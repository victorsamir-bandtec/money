import Foundation
import Testing
import SwiftData
@testable import Money

struct FixedExpenseTests {
    @Test("Calcula nextDueDate corretamente") @MainActor
    func calculatesNextDueDate() throws {
        let schema = Schema([FixedExpense.self, SalarySnapshot.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let expense = FixedExpense(name: "Aluguel", amount: 1000, dueDay: 5)!
        context.insert(expense)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Referência antes do dia de vencimento
        let beforeDueDate = calendar.date(from: DateComponents(year: 2024, month: 6, day: 3))!
        let nextDue1 = expense.nextDueDate(reference: beforeDueDate, calendar: calendar)
        let expected1 = calendar.date(from: DateComponents(year: 2024, month: 6, day: 5))!
        #expect(nextDue1 == expected1)

        // Referência no dia de vencimento
        let onDueDate = calendar.date(from: DateComponents(year: 2024, month: 6, day: 5))!
        let nextDue2 = expense.nextDueDate(reference: onDueDate, calendar: calendar)
        let expected2 = calendar.date(from: DateComponents(year: 2024, month: 6, day: 5))!
        #expect(nextDue2 == expected2)

        // Referência depois do dia de vencimento
        let afterDueDate = calendar.date(from: DateComponents(year: 2024, month: 6, day: 10))!
        let nextDue3 = expense.nextDueDate(reference: afterDueDate, calendar: calendar)
        let expected3 = calendar.date(from: DateComponents(year: 2024, month: 7, day: 5))!
        #expect(nextDue3 == expected3)
    }

    @Test("Ajusta nextDueDate para meses com menos dias") @MainActor
    func adjustsNextDueDateForShortMonths() throws {
        let schema = Schema([FixedExpense.self, SalarySnapshot.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        // Despesa com vencimento dia 31
        let expense = FixedExpense(name: "Teste", amount: 100, dueDay: 31)!
        context.insert(expense)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Fevereiro tem 28/29 dias
        let februaryRef = calendar.date(from: DateComponents(year: 2024, month: 2, day: 15))!
        let nextDueFeb = expense.nextDueDate(reference: februaryRef, calendar: calendar)

        // 2024 é ano bissexto, então fevereiro tem 29 dias
        let expectedFeb = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29))!
        #expect(nextDueFeb == expectedFeb)

        // Abril tem 30 dias
        let aprilRef = calendar.date(from: DateComponents(year: 2024, month: 4, day: 15))!
        let nextDueApril = expense.nextDueDate(reference: aprilRef, calendar: calendar)
        let expectedApril = calendar.date(from: DateComponents(year: 2024, month: 4, day: 30))!
        #expect(nextDueApril == expectedApril)

        // Maio tem 31 dias
        let mayRef = calendar.date(from: DateComponents(year: 2024, month: 5, day: 15))!
        let nextDueMay = expense.nextDueDate(reference: mayRef, calendar: calendar)
        let expectedMay = calendar.date(from: DateComponents(year: 2024, month: 5, day: 31))!
        #expect(nextDueMay == expectedMay)
    }

    @Test("Normaliza categoria corretamente") @MainActor
    func normalizesCategory() throws {
        let schema = Schema([FixedExpense.self, SalarySnapshot.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        // Categoria válida
        let expense1 = FixedExpense(name: "Teste 1", amount: 100, category: "Casa", dueDay: 5)!
        context.insert(expense1)
        #expect(expense1.normalizedCategory == "Casa")

        // Categoria vazia
        let expense2 = FixedExpense(name: "Teste 2", amount: 100, category: "", dueDay: 5)!
        context.insert(expense2)
        #expect(expense2.normalizedCategory == nil)

        // Categoria com espaços
        let expense3 = FixedExpense(name: "Teste 3", amount: 100, category: "   ", dueDay: 5)!
        context.insert(expense3)
        #expect(expense3.normalizedCategory == nil)

        // Categoria nil
        let expense4 = FixedExpense(name: "Teste 4", amount: 100, category: nil, dueDay: 5)!
        context.insert(expense4)
        #expect(expense4.normalizedCategory == nil)
    }

    @Test("Valida precondições de inicialização") @MainActor
    func validatesPreconditions() throws {
        let schema = Schema([FixedExpense.self, SalarySnapshot.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        // Nome válido
        #expect(throws: Never.self) {
            let valid = FixedExpense(name: "Válido", amount: 100, dueDay: 5)!
            context.insert(valid)
        }

        // Valor zero é permitido
        #expect(throws: Never.self) {
            let valid = FixedExpense(name: "Zero", amount: 0, dueDay: 5)!
            context.insert(valid)
        }

        // Dia de vencimento válido (1-31)
        #expect(throws: Never.self) {
            let valid1 = FixedExpense(name: "Dia 1", amount: 100, dueDay: 1)!
            context.insert(valid1)
            let valid31 = FixedExpense(name: "Dia 31", amount: 100, dueDay: 31)!
            context.insert(valid31)
        }
    }

    @Test("Status ativo/inativo funciona corretamente") @MainActor
    func activeStatusWorks() throws {
        let schema = Schema([FixedExpense.self, SalarySnapshot.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let expense = FixedExpense(name: "Teste", amount: 100, dueDay: 5, active: true)!
        context.insert(expense)

        #expect(expense.active)

        expense.active = false
        #expect(!expense.active)

        expense.active = true
        #expect(expense.active)
    }
}
