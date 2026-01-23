import Foundation
import Testing
import SwiftData
@testable import Money

@MainActor
struct EndToEndFlowTests {
    @Test("Fluxo completo: criar devedor → acordo → parcelas → pagamentos → fechamento")
    func completeDebtorToClosureFlow() async throws {
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

        // 1. Criar devedor
        let debtorsListVM = DebtorsListViewModel(context: context)
        try debtorsListVM.load()

        debtorsListVM.addDebtor(name: "Cliente End-to-End", phone: "11999999999", note: "Teste integração")
        #expect(debtorsListVM.debtors.count == 1)

        let debtor = try #require(debtorsListVM.debtors.first)

        // 2. Criar acordo
        let calculator = FinanceCalculator()
        let debtService = DebtService(calculator: calculator)
        let debtorDetailVM = DebtorDetailViewModel(
            debtor: debtor,
            context: context,
            calculator: calculator,
            debtService: debtService,
            notificationScheduler: nil
        )
        try debtorDetailVM.load()

        var agreementDraft = AgreementDraft()
        agreementDraft.title = "Empréstimo Teste"
        agreementDraft.principal = Decimal(1200)
        agreementDraft.installmentCount = 3
        agreementDraft.startDate = Date()

        debtorDetailVM.createAgreement(from: agreementDraft)
        try debtorDetailVM.load()

        #expect(debtorDetailVM.agreements.count == 1)
        let agreement = try #require(debtorDetailVM.agreements.first)
        #expect(debtorDetailVM.installments.count == 3)

        // 3. Verificar parcelas criadas
        let agreementDetailVM = AgreementDetailViewModel(
            agreement: agreement,
            context: context,
            notificationScheduler: nil
        )
        try agreementDetailVM.load()

        #expect(agreementDetailVM.installments.count == 3)
        #expect(agreementDetailVM.totalAmount == Decimal(1200))
        #expect(agreementDetailVM.totalPaid == .zero)
        #expect(!agreement.closed)

        // 4. Pagar primeira parcela totalmente
        let installment1 = agreementDetailVM.installments[0]
        agreementDetailVM.markAsPaidFull(installment1, method: .pix)
        try agreementDetailVM.load()

        #expect(installment1.status == .paid)
        #expect(agreementDetailVM.totalPaid == Decimal(400))
        #expect(!agreement.closed)

        // 5. Pagar segunda parcela parcialmente
        let installment2 = agreementDetailVM.installments[1]
        agreementDetailVM.registerPayment(
            for: installment2,
            amount: Decimal(200),
            date: .now,
            method: .cash,
            note: "Pagamento parcial"
        )
        try agreementDetailVM.load()

        #expect(installment2.status == .partial)
        #expect(installment2.paidAmount == Decimal(200))
        #expect(agreementDetailVM.totalPaid == Decimal(600))

        // 6. Completar segunda parcela
        agreementDetailVM.registerPayment(
            for: installment2,
            amount: Decimal(200),
            date: .now,
            method: .transfer,
            note: "Completando"
        )
        try agreementDetailVM.load()

        #expect(installment2.status == .paid)
        #expect(installment2.paidAmount == Decimal(400))
        #expect(agreementDetailVM.totalPaid == Decimal(800))
        #expect(!agreement.closed)

        // 7. Pagar terceira parcela e fechar acordo
        let installment3 = agreementDetailVM.installments[2]
        agreementDetailVM.markAsPaidFull(installment3)
        try agreementDetailVM.load()

        #expect(installment3.status == .paid)
        #expect(agreementDetailVM.totalPaid == Decimal(1200))
        #expect(agreementDetailVM.remainingAmount == .zero)
        #expect(agreement.closed)
        #expect(agreementDetailVM.progressPercentage == 100.0)

        // 8. Verificar estado final no DebtorsListViewModel
        try debtorsListVM.load()
        let finalSummary = debtorsListVM.summary(for: debtor)

        #expect(finalSummary.totalAgreements == 1)
        #expect(finalSummary.activeAgreements == 0) // Acordo fechado
        #expect(finalSummary.paidInstallments == 3)
        #expect(finalSummary.totalAmount == .zero) // Apenas acordos ativos
    }

    @Test("Fluxo de reabertura: fechar acordo → marcar como pendente → reabrir")
    func reopenAgreementFlow() async throws {
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

        let debtor = Debtor(name: "Reabrir Teste")
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 600, startDate: .now, installmentCount: 2)
        context.insert(agreement)

        let installment1 = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 300)
        let installment2 = Installment(agreement: agreement, number: 2, dueDate: .now, amount: 300)
        context.insert(installment1)
        context.insert(installment2)
        try context.save()

        let scheduler = NotificationSchedulerSpy()
        let calculator = FinanceCalculator()
        let debtService = DebtService(calculator: calculator)
        let debtorDetailVM = DebtorDetailViewModel(
            debtor: debtor,
            context: context,
            calculator: calculator,
            debtService: debtService,
            notificationScheduler: scheduler
        )

        try debtorDetailVM.load()
        #expect(!agreement.closed)

        // Fechar acordo
        debtorDetailVM.mark(installment: installment1, as: .paid)
        await debtorDetailVM.reminderSyncTaskForTesting?.value

        debtorDetailVM.mark(installment: installment2, as: .paid)
        await debtorDetailVM.reminderSyncTaskForTesting?.value

        try debtorDetailVM.load()
        #expect(agreement.closed)
        #expect(scheduler.actions.contains(.cancelAgreement(agreementID: agreement.id)))

        // Reabrir acordo
        scheduler.reset()
        debtorDetailVM.mark(installment: installment2, as: .pending)
        await debtorDetailVM.reminderSyncTaskForTesting?.value

        try debtorDetailVM.load()
        #expect(!agreement.closed)
        #expect(installment2.status == .pending)
    }

    @Test("Fluxo de notificações: criar acordo → pagar → cancelar notificações")
    func notificationSyncFlow() async throws {
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

        let debtor = Debtor(name: "Notificações Teste")
        context.insert(debtor)

        let scheduler = NotificationSchedulerSpy()
        let calculator = FinanceCalculator()
        let debtService = DebtService(calculator: calculator)
        let debtorDetailVM = DebtorDetailViewModel(
            debtor: debtor,
            context: context,
            calculator: calculator,
            debtService: debtService,
            notificationScheduler: scheduler
        )

        try debtorDetailVM.load()

        var draft = AgreementDraft()
        draft.principal = Decimal(900)
        draft.installmentCount = 3
        draft.startDate = Date()

        debtorDetailVM.createAgreement(from: draft)
        try debtorDetailVM.load()

        let agreement = try #require(debtorDetailVM.agreements.first)

        // Verificar que notificações foram agendadas
        #expect(scheduler.actions.filter { action in
            if case .schedule = action { return true }
            return false
        }.count == 3)

        // Pagar parcela e verificar sincronização
        let installment1 = debtorDetailVM.installments[0]
        scheduler.reset()

        debtorDetailVM.mark(installment: installment1, as: .paid)
        await debtorDetailVM.reminderSyncTaskForTesting?.value

        #expect(scheduler.actions.contains(.cancelAgreement(agreementID: agreement.id)))
        #expect(scheduler.actions.filter { action in
            if case .schedule = action { return true }
            return false
        }.count == 2) // Reagendou as 2 restantes
    }

    @Test("Fluxo de métricas financeiras: dashboard reflete mudanças")
    func dashboardMetricsFlow() throws {
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

        // Criar dados base
        let debtor = Debtor(name: "Dashboard Test")
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 2)
        context.insert(agreement)

        let calendar = Calendar.current
        let futureDate = calendar.date(byAdding: .day, value: 5, to: .now)!

        let installment1 = Installment(agreement: agreement, number: 1, dueDate: futureDate, amount: 500)
        let installment2 = Installment(agreement: agreement, number: 2, dueDate: futureDate, amount: 500)
        context.insert(installment1)
        context.insert(installment2)

        context.insert(SalarySnapshot(referenceMonth: .now, amount: 4000))
        context.insert(FixedExpense(name: "Aluguel", amount: 1200, dueDay: 5))
        try context.save()

        // Verificar dashboard inicial
        let dashboardVM = DashboardViewModel(context: context, currencyFormatter: CurrencyFormatter())
        try dashboardVM.load(currentDate: .now)

        #expect(dashboardVM.summary.planned == Decimal(1000))
        #expect(dashboardVM.summary.overdue == .zero)
        #expect(dashboardVM.summary.salary == Decimal(4000))
        #expect(dashboardVM.summary.fixedExpenses == Decimal(1200))

        // Pagar parcela e recarregar
        installment1.paidAmount = Decimal(500)
        installment1.status = .paid
        try context.save()

        try dashboardVM.load(currentDate: .now)

        #expect(dashboardVM.summary.planned == Decimal(500))
        #expect(dashboardVM.summary.received == Decimal(500))
    }
}
