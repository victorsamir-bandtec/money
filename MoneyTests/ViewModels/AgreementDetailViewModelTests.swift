import Foundation
import Testing
import SwiftData
@testable import Money

struct AgreementDetailViewModelTests {
    @Test("Carrega parcelas do acordo") @MainActor
    func loadsInstallments() throws {
        let (context, agreement) = try makeTestEnvironment()
        let viewModel = AgreementDetailViewModel(agreement: agreement, context: context, notificationScheduler: nil)

        try viewModel.load()

        #expect(viewModel.installments.count == 3)
        #expect(viewModel.sortedInstallments.first?.number == 1)
        #expect(viewModel.sortedInstallments.last?.number == 3)
    }

    @Test("Registra pagamento e atualiza parcela") @MainActor
    func registersPaymentAndUpdatesInstallment() throws {
        let (context, agreement) = try makeTestEnvironment()
        let viewModel = AgreementDetailViewModel(agreement: agreement, context: context, notificationScheduler: nil)

        try viewModel.load()
        let installment = try #require(viewModel.installments.first)

        #expect(installment.status == .pending)
        #expect(installment.paidAmount == .zero)

        viewModel.registerPayment(
            for: installment,
            amount: Decimal(200),
            date: .now,
            method: .pix,
            note: "Pagamento teste"
        )

        try viewModel.load()
        #expect(installment.paidAmount == Decimal(200))
        #expect(installment.status == .partial)
        #expect(installment.payments.count == 1)
        #expect(installment.payments.first?.amount == Decimal(200))
    }

    @Test("Marca parcela como paga totalmente") @MainActor
    func marksInstallmentAsFullyPaid() throws {
        let (context, agreement) = try makeTestEnvironment()
        let viewModel = AgreementDetailViewModel(agreement: agreement, context: context, notificationScheduler: nil)

        try viewModel.load()
        let installment = try #require(viewModel.installments.first)

        viewModel.markAsPaidFull(installment, method: .cash)

        try viewModel.load()
        #expect(installment.status == .paid)
        #expect(installment.paidAmount == installment.amount)
        #expect(installment.payments.count == 1)
        #expect(installment.payments.first?.method == .cash)
    }

    @Test("Desfaz último pagamento") @MainActor
    func undoesLastPayment() throws {
        let (context, agreement) = try makeTestEnvironment()
        let viewModel = AgreementDetailViewModel(agreement: agreement, context: context, notificationScheduler: nil)

        try viewModel.load()
        let installment = try #require(viewModel.installments.first)

        // Registrar dois pagamentos
        viewModel.registerPayment(for: installment, amount: Decimal(100), date: .now, method: .pix, note: nil)
        viewModel.registerPayment(for: installment, amount: Decimal(150), date: .now, method: .cash, note: nil)

        try viewModel.load()
        #expect(installment.paidAmount == Decimal(250))
        #expect(installment.payments.count == 2)

        // Desfazer último pagamento
        viewModel.undoLastPayment(installment)

        try viewModel.load()
        #expect(installment.paidAmount == Decimal(100))
        #expect(installment.payments.count == 1)
        #expect(installment.status == .partial)
    }

    @Test("Atualiza status da parcela manualmente") @MainActor
    func updatesInstallmentStatus() throws {
        let (context, agreement) = try makeTestEnvironment()
        let viewModel = AgreementDetailViewModel(agreement: agreement, context: context, notificationScheduler: nil)

        try viewModel.load()
        let installment = try #require(viewModel.installments.first)

        #expect(installment.status == .pending)

        viewModel.updateInstallmentStatus(installment, to: .overdue)
        #expect(installment.status == .overdue)

        viewModel.updateInstallmentStatus(installment, to: .pending)
        #expect(installment.status == .pending)
    }

    @Test("Calcula métricas do acordo") @MainActor
    func calculatesAgreementMetrics() throws {
        let (context, agreement) = try makeTestEnvironment()
        let viewModel = AgreementDetailViewModel(agreement: agreement, context: context, notificationScheduler: nil)

        try viewModel.load()

        #expect(viewModel.totalAmount == Decimal(1200))
        #expect(viewModel.totalPaid == .zero)
        #expect(viewModel.remainingAmount == Decimal(1200))
        #expect(viewModel.paidInstallmentsCount == 0)
        #expect(viewModel.overdueInstallmentsCount == 0)
        #expect(viewModel.progressPercentage == 0)

        let installment1 = viewModel.installments[0]
        let installment2 = viewModel.installments[1]

        viewModel.markAsPaidFull(installment1)
        viewModel.registerPayment(for: installment2, amount: Decimal(200), date: .now, method: .pix, note: nil)

        try viewModel.load()

        #expect(viewModel.totalAmount == Decimal(1200))
        #expect(viewModel.totalPaid == Decimal(600))
        #expect(viewModel.remainingAmount == Decimal(600))
        #expect(viewModel.paidInstallmentsCount == 1)
        #expect(abs(viewModel.progressPercentage - 50.0) < 0.01)
    }

    @Test("Fecha acordo quando todas parcelas são pagas") @MainActor
    func closesAgreementWhenAllInstallmentsPaid() throws {
        let (context, agreement) = try makeTestEnvironment()
        let viewModel = AgreementDetailViewModel(agreement: agreement, context: context, notificationScheduler: nil)

        try viewModel.load()
        #expect(!agreement.closed)

        for installment in viewModel.installments {
            viewModel.markAsPaidFull(installment)
        }

        try viewModel.load()
        #expect(agreement.closed)
    }

    @Test("Sincroniza notificações ao registrar pagamento") @MainActor
    func syncsNotificationsOnPaymentRegistration() async throws {
        let (context, agreement) = try makeTestEnvironment()
        let scheduler = NotificationSchedulerSpy()
        let viewModel = AgreementDetailViewModel(agreement: agreement, context: context, notificationScheduler: scheduler)

        try viewModel.load()
        let installment = try #require(viewModel.installments.first)

        viewModel.registerPayment(for: installment, amount: Decimal(200), date: .now, method: .pix, note: nil)

#if DEBUG
        await viewModel.reminderSyncTaskForTesting?.value
#endif

        // Deve ter cancelado as notificações antigas e reagendado para parcelas pendentes
        #expect(scheduler.actions.contains(.cancelAgreement(agreementID: agreement.id)))
    }

    @Test("Cancela notificações ao fechar acordo") @MainActor
    func cancelsNotificationsWhenClosingAgreement() async throws {
        let (context, agreement) = try makeTestEnvironment()
        let scheduler = NotificationSchedulerSpy()
        let viewModel = AgreementDetailViewModel(agreement: agreement, context: context, notificationScheduler: scheduler)

        try viewModel.load()

        for installment in viewModel.installments {
            viewModel.markAsPaidFull(installment)
        }

#if DEBUG
        await viewModel.reminderSyncTaskForTesting?.value
#endif

        #expect(agreement.closed)
        #expect(scheduler.actions.contains(.cancelAgreement(agreementID: agreement.id)))
    }

    @Test("Emite notificações ao modificar dados") @MainActor
    func postsNotificationsOnDataModification() throws {
        let (context, agreement) = try makeTestEnvironment()
        let viewModel = AgreementDetailViewModel(agreement: agreement, context: context, notificationScheduler: nil)

        try viewModel.load()
        let installment = try #require(viewModel.installments.first)

        var financialNotificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .financialDataDidChange,
            object: nil,
            queue: nil
        ) { _ in
            financialNotificationReceived = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        viewModel.registerPayment(for: installment, amount: Decimal(100), date: .now, method: .pix, note: nil)

        #expect(financialNotificationReceived)
    }

    @Test("Calcula parcelas vencidas corretamente") @MainActor
    func calculatesOverdueInstallmentsCorrectly() throws {
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            CashTransaction.self,
            FixedExpense.self,
            SalarySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let debtor = Debtor(name: "Teste")
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 900, startDate: .now, installmentCount: 3)
        context.insert(agreement)

        let calendar = Calendar.current
        let pastDate1 = calendar.date(byAdding: .day, value: -10, to: .now)!
        let pastDate2 = calendar.date(byAdding: .day, value: -5, to: .now)!
        let futureDate = calendar.date(byAdding: .day, value: 5, to: .now)!

        let overdueInstallment1 = Installment(agreement: agreement, number: 1, dueDate: pastDate1, amount: 300)
        let overdueInstallment2 = Installment(agreement: agreement, number: 2, dueDate: pastDate2, amount: 300)
        let upcomingInstallment = Installment(agreement: agreement, number: 3, dueDate: futureDate, amount: 300)

        context.insert(overdueInstallment1)
        context.insert(overdueInstallment2)
        context.insert(upcomingInstallment)
        try context.save()

        let viewModel = AgreementDetailViewModel(agreement: agreement, context: context, notificationScheduler: nil)
        try viewModel.load()

        #expect(viewModel.overdueInstallmentsCount == 2)
    }
}

// MARK: - Helpers

@MainActor
private func makeTestEnvironment() throws -> (ModelContext, DebtAgreement) {
    let schema = Schema([
        Debtor.self,
        DebtAgreement.self,
        Installment.self,
        Payment.self,
        CashTransaction.self,
        FixedExpense.self,
        SalarySnapshot.self
    ])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: configuration)
    let context = container.mainContext

    let debtor = Debtor(name: "Teste")
    context.insert(debtor)

    let agreement = DebtAgreement(debtor: debtor, principal: 1200, startDate: .now, installmentCount: 3)
    context.insert(agreement)

    let installment1 = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 400)
    let installment2 = Installment(agreement: agreement, number: 2, dueDate: .now, amount: 400)
    let installment3 = Installment(agreement: agreement, number: 3, dueDate: .now, amount: 400)

    context.insert(installment1)
    context.insert(installment2)
    context.insert(installment3)

    try context.save()

    return (context, agreement)
}
