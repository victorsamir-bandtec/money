import Foundation
import SwiftData
import Combine

@MainActor
final class DebtorDetailViewModel: ObservableObject {
    @Published private(set) var agreements: [DebtAgreement] = []
    @Published private(set) var installments: [Installment] = []
    @Published var error: AppError?

    let debtor: Debtor
    private let context: ModelContext
    private let calculator: FinanceCalculator
    private let notificationScheduler: NotificationScheduling?
    private let observers = NotificationObservers()
    private var reminderSyncTask: Task<Void, Never>?

    init(debtor: Debtor, context: ModelContext, calculator: FinanceCalculator, notificationScheduler: NotificationScheduling?) {
        self.debtor = debtor
        self.context = context
        self.calculator = calculator
        self.notificationScheduler = notificationScheduler
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        let reloadHandler: () -> Void = { [weak self] in
            Task { @MainActor [weak self] in
                try? self?.load()
            }
        }

        // Observe payment data changes to reload agreements when payments are registered
        observers.observe(.paymentDataDidChange, handler: reloadHandler)

        // Observe agreement data changes to reload when agreements are modified
        observers.observe(.agreementDataDidChange, handler: reloadHandler)

        // Observe financial changes as a catch‑all to keep metrics fresh
        observers.observe(.financialDataDidChange, handler: reloadHandler)
    }

    // MARK: - Computed Metrics

    var totalAgreementsValue: Decimal { installments.reduce(.zero) { $0 + $1.amount } }

    var totalPaid: Decimal { installments.reduce(.zero) { $0 + $1.paidAmount } }

    var totalRemaining: Decimal {
        (totalAgreementsValue - totalPaid).clamped(to: .zero...totalAgreementsValue)
    }

    var paidInstallmentsCount: Int { installments.filter { $0.status == .paid }.count }

    var totalInstallmentsCount: Int { installments.count }

    struct AgreementOverview {
        let agreementID: UUID
        let totalInstallments: Int
        let paidInstallments: Int
        let openInstallments: Int
        let totalAmount: Decimal
        let paidAmount: Decimal

        var remainingAmount: Decimal {
            (totalAmount - paidAmount).clamped(to: .zero...totalAmount)
        }

        var isClosed: Bool { openInstallments == 0 && totalInstallments > 0 }
    }

    func load() throws {
        let targetID = debtor.id
        // Fetch agreements for the debtor for the list section
        let agreementsDescriptor = FetchDescriptor<DebtAgreement>(predicate: #Predicate { agreement in
            agreement.debtor.id == targetID
        }, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let fetchedAgreements = try context.fetch(agreementsDescriptor)
        var refreshedAgreements: [DebtAgreement] = []
        for agreement in fetchedAgreements {
            if agreement.updateClosedStatus() {
                try context.save()
            }
            refreshedAgreements.append(agreement)
        }
        agreements = refreshedAgreements

        // Fetch all installments for the debtor to compute metrics using fresh values
        let installmentsDescriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
            installment.agreement.debtor.id == targetID
        })
        var fetchedInstallments = try context.fetch(installmentsDescriptor)
        // Fallback: if nested predicate fails for any reason, rely on relationships
        if fetchedInstallments.isEmpty && !agreements.isEmpty {
            fetchedInstallments = agreements.flatMap { $0.installments }
        }
        // Force access to refresh values from context
        fetchedInstallments.forEach { _ = $0.paidAmount }
        installments = fetchedInstallments.sorted(by: { $0.number < $1.number })
    }

    func overview(for agreement: DebtAgreement) -> AgreementOverview {
        let related = installments(for: agreement)
        let totalInstallments = related.count
        let paidInstallments = related.filter { $0.status == .paid }.count
        let openInstallments = max(totalInstallments - paidInstallments, 0)
        let totalAmount = related.reduce(into: Decimal.zero) { $0 += $1.amount }
        let paidAmount = related.reduce(into: Decimal.zero) { $0 += $1.paidAmount }

        return AgreementOverview(
            agreementID: agreement.id,
            totalInstallments: totalInstallments,
            paidInstallments: paidInstallments,
            openInstallments: openInstallments,
            totalAmount: totalAmount,
            paidAmount: paidAmount
        )
    }

    func installments(for agreement: DebtAgreement) -> [Installment] {
        let cached = installments.filter { $0.agreement.id == agreement.id }
        if cached.isEmpty {
            return agreement.installments.sorted(by: { $0.number < $1.number })
        }
        return cached.sorted(by: { $0.number < $1.number })
    }

    func createAgreement(from draft: AgreementDraft) {
        do {
            let normalizedRate = draft.interestRate.map { $0 / 100 }

            let agreement = DebtAgreement(
                debtor: debtor,
                title: draft.title.normalizedOrNil,
                principal: draft.principal,
                startDate: draft.startDate,
                installmentCount: draft.installmentCount,
                currencyCode: draft.currencyCode,
                interestRateMonthly: normalizedRate
            )
            context.insert(agreement)

            let schedule = try calculator.generateSchedule(
                principal: draft.principal,
                installments: draft.installmentCount,
                monthlyInterest: normalizedRate,
                firstDueDate: draft.startDate
            )
            var createdInstallments: [Installment] = []
            for spec in schedule {
                let installment = Installment(
                    agreement: agreement,
                    number: spec.number,
                    dueDate: spec.dueDate,
                    amount: spec.amount
                )
                context.insert(installment)
                createdInstallments.append(installment)
            }

            Task {
                await context.saveWithCallbacks(
                    notification: .agreementDataDidChange,
                    onSuccess: { [weak self] in
                        guard let self else { return }
                        if let scheduler = self.notificationScheduler {
                            for installment in createdInstallments {
                                Task { await scheduler.syncReminders(for: installment) }
                            }
                        }
                        try self.load()
                    },
                    onError: { [weak self] error in
                        if let appError = error as? AppError {
                            self?.error = appError
                        } else {
                            self?.error = .persistence("error.generic")
                        }
                    }
                )
            }
        } catch let error as AppError {
            self.error = error
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    func deleteAgreement(_ agreement: DebtAgreement) {
        if let scheduler = notificationScheduler {
            reminderSyncTask?.cancel()
            reminderSyncTask = Task { @MainActor in
                await scheduler.cancelReminders(for: agreement.id)
            }
        }

        let targetID = agreement.id
        agreements.removeAll { $0.id == targetID }
        installments.removeAll { $0.agreement.id == targetID }
        context.delete(agreement)

        Task {
            await context.saveWithCallbacks(
                notification: .agreementDataDidChange,
                onSuccess: { [weak self] in
                    try self?.load()
                },
                onError: { [weak self] _ in
                    self?.error = .persistence("error.generic")
                }
            )
        }
    }

    func mark(installment: Installment, as status: InstallmentStatus) {
        let agreement = installment.agreement
        switch status {
        case .paid:
            installment.paidAmount = installment.amount
            installment.status = .paid
        case .partial:
            installment.status = .partial
        case .overdue:
            installment.status = .overdue
        case .pending:
            installment.status = .pending
        }

        let closedChanged = agreement.updateClosedStatus()
        Task {
            await context.saveWithCallbacks(
                notification: closedChanged ? .agreementDataDidChange : .financialDataDidChange,
                onSuccess: { [weak self] in
                    guard let self else { return }
                    self.syncReminders(for: agreement)
                    try self.load()
                },
                onError: { [weak self] _ in
                    self?.error = .persistence("error.generic")
                }
            )
        }
    }

    private func syncReminders(for agreement: DebtAgreement) {
        guard let scheduler = notificationScheduler else { return }
        let agreementID = agreement.id
        let installments = agreement.installments
        let isClosed = agreement.closed
        let startOfToday = Calendar.current.startOfDay(for: Date())

        reminderSyncTask?.cancel()
        reminderSyncTask = Task { @MainActor in
            await scheduler.cancelReminders(for: agreementID)
            guard !isClosed else { return }

            let upcoming = installments.filter { installment in
                installment.status != .paid && installment.dueDate >= startOfToday
            }

            for installment in upcoming {
                await scheduler.syncReminders(for: installment)
            }
        }
    }

#if DEBUG
    var reminderSyncTaskForTesting: Task<Void, Never>? { reminderSyncTask }
#endif
}

struct AgreementDraft: Equatable {
    var title: String = ""
    var principal: Decimal = .zero
    var startDate: Date = .now
    var installmentCount: Int = 12
    var currencyCode: String = "BRL"
    var interestRate: Decimal? = nil
}
