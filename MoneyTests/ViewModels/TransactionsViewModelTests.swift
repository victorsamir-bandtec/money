import Foundation
import Testing
import SwiftData
@testable import Money

struct TransactionsViewModelTests {
    @Test("Carrega e filtra transacoes variaveis") @MainActor
    func loadsAndFiltersTransactions() throws {
        let schema = Schema([
            CashTransaction.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceMonth = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15, hour: 9))!

        let groceriesDate = calendar.date(from: DateComponents(year: 2024, month: 6, day: 10, hour: 13))!
        let taxiDate = calendar.date(from: DateComponents(year: 2024, month: 6, day: 3, hour: 8))!
        let freelanceDate = calendar.date(from: DateComponents(year: 2024, month: 6, day: 5, hour: 20))!
        let previousMonth = calendar.date(from: DateComponents(year: 2024, month: 5, day: 28, hour: 10))!

        context.insert(CashTransaction(date: groceriesDate, amount: 80, type: .expense, category: "Mercado", note: "Compras semanais"))
        context.insert(CashTransaction(date: taxiDate, amount: 45, type: .expense, category: "Transporte", note: "Táxi aeroporto"))
        context.insert(CashTransaction(date: freelanceDate, amount: 200, type: .income, category: "Freelancer", note: "Site institucional"))
        context.insert(CashTransaction(date: previousMonth, amount: 100, type: .income, category: "Bônus"))
        try context.save()

        let viewModel = TransactionsViewModel(context: context, calendar: calendar)
        try viewModel.load(for: referenceMonth)

        #expect(viewModel.metrics.totalExpenses == Decimal(125))
        #expect(viewModel.metrics.totalIncome == Decimal(200))
        #expect(viewModel.metrics.netBalance == Decimal(75))
        #expect(viewModel.availableCategories == ["Mercado", "Transporte"])
        #expect(viewModel.sections.count == 3)

        viewModel.typeFilter = .income
        let incomeTransactions = viewModel.sections.flatMap(\.transactions)
        #expect(incomeTransactions.count == 1)
        #expect(incomeTransactions.first?.type == .income)

        viewModel.typeFilter = .expenses
        viewModel.categoryFilter = "Mercado"
        let categoryTransactions = viewModel.sections.flatMap(\.transactions)
        #expect(categoryTransactions.count == 1)
        #expect(categoryTransactions.first?.category == "Mercado")

        viewModel.categoryFilter = nil
        viewModel.searchText = "táxi"
        let searchResults = viewModel.sections.flatMap(\.transactions)
        #expect(searchResults.count == 1)
        #expect(searchResults.first?.note?.contains("Táxi") == true)

        viewModel.searchText = ""
        viewModel.sortOrder = .amountDescending
        viewModel.typeFilter = .all

        let orderedSections = viewModel.sections
        let firstSectionFirstAmount = orderedSections.first?.transactions.first?.amount
        #expect(firstSectionFirstAmount == Decimal(200))
    }

    @Test("Adiciona transacao com sucesso") @MainActor
    func addTransactionSavesSuccessfully() throws {
        let schema = Schema([CashTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let calendar = Calendar.current
        let referenceDate = Date()

        let viewModel = TransactionsViewModel(context: context, calendar: calendar)
        try viewModel.load(for: referenceDate)

        #expect(viewModel.sections.isEmpty)

        viewModel.addTransaction(
            date: referenceDate,
            amount: 150,
            type: .expense,
            category: "Supermercado",
            note: "Compras mensais"
        )

        try viewModel.load(for: referenceDate)
        #expect(viewModel.sections.count == 1)

        let transaction = viewModel.sections.first?.transactions.first
        #expect(transaction?.amount == Decimal(150))
        #expect(transaction?.type == .expense)
        #expect(transaction?.category == "Supermercado")
        #expect(transaction?.note == "Compras mensais")
    }

    @Test("Atualiza transacao existente") @MainActor
    func updateTransactionModifiesExisting() throws {
        let schema = Schema([CashTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let calendar = Calendar.current
        let referenceDate = Date()

        let transaction = CashTransaction(
            date: referenceDate,
            amount: 100,
            type: .expense,
            category: "Original",
            note: "Nota original"
        )
        context.insert(transaction)
        try context.save()

        let viewModel = TransactionsViewModel(context: context, calendar: calendar)
        try viewModel.load(for: referenceDate)

        #expect(viewModel.sections.first?.transactions.first?.category == "Original")

        viewModel.updateTransaction(
            transaction,
            date: referenceDate,
            amount: 200,
            type: .income,
            category: "Atualizada",
            note: "Nota atualizada"
        )

        try viewModel.load(for: referenceDate)
        let updated = viewModel.sections.first?.transactions.first
        #expect(updated?.amount == Decimal(200))
        #expect(updated?.type == .income)
        #expect(updated?.category == "Atualizada")
        #expect(updated?.note == "Nota atualizada")
    }

    @Test("Remove transacao com sucesso") @MainActor
    func removeTransactionDeletesSuccessfully() throws {
        let schema = Schema([CashTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let calendar = Calendar.current
        let referenceDate = Date()

        let transaction = CashTransaction(
            date: referenceDate,
            amount: 100,
            type: .expense,
            category: "Para Deletar"
        )
        context.insert(transaction)
        try context.save()

        let viewModel = TransactionsViewModel(context: context, calendar: calendar)
        try viewModel.load(for: referenceDate)

        #expect(viewModel.sections.count == 1)

        viewModel.removeTransaction(transaction)

        try viewModel.load(for: referenceDate)
        #expect(viewModel.sections.isEmpty)
    }

    @Test("Adicionar transacao com valor invalido define erro") @MainActor
    func addTransactionWithInvalidAmountSetsError() throws {
        let schema = Schema([CashTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let viewModel = TransactionsViewModel(context: context)
        #expect(viewModel.error == nil)

        // Tentar adicionar com valor zero
        viewModel.addTransaction(
            date: .now,
            amount: 0,
            type: .expense,
            category: "Teste",
            note: nil
        )

        #expect(viewModel.error != nil)
        #expect(viewModel.sections.isEmpty)

        // Tentar adicionar com valor negativo
        viewModel.addTransaction(
            date: .now,
            amount: -50,
            type: .expense,
            category: "Teste",
            note: nil
        )

        #expect(viewModel.error != nil)
    }

    @Test("Observador de notificacao recarrega dados") @MainActor
    func notificationObserverReloadsData() async throws {
        let schema = Schema([CashTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let calendar = Calendar.current
        let referenceDate = Date()

        let viewModel = TransactionsViewModel(context: context, calendar: calendar)
        try viewModel.load(for: referenceDate)

        #expect(viewModel.sections.isEmpty)

        // Adicionar transação diretamente no contexto
        let transaction = CashTransaction(
            date: referenceDate,
            amount: 250,
            type: .income,
            category: "Notificação Teste"
        )
        context.insert(transaction)
        try context.save()

        // Disparar notificação
        NotificationCenter.default.post(name: .cashTransactionDataDidChange, object: nil)

        // Aguardar um pouco para o observador processar
        try await Task.sleep(nanoseconds: 150_000_000)
        await Task.yield()

        // Verificar que dados foram recarregados
        #expect(viewModel.sections.count == 1)
        #expect(viewModel.sections.first?.transactions.first?.category == "Notificação Teste")
    }
}
