import Foundation
import SwiftData
import Combine

@MainActor
final class AgreementDetailViewModel: ObservableObject {
    @Published private(set) var installments: [Installment] = []
    @Published var error: AppError?

    let agreement: DebtAgreement
    private let context: ModelContext
    private let notificationScheduler: NotificationScheduling?
    private var reminderSyncTask: Task<Void, Never>?

    init(agreement: DebtAgreement, context: ModelContext, notificationScheduler: NotificationScheduling? = nil) {
        self.agreement = agreement
        self.context = context
        self.notificationScheduler = notificationScheduler
    }

    // MARK: - Computed Metrics

    var totalAmount: Decimal {
        installments.reduce(.zero) { $0 + $1.amount }
    }

    var totalPaid: Decimal {
        installments.reduce(.zero) { $0 + $1.paidAmount }
    }

    var remainingAmount: Decimal {
        (totalAmount - totalPaid).clamped(to: .zero...totalAmount)
    }

    var paidInstallmentsCount: Int {
        installments.filter { $0.status == .paid }.count
    }

    var overdueInstallmentsCount: Int {
        installments.filter { $0.isOverdue }.count
    }

    var progressPercentage: Double {
        guard totalAmount > 0 else { return 0 }
        let percentage = (Double(truncating: totalPaid as NSNumber) / Double(truncating: totalAmount as NSNumber)) * 100
        return min(max(percentage, 0), 100)
    }

    var sortedInstallments: [Installment] {
        installments.sorted { $0.number < $1.number }
    }

    // MARK: - Methods

    func load() throws {
        let targetID = agreement.id
        let descriptor = FetchDescriptor<Installment>(
            predicate: #Predicate { installment in
                installment.agreement.id == targetID
            },
            sortBy: [SortDescriptor(\.number, order: .forward)]
        )
        installments = try context.fetch(descriptor)
    }

    func registerPayment(
        for installment: Installment,
        amount: Decimal,
        date: Date,
        method: PaymentMethod,
        note: String?
    ) {
        do {
            let payment = Payment(
                installment: installment,
                date: date,
                amount: amount,
                method: method,
                note: note
            )
            context.insert(payment)

            if !installment.payments.contains(where: { $0.id == payment.id }) {
                installment.payments.append(payment)
            }

            // Update installment paid amount
            installment.paidAmount += amount

            // Update status
            if installment.paidAmount >= installment.amount {
                installment.status = .paid
            } else if installment.paidAmount > 0 {
                installment.status = .partial
            }

            let agreement = installment.agreement
            let closedChanged = agreement.updateClosedStatus()
            try context.save()
            publishInstallmentsChange()
            syncReminders(for: agreement)

            NotificationCenter.default.postFinanceDataUpdates(agreementChanged: closedChanged)
        } catch let error as AppError {
            context.rollback()
            self.error = error
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
        }
    }

    func updateInstallmentStatus(_ installment: Installment, to status: InstallmentStatus) {
        do {
            installment.status = status
            let agreement = installment.agreement
            let closedChanged = agreement.updateClosedStatus()
            try context.save()
            publishInstallmentsChange()
            syncReminders(for: agreement)
            NotificationCenter.default.postFinanceDataUpdates(agreementChanged: closedChanged)
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
        }
    }

    func markAsPaidFull(_ installment: Installment, method: PaymentMethod = .other) {
        do {
            let remainingAmount = installment.remainingAmount

            // Create automatic payment for remaining amount
            let payment = Payment(
                installment: installment,
                date: .now,
                amount: remainingAmount,
                method: method,
                note: String(localized: "payment.quick.note")
            )
            context.insert(payment)

            if !installment.payments.contains(where: { $0.id == payment.id }) {
                installment.payments.append(payment)
            }

            // Mark as fully paid
            installment.paidAmount = installment.amount
            installment.status = .paid

            let agreement = installment.agreement
            let closedChanged = agreement.updateClosedStatus()
            try context.save()
            publishInstallmentsChange()
            syncReminders(for: agreement)

            NotificationCenter.default.postFinanceDataUpdates(agreementChanged: closedChanged)
        } catch let error as AppError {
            context.rollback()
            self.error = error
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
        }
    }

    func undoLastPayment(_ installment: Installment) {
        do {
            guard let lastPayment = installment.payments.sorted(by: { $0.date > $1.date }).first else {
                return
            }

            // Remove payment
            context.delete(lastPayment)

            if let index = installment.payments.firstIndex(where: { $0.id == lastPayment.id }) {
                installment.payments.remove(at: index)
            }

            // Update paid amount
            installment.paidAmount -= lastPayment.amount

            // Update status
            if installment.paidAmount == 0 {
                installment.status = installment.isOverdue ? .overdue : .pending
            } else if installment.paidAmount < installment.amount {
                installment.status = .partial
            }

            let agreement = installment.agreement
            let closedChanged = agreement.updateClosedStatus()
            try context.save()
            publishInstallmentsChange()
            syncReminders(for: agreement)

            NotificationCenter.default.postFinanceDataUpdates(agreementChanged: closedChanged)
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
        }
    }

    private func publishInstallmentsChange() {
        installments = Array(installments)
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

struct PaymentDraft: Equatable {
    var amount: Decimal = .zero
    var date: Date = .now
    var method: PaymentMethod = .pix
    var note: String = ""
}
