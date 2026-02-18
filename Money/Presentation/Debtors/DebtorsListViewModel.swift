import Foundation
import SwiftData
import Combine

@MainActor
final class DebtorsListViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published private(set) var debtors: [Debtor] = []
    @Published var showArchived: Bool = false
    @Published var error: AppError?
    @Published private(set) var totalCount: Int = 0
    @Published private(set) var archivedCount: Int = 0
    @Published private(set) var summaries: [UUID: DebtorSummary] = [:]
    @Published private(set) var profiles: [UUID: DebtorCreditProfile] = [:]

    private let context: ModelContext
    private let calculator = CreditScoreCalculator()

    init(context: ModelContext) {
        self.context = context
    }

    func load() throws {
        let shouldIncludeArchived = showArchived
        let predicate = #Predicate<Debtor> { debtor in
            shouldIncludeArchived || debtor.archived == false
        }
        let descriptor = FetchDescriptor<Debtor>(predicate: predicate, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        var results = try context.fetch(descriptor)

        let fullDescriptor = FetchDescriptor<Debtor>()
        let fullList = try context.fetch(fullDescriptor)
        totalCount = fullList.count
        archivedCount = fullList.filter(\.archived).count

        if let term = searchText.normalizedOrNil {
            results = results.filter { debtor in
                debtor.name.localizedCaseInsensitiveContains(term)
            }
        }
        summaries = try computeSummaries(for: results)
        profiles = try loadProfiles(for: results)
        debtors = results
    }

    func creditProfile(for debtor: Debtor) -> DebtorCreditProfile? {
        profiles[debtor.id]
    }

    private func loadProfiles(for debtors: [Debtor]) throws -> [UUID: DebtorCreditProfile] {
        var output: [UUID: DebtorCreditProfile] = [:]
        for debtor in debtors {
            if let profile = try? calculator.calculateProfile(for: debtor, context: context) {
                output[debtor.id] = profile
            }
        }
        return output
    }

    func addDebtor(name: String, phone: String?, note: String?) {
        guard let trimmed = name.normalizedOrNil else {
            error = .validation("error.debtor.name")
            return
        }
        guard let debtor = Debtor(name: trimmed, phone: phone, note: note) else {
            error = .validation("error.debtor.invalid")
            return
        }
        context.insert(debtor)
        do {
            try context.save()
            try load()
        } catch {
            context.delete(debtor)
            self.error = .persistence("error.generic")
        }
    }

    var activeCount: Int {
        max(totalCount - archivedCount, 0)
    }

    func toggleArchive(_ debtor: Debtor) {
        debtor.archived.toggle()
        do {
            try context.save()
            try load()
        } catch {
            context.undoManager?.undo()
            self.error = .persistence("error.generic")
        }
    }

    func deleteDebtor(_ debtor: Debtor) {
        context.delete(debtor)
        do {
            try context.save()
            try load()
            NotificationCenter.default.post(name: .debtorDataDidChange, object: nil)
            NotificationCenter.default.postFinanceDataUpdates(agreementChanged: true)
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
        }
    }
}

extension DebtorsListViewModel {
    struct DebtorSummary: Equatable {
        let totalAgreements: Int
        let activeAgreements: Int
        let totalInstallments: Int
        let paidInstallments: Int
        let openInstallments: Int
        let overdueInstallments: Int
        let totalAmount: Decimal
        let paidAmount: Decimal

        var remainingAmount: Decimal {
            (totalAmount - paidAmount).clamped(to: .zero...totalAmount)
        }

        static let empty = DebtorSummary(
            totalAgreements: 0,
            activeAgreements: 0,
            totalInstallments: 0,
            paidInstallments: 0,
            openInstallments: 0,
            overdueInstallments: 0,
            totalAmount: .zero,
            paidAmount: .zero
        )
    }

    func summary(for debtor: Debtor) -> DebtorSummary {
        summaries[debtor.id] ?? .empty
    }

    private func computeSummaries(for debtors: [Debtor]) throws -> [UUID: DebtorSummary] {
        guard !debtors.isEmpty else { return [:] }

        let debtorIDs = debtors.map(\.id)
        let agreements = try fetchAgreements(for: debtorIDs)
        let installments = try fetchInstallments(for: debtorIDs)

        var agreementsByDebtor: [UUID: [DebtAgreement]] = [:]
        agreements.forEach { agreement in
            agreementsByDebtor[agreement.debtor.id, default: []].append(agreement)
        }

        var installmentsByDebtor: [UUID: [Installment]] = [:]
        var installmentsByAgreement: [UUID: [Installment]] = [:]
        installments.forEach { installment in
            let debtorID = installment.agreement.debtor.id
            installmentsByDebtor[debtorID, default: []].append(installment)
            installmentsByAgreement[installment.agreement.id, default: []].append(installment)
        }

        var output: [UUID: DebtorSummary] = [:]
        var needsSave = false

        for debtor in debtors {
            let debtorAgreements = agreementsByDebtor[debtor.id] ?? []

            for agreement in debtorAgreements {
                let agreementInstallments = installmentsByAgreement[agreement.id] ?? []
                let shouldClose = !agreementInstallments.isEmpty && agreementInstallments.allSatisfy { $0.status == .paid }
                if agreement.closed != shouldClose {
                    agreement.closed = shouldClose
                    needsSave = true
                }
            }

            let activeAgreements = debtorAgreements.filter { !$0.closed }
            let activeInstallments = (installmentsByDebtor[debtor.id] ?? []).filter { !$0.agreement.closed }

            let totalInstallments = activeInstallments.count
            let paidInstallments = activeInstallments.filter { $0.status == .paid }.count
            let openInstallments = max(totalInstallments - paidInstallments, 0)
            let overdueInstallments = activeInstallments.filter { $0.isOverdue }.count

            let totalAmount = activeInstallments.reduce(into: Decimal.zero) { result, installment in
                result += installment.amount
            }
            let paidAmount = activeInstallments.reduce(into: Decimal.zero) { result, installment in
                let normalized = min(installment.paidAmount, installment.amount)
                result += normalized
            }

            output[debtor.id] = DebtorSummary(
                totalAgreements: debtorAgreements.count,
                activeAgreements: activeAgreements.count,
                totalInstallments: totalInstallments,
                paidInstallments: paidInstallments,
                openInstallments: openInstallments,
                overdueInstallments: overdueInstallments,
                totalAmount: totalAmount,
                paidAmount: paidAmount
            )
        }

        if needsSave {
            try context.save()
        }

        return output
    }

    private func fetchAgreements(for debtorIDs: [UUID]) throws -> [DebtAgreement] {
        let ids = Set(debtorIDs)
        let descriptor = FetchDescriptor<DebtAgreement>(predicate: #Predicate { agreement in
            ids.contains(agreement.debtor.id)
        })
        return try context.fetch(descriptor)
    }

    private func fetchInstallments(for debtorIDs: [UUID]) throws -> [Installment] {
        let ids = Set(debtorIDs)
        let descriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
            ids.contains(installment.agreement.debtor.id)
        })
        return try context.fetch(descriptor)
    }
}
