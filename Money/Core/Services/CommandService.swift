import Foundation
import SwiftData

@MainActor
final class CommandService {
    private let eventBus: DomainEventPublishing
    private let projectionUpdater: FinancialProjectionUpdating

    init(
        eventBus: DomainEventPublishing,
        projectionUpdater: FinancialProjectionUpdating
    ) {
        self.eventBus = eventBus
        self.projectionUpdater = projectionUpdater
    }

    convenience init(eventBus: DomainEventPublishing) {
        self.init(eventBus: eventBus, projectionUpdater: FinancialProjectionUpdater())
    }

    func addDebtor(name: String, phone: String?, note: String?, context: ModelContext) throws -> Debtor {
        guard let normalizedName = name.normalizedOrNil,
              let debtor = Debtor(name: normalizedName, phone: phone, note: note) else {
            throw AppError.validation("error.debtor.invalid")
        }

        context.insert(debtor)
        try context.save()

        publish(.debtorChanged)
        return debtor
    }

    func toggleArchive(debtor: Debtor, context: ModelContext) throws {
        debtor.archived.toggle()
        try context.save()
        publish(.debtorChanged)
    }

    func deleteDebtor(_ debtor: Debtor, context: ModelContext) throws {
        context.delete(debtor)
        try context.save()
        publish(.agreementChanged)

        NotificationCenter.default.post(name: .debtorDataDidChange, object: nil)
        NotificationCenter.default.postFinanceDataUpdates(agreementChanged: true)

        try projectionUpdater.refreshForCurrentMonth(context: context, referenceDate: .now)
    }

    func createAgreement(
        debtor: Debtor,
        draft: AgreementDraft,
        debtService: DebtService,
        context: ModelContext
    ) throws -> DebtAgreement {
        let agreement = try debtService.createAgreement(
            debtor: debtor,
            title: draft.title,
            principal: draft.principal,
            startDate: draft.startDate,
            installmentCount: draft.installmentCount,
            currencyCode: draft.currencyCode,
            interestRate: draft.interestRate,
            context: context
        )

        try context.save()
        NotificationCenter.default.postFinanceDataUpdates(agreementChanged: true)
        publish(.agreementChanged)
        try projectionUpdater.refreshForCurrentMonth(context: context, referenceDate: draft.startDate)
        return agreement
    }

    func deleteAgreement(_ agreement: DebtAgreement, context: ModelContext) throws {
        context.delete(agreement)
        try context.save()
        NotificationCenter.default.postFinanceDataUpdates(agreementChanged: true)
        publish(.agreementChanged)
        try projectionUpdater.refreshForCurrentMonth(context: context, referenceDate: .now)
    }

    func markInstallment(
        _ installment: Installment,
        status: InstallmentStatus,
        context: ModelContext
    ) throws {
        switch status {
        case .paid:
            installment.paidAmount = installment.amount
            installment.status = .paid
        case .partial:
            installment.status = .partial
        case .pending:
            installment.status = .pending
        case .overdue:
            installment.status = .overdue
        }

        _ = installment.agreement.updateClosedStatus()
        try context.save()

        NotificationCenter.default.postFinanceDataUpdates(agreementChanged: true)
        publish(.paymentChanged)
        try projectionUpdater.refreshForCurrentMonth(context: context, referenceDate: installment.dueDate)
    }

    @discardableResult
    func registerPayment(
        installment: Installment,
        amount: Decimal,
        date: Date,
        method: PaymentMethod,
        note: String?,
        context: ModelContext
    ) throws -> Payment {
        guard let payment = Payment(
            installment: installment,
            date: date,
            amount: amount,
            method: method,
            note: note
        ) else {
            throw AppError.validation("error.payment.invalid")
        }

        context.insert(payment)
        if !installment.payments.contains(where: { $0.id == payment.id }) {
            installment.payments.append(payment)
        }

        installment.paidAmount += amount
        if installment.paidAmount >= installment.amount {
            installment.paidAmount = installment.amount
            installment.status = .paid
        } else if installment.paidAmount > .zero {
            installment.status = .partial
        }

        _ = installment.agreement.updateClosedStatus()
        try context.save()

        NotificationCenter.default.postFinanceDataUpdates(agreementChanged: true)
        publish(.paymentChanged)
        try projectionUpdater.refreshForCurrentMonth(context: context, referenceDate: date)
        return payment
    }

    @discardableResult
    func updateSalary(
        amount: Decimal,
        month: Date,
        note: String?,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> SalarySnapshot {
        guard amount >= .zero else {
            throw AppError.validation("error.salary.invalid")
        }

        let interval = calendar.dateInterval(of: .month, for: month) ?? DateInterval(start: month, end: month)
        let descriptor = FetchDescriptor<SalarySnapshot>(predicate: #Predicate { snapshot in
            snapshot.referenceMonth >= interval.start && snapshot.referenceMonth < interval.end
        })

        let snapshot: SalarySnapshot
        if let existing = try context.fetch(descriptor).first {
            existing.amount = amount
            existing.referenceMonth = month
            existing.note = note.normalizedOrNil
            snapshot = existing
        } else {
            guard let created = SalarySnapshot(referenceMonth: month, amount: amount, note: note.normalizedOrNil) else {
                throw AppError.validation("error.salary.invalid")
            }
            context.insert(created)
            snapshot = created
        }

        try context.save()
        publish(.salaryChanged)
        NotificationCenter.default.post(name: .financialDataDidChange, object: nil)
        try projectionUpdater.refreshForCurrentMonth(context: context, referenceDate: month)

        return snapshot
    }

    @discardableResult
    func upsertTransaction(
        existing: CashTransaction?,
        date: Date,
        amount: Decimal,
        type: CashTransactionType,
        category: String?,
        note: String?,
        context: ModelContext
    ) throws -> CashTransaction {
        guard amount > .zero else {
            throw AppError.validation("error.transaction.amount")
        }

        let transaction: CashTransaction
        if let existing {
            existing.date = date
            existing.amount = amount
            existing.type = type
            existing.category = category.normalizedOrNil
            existing.note = note.normalizedOrNil
            transaction = existing
        } else {
            guard let created = CashTransaction(
                date: date,
                amount: amount,
                type: type,
                category: category.normalizedOrNil,
                note: note.normalizedOrNil
            ) else {
                throw AppError.validation("error.transaction.invalid")
            }
            context.insert(created)
            transaction = created
        }

        try context.save()
        publish(.transactionChanged)
        NotificationCenter.default.postTransactionDataUpdates()
        try projectionUpdater.refreshForCurrentMonth(context: context, referenceDate: date)
        return transaction
    }

    func deleteTransaction(_ transaction: CashTransaction, context: ModelContext) throws {
        let referenceDate = transaction.date
        context.delete(transaction)
        try context.save()
        publish(.transactionChanged)
        NotificationCenter.default.postTransactionDataUpdates()
        try projectionUpdater.refreshForCurrentMonth(context: context, referenceDate: referenceDate)
    }

    @discardableResult
    func upsertExpense(
        existing: FixedExpense?,
        name: String,
        amount: Decimal,
        category: String?,
        dueDay: Int,
        active: Bool,
        note: String?,
        context: ModelContext
    ) throws -> FixedExpense {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              amount > .zero,
              (1...31).contains(dueDay) else {
            throw AppError.validation("error.expense.invalid")
        }

        let expense: FixedExpense
        if let existing {
            existing.name = name.normalized
            existing.amount = amount
            existing.category = category.normalizedOrNil
            existing.dueDay = dueDay
            existing.active = active
            existing.note = note.normalizedOrNil
            expense = existing
        } else {
            guard let created = FixedExpense(
                name: name.normalized,
                amount: amount,
                category: category.normalizedOrNil,
                dueDay: dueDay,
                active: active,
                note: note.normalizedOrNil
            ) else {
                throw AppError.validation("error.expense.invalid")
            }
            context.insert(created)
            expense = created
        }

        try context.save()
        publish(.transactionChanged)
        NotificationCenter.default.post(name: .financialDataDidChange, object: nil)
        try projectionUpdater.refreshForCurrentMonth(context: context, referenceDate: .now)
        return expense
    }

    func deleteExpense(_ expense: FixedExpense, context: ModelContext) throws {
        context.delete(expense)
        try context.save()
        publish(.transactionChanged)
        NotificationCenter.default.post(name: .financialDataDidChange, object: nil)
        try projectionUpdater.refreshForCurrentMonth(context: context, referenceDate: .now)
    }

    @discardableResult
    func recalculateCreditProfile(
        for debtor: Debtor,
        calculator: CreditScoreCalculator,
        context: ModelContext
    ) throws -> DebtorCreditProfile {
        let debtorID = debtor.id
        let profileDescriptor = FetchDescriptor<DebtorCreditProfile>(
            predicate: #Predicate { profile in
                profile.debtor.id == debtorID
            }
        )
        let existingProfile = try context.fetch(profileDescriptor).first
        let profile = existingProfile ?? DebtorCreditProfile(debtor: debtor)

        let metrics = try calculator.calculateMetrics(for: debtor, context: context)
        calculator.apply(metrics: metrics, to: profile)

        if existingProfile == nil {
            context.insert(profile)
        }

        try context.save()
        publish(.debtorChanged)
        return profile
    }

    private func publish(_ event: DomainEvent) {
        Task {
            await eventBus.publish(event)
        }
    }
}
