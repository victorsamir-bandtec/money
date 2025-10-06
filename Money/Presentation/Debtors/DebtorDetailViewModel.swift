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
    private var notificationObservers: [Any] = []
    private var reminderSyncTask: Task<Void, Never>?

    init(debtor: Debtor, context: ModelContext, calculator: FinanceCalculator, notificationScheduler: NotificationScheduling?) {
        self.debtor = debtor
        self.context = context
        self.calculator = calculator
        self.notificationScheduler = notificationScheduler
        setupNotificationObservers()
    }

    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func setupNotificationObservers() {
        // Observe payment data changes to reload agreements when payments are registered
        let paymentObserver = NotificationCenter.default.addObserver(
            forName: .paymentDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? self?.load()
            }
        }
        notificationObservers.append(paymentObserver)

        // Observe agreement data changes to reload when agreements are modified
        let agreementObserver = NotificationCenter.default.addObserver(
            forName: .agreementDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? self?.load()
            }
        }
        notificationObservers.append(agreementObserver)

        // Observe financial changes as a catch‑all to keep metrics fresh
        let financialObserver = NotificationCenter.default.addObserver(
            forName: .financialDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? self?.load()
            }
        }
        notificationObservers.append(financialObserver)
    }

    // MARK: - Computed Metrics

    var totalAgreementsValue: Decimal { installments.reduce(.zero) { $0 + $1.amount } }

    var totalPaid: Decimal { installments.reduce(.zero) { $0 + $1.paidAmount } }

    var totalRemaining: Decimal {
        (totalAgreementsValue - totalPaid).clamped(to: .zero...totalAgreementsValue)
    }

    var paidInstallmentsCount: Int { installments.filter { $0.status == .paid }.count }

    var totalInstallmentsCount: Int { installments.count }

    func load() throws {
        let targetID = debtor.id
        // Fetch agreements for the debtor for the list section
        let agreementsDescriptor = FetchDescriptor<DebtAgreement>(predicate: #Predicate { agreement in
            agreement.debtor.id == targetID
        }, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        agreements = try context.fetch(agreementsDescriptor)

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

    func createAgreement(from draft: AgreementDraft) {
        do {
            let normalizedRate = draft.interestRate.map { $0 / 100 }

            let agreement = DebtAgreement(
                debtor: debtor,
                title: draft.title.isEmpty ? nil : draft.title,
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
            var payloads: [InstallmentReminderPayload] = []
            for spec in schedule {
                let installment = Installment(
                    agreement: agreement,
                    number: spec.number,
                    dueDate: spec.dueDate,
                    amount: spec.amount
                )
                context.insert(installment)
                payloads.append(InstallmentReminderPayload(
                    agreementID: agreement.id,
                    installmentNumber: spec.number,
                    dueDate: spec.dueDate
                ))
            }
            try context.save()
            if let scheduler = notificationScheduler {
                for payload in payloads {
                    Task { try? await scheduler.scheduleReminder(for: payload) }
                }
            }
            try load()
        } catch let error as AppError {
            context.rollback()
            self.error = error
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
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
        do {
            let closedChanged = agreement.updateClosedStatus()
            try context.save()
            syncReminders(for: agreement)
            try load()
            // Notify other views that financial/payment data changed so dashboards and
            // lists can refresh immediately after a manual status change performed
            // from DebtorDetailScene.
            NotificationCenter.default.post(name: .paymentDataDidChange, object: nil)
            NotificationCenter.default.post(name: .financialDataDidChange, object: nil)
            if closedChanged {
                NotificationCenter.default.post(name: .agreementDataDidChange, object: nil)
            }
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
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
                let payload = InstallmentReminderPayload(
                    agreementID: agreementID,
                    installmentNumber: installment.number,
                    dueDate: installment.dueDate
                )
                try? await scheduler.scheduleReminder(for: payload)
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
