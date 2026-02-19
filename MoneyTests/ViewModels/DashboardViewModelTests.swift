import Foundation
import Testing
import SwiftData
@testable import Money

struct DashboardViewModelTests {
    @Test("Inclui parcelas vencidas e próximas no dashboard") @MainActor
    func loadsOverdueAndUpcoming() throws {
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            CashTransaction.self,
            FixedExpense.self,
            SalarySnapshot.self,
            MonthlySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let debtor = Debtor(name: "Cliente Teste")!
        context.insert(debtor)

        let now = Date(timeIntervalSince1970: 1_700_000_000) // referência fixa para estabilidade dos testes
        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: now, installmentCount: 3)!
        context.insert(agreement)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let overdueDate = calendar.date(byAdding: .day, value: -10, to: now)!
        let upcomingDate = calendar.date(byAdding: .day, value: 5, to: now)!
        let futurePaidDate = calendar.date(byAdding: .day, value: 25, to: now)!

        let overdueInstallment = Installment(agreement: agreement, number: 1, dueDate: overdueDate, amount: 100)!
        overdueInstallment.paidAmount = 20
        overdueInstallment.status = .partial
        context.insert(overdueInstallment)

        let upcomingInstallment = Installment(agreement: agreement, number: 2, dueDate: upcomingDate, amount: 150)!
        context.insert(upcomingInstallment)

        let paidInstallment = Installment(agreement: agreement, number: 3, dueDate: futurePaidDate, amount: 200, status: .paid)!
        paidInstallment.paidAmount = 200
        context.insert(paidInstallment)

        try context.save()
        try FinancialProjectionUpdater().refreshForCurrentMonth(context: context, referenceDate: now)

        let viewModel = DashboardViewModel(context: context, currencyFormatter: CurrencyFormatter())
        try viewModel.load(currentDate: now)

        #expect(viewModel.summary.planned == Decimal(150))
        #expect(viewModel.summary.overdue == Decimal(80))
        #expect(viewModel.summary.remainingToReceive == Decimal(230))
        // Nova regra: availableToSpend considera apenas liquidez real (Salário + Recebidos - Despesas).
        // Neste teste: Salário 0, Recebidos 0 (não há Payments), Despesas 0.
        #expect(viewModel.summary.availableToSpend == Decimal(0))
        #expect(viewModel.upcoming.count == 2)

        let upcomingIdentifiers = viewModel.upcoming.map(\.id)
        #expect(upcomingIdentifiers.contains(overdueInstallment.id))
        #expect(upcomingIdentifiers.contains(upcomingInstallment.id))
        #expect(viewModel.upcoming.first?.id == overdueInstallment.id)
        #expect(viewModel.alerts.map(\.id) == upcomingIdentifiers)
    }

    @Test("Considera transacoes variaveis no resumo") @MainActor
    func includesVariableTransactionsInSummary() throws {
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            CashTransaction.self,
            FixedExpense.self,
            SalarySnapshot.self,
            MonthlySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceDate = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15, hour: 12))!

        context.insert(CashTransaction(date: referenceDate, amount: 120, type: .expense, category: "Mercado")!)
        context.insert(CashTransaction(date: referenceDate, amount: 60, type: .income, category: "Freelancer")!)
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: referenceDate)!
        context.insert(CashTransaction(date: previousMonth, amount: 50, type: .expense, category: "Viagem")!)
        try context.save()
        try FinancialProjectionUpdater().refreshForCurrentMonth(context: context, referenceDate: referenceDate)

        let viewModel = DashboardViewModel(context: context, currencyFormatter: CurrencyFormatter())
        try viewModel.load(currentDate: referenceDate)

        #expect(viewModel.summary.variableExpenses == Decimal(120))
        #expect(viewModel.summary.variableIncome == Decimal(60))
        #expect(viewModel.summary.availableToSpend == Decimal(-60))
        #expect(viewModel.summary.totalExpenses == Decimal(120))
        #expect(viewModel.summary.variableBalance == Decimal(-60))
    }

    @Test("Calcula despesas fixas corretamente") @MainActor
    func calculatesFixedExpensesCorrectly() throws {
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            CashTransaction.self,
            FixedExpense.self,
            SalarySnapshot.self,
            MonthlySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        context.insert(FixedExpense(name: "Aluguel", amount: 1000, dueDay: 5, active: true)!)
        context.insert(FixedExpense(name: "Internet", amount: 100, dueDay: 10, active: true)!)
        context.insert(FixedExpense(name: "Curso Arquivado", amount: 200, dueDay: 15, active: false)!)
        try context.save()
        try FinancialProjectionUpdater().refreshForCurrentMonth(context: context, referenceDate: Date.now)

        let viewModel = DashboardViewModel(context: context, currencyFormatter: CurrencyFormatter())
        try viewModel.load(currentDate: Date.now)

        #expect(viewModel.summary.fixedExpenses == Decimal(1100))
        #expect(viewModel.summary.totalExpenses == Decimal(1100))
    }

    @Test("Inclui salário no cálculo de disponível") @MainActor
    func includesSalaryInAvailableCalculation() throws {
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            CashTransaction.self,
            FixedExpense.self,
            SalarySnapshot.self,
            MonthlySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let calendar = Calendar.current
        let currentMonth = calendar.startOfDay(for: Date.now)
        context.insert(SalarySnapshot(referenceMonth: currentMonth, amount: 5000)!)
        context.insert(FixedExpense(name: "Aluguel", amount: 1500, dueDay: 5)!)
        try context.save()
        try FinancialProjectionUpdater().refreshForCurrentMonth(context: context, referenceDate: Date.now)

        let viewModel = DashboardViewModel(context: context, currencyFormatter: CurrencyFormatter())
        try viewModel.load(currentDate: Date.now)

        #expect(viewModel.summary.salary == Decimal(5000))
        #expect(viewModel.summary.fixedExpenses == Decimal(1500))
        #expect(viewModel.summary.availableToSpend == Decimal(3500))
    }

    @Test("Limpar dados zera resumo e parcelas futuras") @MainActor
    func clearingDataResetsDashboardState() throws {
        let environment = AppEnvironment(isStoredInMemoryOnly: true)

        try environment.sampleDataService.populateData()
        environment.bootstrapReadModels()

        let viewModel = DashboardViewModel(
            context: environment.modelContext,
            currencyFormatter: environment.currencyFormatter
        )

        try viewModel.load(currentDate: Date.now)
        #expect(viewModel.summary != DashboardSummary.empty)
        #expect(!viewModel.upcoming.isEmpty)

        try environment.sampleDataService.clearAllData()
        environment.bootstrapReadModels()
        try viewModel.load(currentDate: Date.now)

        #expect(viewModel.summary == DashboardSummary.empty)
        #expect(viewModel.upcoming.isEmpty)
        #expect(viewModel.alerts.isEmpty)
    }
}

struct DashboardSummaryTests {
    @Test("Calcula saldo disponível agregando entradas e saídas")
    func computesAvailableBalance() {
        let summary = DashboardSummary(
            salary: 4000,
            received: 850,
            overdue: 300,
            fixedExpenses: 1200,
            planned: 700,
            variableExpenses: 150,
            variableIncome: 50
        )

        #expect(summary.remainingToReceive == Decimal(1000))
        // Nova fórmula: (Salary + Received + VariableIncome) - (FixedExpenses + VariableExpenses)
        // 4000 + 850 + 50 - (1200 + 150) = 4900 - 1350 = 3550
        #expect(summary.availableToSpend == Decimal(3550))
        #expect(summary.totalExpenses == Decimal(1350))
        #expect(summary.variableBalance == Decimal(-100))
    }
}
