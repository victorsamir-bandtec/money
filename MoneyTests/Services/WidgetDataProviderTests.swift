import Foundation
import Testing
import SwiftData
@testable import Money

@MainActor
struct WidgetDataProviderTests {
    let container: ModelContainer
    let context: ModelContext
    let provider: WidgetDataProvider

    init() throws {
        // Create in-memory container for testing
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            FixedExpense.self,
            SalarySnapshot.self,
            CashTransaction.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        provider = WidgetDataProvider(container: container)
    }

    // MARK: - fetchWidgetSummary Tests

    @Test("Retorna summary vazio quando não há dados")
    func fetchesEmptySummary() async throws {
        let summary = try await provider.fetchWidgetSummary()

        #expect(summary.salary == .zero)
        #expect(summary.received == .zero)
        #expect(summary.overdue == .zero)
        #expect(summary.fixedExpenses == .zero)
        #expect(summary.planned == .zero)
        #expect(summary.availableToSpend == .zero)
        #expect(summary.isEmpty == true)
    }

    @Test("Calcula overdue corretamente separando de planned")
    func calculatesOverdueAndPlannedSeparately() async throws {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Create debtor and agreement
        let debtor = Debtor(name: "Test Debtor", contact: nil)
        context.insert(debtor)

        let agreement = DebtAgreement(
            debtor: debtor,
            title: "Test Agreement",
            principal: 300,
            installmentCount: 3,
            firstDueDate: yesterday
        )
        context.insert(agreement)

        // Create installments: 1 overdue, 1 planned, 1 paid
        let overdueInstallment = Installment(
            agreement: agreement,
            number: 1,
            amount: 100,
            dueDate: yesterday,
            status: .pending
        )
        context.insert(overdueInstallment)

        let plannedInstallment = Installment(
            agreement: agreement,
            number: 2,
            amount: 100,
            dueDate: tomorrow,
            status: .pending
        )
        context.insert(plannedInstallment)

        let paidInstallment = Installment(
            agreement: agreement,
            number: 3,
            amount: 100,
            dueDate: tomorrow,
            status: .paid
        )
        context.insert(paidInstallment)

        try context.save()

        let summary = try await provider.fetchWidgetSummary(for: today)

        #expect(summary.overdue == 100)
        #expect(summary.planned == 100)
        #expect(summary.remainingToReceive == 200)
    }

    @Test("Inclui parcialmente pagas no cálculo de overdue")
    func includesPartiallyPaidInOverdue() async throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: today))!

        let debtor = Debtor(name: "Test", contact: nil)
        context.insert(debtor)

        let agreement = DebtAgreement(
            debtor: debtor,
            title: "Test",
            principal: 100,
            installmentCount: 1,
            firstDueDate: yesterday
        )
        context.insert(agreement)

        let installment = Installment(
            agreement: agreement,
            number: 1,
            amount: 100,
            dueDate: yesterday,
            status: .partiallyPaid
        )
        context.insert(installment)

        // Add partial payment of 30
        let payment = Payment(installment: installment, amount: 30, date: today)
        context.insert(payment)

        try context.save()

        let summary = try await provider.fetchWidgetSummary(for: today)

        // Should have 70 remaining (100 - 30)
        #expect(summary.overdue == 70)
    }

    @Test("Calcula received do mês corrente")
    func calculatesReceivedForCurrentMonth() async throws {
        let calendar = Calendar.current
        let today = Date()
        let monthStart = calendar.dateInterval(of: .month, for: today)!.start

        let debtor = Debtor(name: "Test", contact: nil)
        context.insert(debtor)

        let agreement = DebtAgreement(
            debtor: debtor,
            title: "Test",
            principal: 100,
            installmentCount: 1,
            firstDueDate: monthStart
        )
        context.insert(agreement)

        let installment = Installment(
            agreement: agreement,
            number: 1,
            amount: 100,
            dueDate: monthStart,
            status: .paid
        )
        context.insert(installment)

        // Payment in current month
        let payment = Payment(installment: installment, amount: 100, date: today)
        context.insert(payment)

        try context.save()

        let summary = try await provider.fetchWidgetSummary(for: today)

        #expect(summary.received == 100)
    }

    @Test("Inclui fixedExpenses ativas no summary")
    func includesActiveFixedExpenses() async throws {
        let activeExpense = FixedExpense(name: "Rent", amount: 500, active: true)
        context.insert(activeExpense)

        let inactiveExpense = FixedExpense(name: "Old Subscription", amount: 20, active: false)
        context.insert(inactiveExpense)

        try context.save()

        let summary = try await provider.fetchWidgetSummary()

        #expect(summary.fixedExpenses == 500)
    }

    @Test("Inclui salário do mês corrente")
    func includesSalaryForCurrentMonth() async throws {
        let calendar = Calendar.current
        let today = Date()
        let monthStart = calendar.dateInterval(of: .month, for: today)!.start

        let salary = SalarySnapshot(amount: 4200, referenceMonth: monthStart)
        context.insert(salary)

        try context.save()

        let summary = try await provider.fetchWidgetSummary(for: today)

        #expect(summary.salary == 4200)
    }

    @Test("Inclui transações variáveis do mês")
    func includesVariableTransactionsForMonth() async throws {
        let calendar = Calendar.current
        let today = Date()

        let income = CashTransaction(
            date: today,
            amount: 150,
            type: .income,
            category: "Freelance"
        )
        context.insert(income)

        let expense = CashTransaction(
            date: today,
            amount: 80,
            type: .expense,
            category: "Food"
        )
        context.insert(expense)

        try context.save()

        let summary = try await provider.fetchWidgetSummary(for: today)

        #expect(summary.variableIncome == 150)
        #expect(summary.variableExpenses == 80)
    }

    @Test("Calcula availableToSpend corretamente")
    func calculatesAvailableToSpendCorrectly() async throws {
        let calendar = Calendar.current
        let today = Date()
        let monthStart = calendar.dateInterval(of: .month, for: today)!.start

        // Add salary
        let salary = SalarySnapshot(amount: 5000, referenceMonth: monthStart)
        context.insert(salary)

        // Add fixed expense
        let fixedExpense = FixedExpense(name: "Rent", amount: 1500, active: true)
        context.insert(fixedExpense)

        // Add variable expense
        let varExpense = CashTransaction(
            date: today,
            amount: 200,
            type: .expense,
            category: "Food"
        )
        context.insert(varExpense)

        // Add planned income (debtor payment)
        let debtor = Debtor(name: "Test", contact: nil)
        context.insert(debtor)

        let agreement = DebtAgreement(
            debtor: debtor,
            title: "Test",
            principal: 300,
            installmentCount: 1,
            firstDueDate: calendar.date(byAdding: .day, value: 5, to: today)!
        )
        context.insert(agreement)

        let plannedInstallment = Installment(
            agreement: agreement,
            number: 1,
            amount: 300,
            dueDate: calendar.date(byAdding: .day, value: 5, to: today)!,
            status: .pending
        )
        context.insert(plannedInstallment)

        try context.save()

        let summary = try await provider.fetchWidgetSummary(for: today)

        // available = salary + planned - (fixedExpenses + varExpenses)
        // = 5000 + 300 - (1500 + 200) = 3600
        #expect(summary.availableToSpend == 3600)
    }

    // MARK: - fetchUpcomingInstallments Tests

    @Test("Retorna lista vazia quando não há installments")
    func fetchesEmptyInstallmentsList() async throws {
        let installments = try await provider.fetchUpcomingInstallments()

        #expect(installments.isEmpty)
    }

    @Test("Busca installments dentro da janela de 14 dias")
    func fetchesInstallmentsWithinWindow() async throws {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)

        let debtor = Debtor(name: "Test", contact: nil)
        context.insert(debtor)

        let agreement = DebtAgreement(
            debtor: debtor,
            title: "Test Agreement",
            principal: 300,
            installmentCount: 3,
            firstDueDate: startOfDay
        )
        context.insert(agreement)

        // Inside window (today)
        let insideWindow1 = Installment(
            agreement: agreement,
            number: 1,
            amount: 100,
            dueDate: calendar.date(byAdding: .day, value: 1, to: startOfDay)!,
            status: .pending
        )
        context.insert(insideWindow1)

        // Inside window (7 days)
        let insideWindow2 = Installment(
            agreement: agreement,
            number: 2,
            amount: 100,
            dueDate: calendar.date(byAdding: .day, value: 7, to: startOfDay)!,
            status: .pending
        )
        context.insert(insideWindow2)

        // Outside window (20 days)
        let outsideWindow = Installment(
            agreement: agreement,
            number: 3,
            amount: 100,
            dueDate: calendar.date(byAdding: .day, value: 20, to: startOfDay)!,
            status: .pending
        )
        context.insert(outsideWindow)

        try context.save()

        let installments = try await provider.fetchUpcomingInstallments(for: today)

        #expect(installments.count == 2)
    }

    @Test("Inclui installments em atraso")
    func includesOverdueInstallments() async throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: today))!

        let debtor = Debtor(name: "Test", contact: nil)
        context.insert(debtor)

        let agreement = DebtAgreement(
            debtor: debtor,
            title: "Test",
            principal: 100,
            installmentCount: 1,
            firstDueDate: yesterday
        )
        context.insert(agreement)

        let overdueInstallment = Installment(
            agreement: agreement,
            number: 1,
            amount: 100,
            dueDate: yesterday,
            status: .overdue
        )
        context.insert(overdueInstallment)

        try context.save()

        let installments = try await provider.fetchUpcomingInstallments(for: today)

        #expect(installments.count == 1)
        #expect(installments.first?.isOverdue == true)
    }

    @Test("Ordena installments por dueDate")
    func sortsInstallmentsByDueDate() async throws {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)

        let debtor = Debtor(name: "Test", contact: nil)
        context.insert(debtor)

        let agreement = DebtAgreement(
            debtor: debtor,
            title: "Test",
            principal: 300,
            installmentCount: 3,
            firstDueDate: startOfDay
        )
        context.insert(agreement)

        // Create in wrong order
        let later = Installment(
            agreement: agreement,
            number: 3,
            amount: 100,
            dueDate: calendar.date(byAdding: .day, value: 10, to: startOfDay)!,
            status: .pending
        )
        context.insert(later)

        let earlier = Installment(
            agreement: agreement,
            number: 1,
            amount: 100,
            dueDate: calendar.date(byAdding: .day, value: 2, to: startOfDay)!,
            status: .pending
        )
        context.insert(earlier)

        let middle = Installment(
            agreement: agreement,
            number: 2,
            amount: 100,
            dueDate: calendar.date(byAdding: .day, value: 5, to: startOfDay)!,
            status: .pending
        )
        context.insert(middle)

        try context.save()

        let installments = try await provider.fetchUpcomingInstallments(for: today)

        #expect(installments.count == 3)
        #expect(installments[0].dueDate == earlier.dueDate)
        #expect(installments[1].dueDate == middle.dueDate)
        #expect(installments[2].dueDate == later.dueDate)
    }

    @Test("Respeita limite máximo de installments")
    func respectsMaximumLimit() async throws {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)

        let debtor = Debtor(name: "Test", contact: nil)
        context.insert(debtor)

        let agreement = DebtAgreement(
            debtor: debtor,
            title: "Test",
            principal: 1000,
            installmentCount: 10,
            firstDueDate: startOfDay
        )
        context.insert(agreement)

        // Create 10 installments
        for i in 1...10 {
            let installment = Installment(
                agreement: agreement,
                number: i,
                amount: 100,
                dueDate: calendar.date(byAdding: .day, value: i, to: startOfDay)!,
                status: .pending
            )
            context.insert(installment)
        }

        try context.save()

        let installments = try await provider.fetchUpcomingInstallments(limit: 3, for: today)

        #expect(installments.count == 3)
    }

    @Test("Filtra installments pagas")
    func filtersPaidInstallments() async throws {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))!

        let debtor = Debtor(name: "Test", contact: nil)
        context.insert(debtor)

        let agreement = DebtAgreement(
            debtor: debtor,
            title: "Test",
            principal: 200,
            installmentCount: 2,
            firstDueDate: tomorrow
        )
        context.insert(agreement)

        let paidInstallment = Installment(
            agreement: agreement,
            number: 1,
            amount: 100,
            dueDate: tomorrow,
            status: .paid
        )
        context.insert(paidInstallment)

        let pendingInstallment = Installment(
            agreement: agreement,
            number: 2,
            amount: 100,
            dueDate: calendar.date(byAdding: .day, value: 2, to: tomorrow)!,
            status: .pending
        )
        context.insert(pendingInstallment)

        try context.save()

        let installments = try await provider.fetchUpcomingInstallments(for: today)

        #expect(installments.count == 1)
        #expect(installments.first?.id == pendingInstallment.id)
    }

    @Test("Popula displayTitle corretamente")
    func populatesDisplayTitle() async throws {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))!

        let debtor = Debtor(name: "João Silva", contact: nil)
        context.insert(debtor)

        // Agreement with title
        let agreementWithTitle = DebtAgreement(
            debtor: debtor,
            title: "Empréstimo Pessoal",
            principal: 100,
            installmentCount: 1,
            firstDueDate: tomorrow
        )
        context.insert(agreementWithTitle)

        let installmentWithTitle = Installment(
            agreement: agreementWithTitle,
            number: 1,
            amount: 100,
            dueDate: tomorrow,
            status: .pending
        )
        context.insert(installmentWithTitle)

        // Agreement without title
        let agreementWithoutTitle = DebtAgreement(
            debtor: debtor,
            title: nil,
            principal: 100,
            installmentCount: 1,
            firstDueDate: calendar.date(byAdding: .day, value: 2, to: tomorrow)!
        )
        context.insert(agreementWithoutTitle)

        let installmentWithoutTitle = Installment(
            agreement: agreementWithoutTitle,
            number: 1,
            amount: 100,
            dueDate: calendar.date(byAdding: .day, value: 2, to: tomorrow)!,
            status: .pending
        )
        context.insert(installmentWithoutTitle)

        try context.save()

        let installments = try await provider.fetchUpcomingInstallments(for: today)

        #expect(installments.count == 2)
        #expect(installments[0].displayTitle == "Empréstimo Pessoal")
        #expect(installments[1].displayTitle == "João Silva")
    }
}
