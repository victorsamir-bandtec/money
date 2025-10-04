import Foundation
import SwiftData
import Combine

@MainActor
final class DebtorDetailViewModel: ObservableObject {
    @Published private(set) var agreements: [DebtAgreement] = []
    @Published var error: AppError?

    let debtor: Debtor
    private let context: ModelContext
    private let calculator: FinanceCalculator
    private let notificationScheduler: NotificationScheduling?

    init(debtor: Debtor, context: ModelContext, calculator: FinanceCalculator, notificationScheduler: NotificationScheduling?) {
        self.debtor = debtor
        self.context = context
        self.calculator = calculator
        self.notificationScheduler = notificationScheduler
    }

    func load() throws {
        let targetID = debtor.id
        let descriptor = FetchDescriptor<DebtAgreement>(predicate: #Predicate { agreement in
            agreement.debtor.id == targetID
        }, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        agreements = try context.fetch(descriptor)
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
            try context.save()
            if let scheduler = notificationScheduler {
                let payload = InstallmentReminderPayload(
                    agreementID: installment.agreement.id,
                    installmentNumber: installment.number,
                    dueDate: installment.dueDate
                )
                Task { try? await scheduler.scheduleReminder(for: payload) }
            }
            try load()
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
        }
    }
}

struct AgreementDraft: Equatable {
    var title: String = ""
    var principal: Decimal = .zero
    var startDate: Date = .now
    var installmentCount: Int = 12
    var currencyCode: String = "BRL"
    var interestRate: Decimal? = nil
}
