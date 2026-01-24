import Foundation
import Testing
import SwiftData
@testable import Money

struct CashTransactionTests {
    @Test("Normaliza categoria corretamente") @MainActor
    func normalizesCategory() throws {
        let schema = Schema([CashTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        // Categoria válida
        let transaction1 = CashTransaction(date: .now, amount: 100, type: .expense, category: "Mercado")!
        context.insert(transaction1)
        #expect(transaction1.normalizedCategory == "Mercado")

        // Categoria vazia
        let transaction2 = CashTransaction(date: .now, amount: 100, type: .expense, category: "")!
        context.insert(transaction2)
        #expect(transaction2.normalizedCategory == nil)

        // Categoria com espaços
        let transaction3 = CashTransaction(date: .now, amount: 100, type: .expense, category: "   ")!
        context.insert(transaction3)
        #expect(transaction3.normalizedCategory == nil)

        // Categoria nil
        let transaction4 = CashTransaction(date: .now, amount: 100, type: .expense, category: nil)!
        context.insert(transaction4)
        #expect(transaction4.normalizedCategory == nil)
    }

    @Test("Calcula signedAmount corretamente") @MainActor
    func calculatesSignedAmount() throws {
        let schema = Schema([CashTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        // Despesa deve ser negativa
        let expense = CashTransaction(date: .now, amount: 150, type: .expense)!
        context.insert(expense)
        #expect(expense.signedAmount == Decimal(-150))

        // Receita deve ser positiva
        let income = CashTransaction(date: .now, amount: 200, type: .income)!
        context.insert(income)
        #expect(income.signedAmount == Decimal(200))

        // Valor zero (via mutação, já que init requer > 0)
        let zeroExpense = CashTransaction(date: .now, amount: 1, type: .expense)!
        zeroExpense.amount = 0
        context.insert(zeroExpense)
        #expect(zeroExpense.signedAmount == .zero)

        let zeroIncome = CashTransaction(date: .now, amount: 1, type: .income)!
        zeroIncome.amount = 0
        context.insert(zeroIncome)
        #expect(zeroIncome.signedAmount == .zero)
    }

    @Test("Type enum conversão funciona corretamente") @MainActor
    func typeEnumConversion() throws {
        let schema = Schema([CashTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let transaction = CashTransaction(date: .now, amount: 100, type: .expense)!
        context.insert(transaction)

        #expect(transaction.type == .expense)
        #expect(transaction.typeRaw == "expense")

        transaction.type = .income
        #expect(transaction.typeRaw == "income")
    }

    @Test("Valida precondições de inicialização") @MainActor
    func validatesPreconditions() throws {
        let schema = Schema([CashTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        // Valor válido > 0
        #expect(throws: Never.self) {
            let valid = CashTransaction(date: .now, amount: 0.01, type: .expense)!
            context.insert(valid)
        }

        // Data e tipo válidos
        #expect(throws: Never.self) {
            let validExpense = CashTransaction(date: .now, amount: 100, type: .expense)!
            context.insert(validExpense)

            let validIncome = CashTransaction(date: .now, amount: 100, type: .income)!
            context.insert(validIncome)
        }
    }

    @Test("Armazena nota opcional corretamente") @MainActor
    func storesOptionalNote() throws {
        let schema = Schema([CashTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        // Com nota
        let withNote = CashTransaction(date: .now, amount: 100, type: .expense, note: "Compras do mês")!
        context.insert(withNote)
        #expect(withNote.note == "Compras do mês")

        // Sem nota
        let withoutNote = CashTransaction(date: .now, amount: 100, type: .expense, note: nil)!
        context.insert(withoutNote)
        #expect(withoutNote.note == nil)
    }

    @Test("CreatedAt é armazenado corretamente") @MainActor
    func storesCreatedAtCorrectly() throws {
        let schema = Schema([CashTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let beforeCreation = Date()
        let transaction = CashTransaction(date: .now, amount: 100, type: .expense)!
        let afterCreation = Date()

        context.insert(transaction)

        #expect(transaction.createdAt >= beforeCreation)
        #expect(transaction.createdAt <= afterCreation)

        // Com createdAt customizado
        let customDate = Date(timeIntervalSince1970: 1000000)
        let customTransaction = CashTransaction(
            date: .now,
            amount: 100,
            type: .expense,
            createdAt: customDate
        )!
        context.insert(customTransaction)
        #expect(customTransaction.createdAt == customDate)
    }
}
