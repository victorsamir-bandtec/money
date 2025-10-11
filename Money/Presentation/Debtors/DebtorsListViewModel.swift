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

    private let context: ModelContext

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
        debtors = results
    }

    func addDebtor(name: String, phone: String?, note: String?) {
        guard let trimmed = name.normalizedOrNil else {
            error = .validation("error.debtor.name")
            return
        }
        let debtor = Debtor(name: trimmed, phone: phone, note: note)
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
        var output: [UUID: DebtorSummary] = [:]
        var needsSave = false
        for debtor in debtors {
            let result = try makeSummary(for: debtor)
            output[debtor.id] = result.summary
            needsSave = needsSave || result.didUpdateClosedStatus
        }
        if needsSave {
            try context.save()
        }
        return output
    }

    private func makeSummary(for debtor: Debtor) throws -> (summary: DebtorSummary, didUpdateClosedStatus: Bool) {
        let debtorID = debtor.id

        let agreementsDescriptor = FetchDescriptor<DebtAgreement>(predicate: #Predicate { agreement in
            agreement.debtor.id == debtorID
        })
        let agreements = try context.fetch(agreementsDescriptor)

        var didUpdateClosedStatus = false
        for agreement in agreements where agreement.updateClosedStatus() {
            didUpdateClosedStatus = true
        }

        let activeAgreements = agreements.filter { !$0.closed }

        let installmentsDescriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
            installment.agreement.debtor.id == debtorID
        })
        let installments = try context.fetch(installmentsDescriptor)
        let activeInstallments = installments.filter { !$0.agreement.closed }

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

        let summary = DebtorSummary(
            totalAgreements: agreements.count,
            activeAgreements: activeAgreements.count,
            totalInstallments: totalInstallments,
            paidInstallments: paidInstallments,
            openInstallments: openInstallments,
            overdueInstallments: overdueInstallments,
            totalAmount: totalAmount,
            paidAmount: paidAmount
        )

        return (summary, didUpdateClosedStatus)
    }
}
