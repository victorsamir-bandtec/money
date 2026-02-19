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
    @Published private(set) var profiles: [UUID: DebtorCreditProfileDTO] = [:]

    private let context: ModelContext
    private let commandService: CommandService?
    private let metricsEngine: DebtorMetricsProviding?
    private let eventBus: DomainEventSubscribing?
    private var eventTask: Task<Void, Never>?

    init(
        context: ModelContext,
        commandService: CommandService? = nil,
        metricsEngine: DebtorMetricsProviding? = nil,
        eventBus: DomainEventSubscribing? = nil
    ) {
        self.context = context
        self.commandService = commandService
        self.metricsEngine = metricsEngine
        self.eventBus = eventBus
        subscribeToEvents()
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
                debtor.name.localizedStandardContains(term)
            }
        }

        summaries = try computeSummaries(for: results)
        profiles = try loadProfiles(for: results)
        debtors = results
    }

    func loadAsync() async {
        guard let metricsEngine else {
            try? load()
            return
        }

        do {
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
                    debtor.name.localizedStandardContains(term)
                }
            }

            let debtorIDs = results.map(\.id)
            async let computedSummaries = metricsEngine.summaries(for: debtorIDs)
            async let computedProfiles = metricsEngine.profiles(for: debtorIDs)

            let summaryDTOs = try await computedSummaries
            let profileDTOs = try await computedProfiles

            summaries = summaryDTOs.mapValues { dto in
                DebtorSummary(
                    totalAgreements: dto.totalAgreements,
                    activeAgreements: dto.activeAgreements,
                    totalInstallments: dto.totalInstallments,
                    paidInstallments: dto.paidInstallments,
                    openInstallments: dto.openInstallments,
                    overdueInstallments: dto.overdueInstallments,
                    totalAmount: dto.totalAmount,
                    paidAmount: dto.paidAmount
                )
            }
            profiles = profileDTOs
            debtors = results
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    func creditProfile(for debtor: Debtor) -> DebtorCreditProfileDTO? {
        profiles[debtor.id]
    }

    private func loadProfiles(for debtors: [Debtor]) throws -> [UUID: DebtorCreditProfileDTO] {
        guard !debtors.isEmpty else { return [:] }

        let debtorIDs = Set(debtors.map(\.id))
        let descriptor = FetchDescriptor<DebtorCreditProfile>(predicate: #Predicate { profile in
            debtorIDs.contains(profile.debtor.id)
        })

        let fetchedProfiles = try context.fetch(descriptor)
        return Dictionary(uniqueKeysWithValues: fetchedProfiles.map { profile in
            (
                profile.debtor.id,
                DebtorCreditProfileDTO(
                    debtorID: profile.debtor.id,
                    score: profile.score,
                    riskLevel: profile.riskLevel,
                    lastCalculated: profile.lastCalculated
                )
            )
        })
    }

    func addDebtor(name: String, phone: String?, note: String?) {
        guard let trimmed = name.normalizedOrNil else {
            error = .validation("error.debtor.name")
            return
        }

        do {
            if let commandService {
                _ = try commandService.addDebtor(name: trimmed, phone: phone, note: note, context: context)
                Task {
                    if let metricsEngine {
                        await metricsEngine.invalidate(debtorIDs: nil)
                    }
                }
            } else {
                guard let debtor = Debtor(name: trimmed, phone: phone, note: note) else {
                    error = .validation("error.debtor.invalid")
                    return
                }
                context.insert(debtor)
                try context.save()
                try load()
            }
        } catch let appError as AppError {
            self.error = appError
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    var activeCount: Int {
        max(totalCount - archivedCount, 0)
    }

    func toggleArchive(_ debtor: Debtor) {
        do {
            if let commandService {
                try commandService.toggleArchive(debtor: debtor, context: context)
                Task {
                    if let metricsEngine {
                        await metricsEngine.invalidate(debtorIDs: [debtor.id])
                    }
                }
            } else {
                debtor.archived.toggle()
                try context.save()
                try load()
            }
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
        }
    }

    func deleteDebtor(_ debtor: Debtor) {
        do {
            if let commandService {
                try commandService.deleteDebtor(debtor, context: context)
                Task {
                    if let metricsEngine {
                        await metricsEngine.invalidate(debtorIDs: nil)
                    }
                }
            } else {
                context.delete(debtor)
                try context.save()
                try load()
                NotificationCenter.default.post(name: .debtorDataDidChange, object: nil)
                NotificationCenter.default.postFinanceDataUpdates(agreementChanged: true)
            }
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
        }
    }

    private func subscribeToEvents() {
        guard let eventBus else { return }

        eventTask = Task { [weak self] in
            let stream = await eventBus.stream()
            for await event in stream {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                switch event {
                case .debtorChanged, .agreementChanged, .paymentChanged:
                    await self.loadAsync()
                case .salaryChanged, .transactionChanged:
                    break
                }
            }
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

        for debtor in debtors {
            let debtorAgreements = agreementsByDebtor[debtor.id] ?? []
            let closedMap: [UUID: Bool] = Dictionary(uniqueKeysWithValues: debtorAgreements.map { agreement in
                let agreementInstallments = installmentsByAgreement[agreement.id] ?? []
                let isClosed = !agreementInstallments.isEmpty && agreementInstallments.allSatisfy { $0.status == .paid }
                return (agreement.id, isClosed)
            })

            let activeAgreements = debtorAgreements.filter { !(closedMap[$0.id] ?? $0.closed) }
            let activeAgreementIDs = Set(activeAgreements.map(\.id))
            let activeInstallments = (installmentsByDebtor[debtor.id] ?? []).filter { activeAgreementIDs.contains($0.agreement.id) }

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
