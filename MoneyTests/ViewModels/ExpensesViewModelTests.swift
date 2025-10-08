import Foundation
import Testing
import SwiftData
@testable import Money

struct ExpensesViewModelTests {
    @Test("Aplica filtros por texto, status e categoria") @MainActor
    func filtersExpenses() throws {
        let schema = Schema([
            FixedExpense.self,
            SalarySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let internet = FixedExpense(name: "Internet", amount: 120, category: "Casa", dueDay: 10)
        let gym = FixedExpense(name: "Academia", amount: 90, category: "Saúde", dueDay: 5)
        let archived = FixedExpense(name: "Curso", amount: 200, category: "Educação", dueDay: 20, active: false)

        context.insert(internet)
        context.insert(gym)
        context.insert(archived)
        try context.save()

        let viewModel = ExpensesViewModel(context: context)
        try viewModel.load()

        #expect(viewModel.filteredExpenses.count == 2)

        viewModel.searchText = "net"
        #expect(viewModel.filteredExpenses.count == 1)
        #expect(viewModel.filteredExpenses.first?.id == internet.id)

        viewModel.searchText = ""
        viewModel.statusFilter = .archived
        #expect(viewModel.filteredExpenses.count == 1)
        #expect(viewModel.filteredExpenses.first?.id == archived.id)

        viewModel.statusFilter = .all
        viewModel.selectedCategory = "Saúde"
        #expect(viewModel.filteredExpenses.count == 1)
        #expect(viewModel.filteredExpenses.first?.id == gym.id)
    }

    @Test("Calcula métricas e cobertura a partir do salário") @MainActor
    func calculatesMetrics() throws {
        let schema = Schema([
            FixedExpense.self,
            SalarySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        context.insert(FixedExpense(name: "Aluguel", amount: 1500, category: "Casa", dueDay: 1))
        context.insert(FixedExpense(name: "Internet", amount: 120, category: "Casa", dueDay: 10))

        let calendar = Calendar.current
        let referenceMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        context.insert(SalarySnapshot(referenceMonth: referenceMonth, amount: 4000))
        try context.save()

        let viewModel = ExpensesViewModel(context: context)
        try viewModel.load(currentMonth: referenceMonth)

        #expect(viewModel.metrics.totalExpenses == Decimal(1620))
        #expect(viewModel.metrics.salaryAmount == Decimal(4000))
        #expect(viewModel.metrics.remaining == Decimal(2380))

        let coverage = try #require(viewModel.metrics.coverage)
        #expect(abs(coverage - 0.405) < 0.0001)

        #expect(viewModel.availableCategories.contains("Casa"))
        #expect(viewModel.availableCategories.count == 1)
    }

    @Test("Adiciona despesa e emite notificação") @MainActor
    func addsExpenseAndPostsNotification() throws {
        let schema = Schema([
            FixedExpense.self,
            SalarySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let viewModel = ExpensesViewModel(context: context)
        try viewModel.load()

        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(forName: .financialDataDidChange, object: nil, queue: nil) { _ in
            notificationReceived = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        viewModel.addExpense(name: "Nova Despesa", amount: 300, category: "Teste", dueDay: 15, note: "Nota teste")

        #expect(notificationReceived)
        #expect(viewModel.expenses.count == 1)
        #expect(viewModel.expenses.first?.name == "Nova Despesa")
    }

    @Test("Arquiva e desarquiva despesa") @MainActor
    func archivesAndUnarchivesExpense() throws {
        let schema = Schema([
            FixedExpense.self,
            SalarySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let expense = FixedExpense(name: "Teste", amount: 100, dueDay: 5, active: true)
        context.insert(expense)
        try context.save()

        let viewModel = ExpensesViewModel(context: context)
        try viewModel.load()

        #expect(viewModel.filteredExpenses.count == 1)

        viewModel.toggleArchive(expense)
        #expect(!expense.active)
        #expect(viewModel.filteredExpenses.isEmpty)

        viewModel.statusFilter = .archived
        #expect(viewModel.filteredExpenses.count == 1)
    }

    @Test("Deleta despesa corretamente") @MainActor
    func deletesExpense() throws {
        let schema = Schema([
            FixedExpense.self,
            SalarySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let expense = FixedExpense(name: "Para Deletar", amount: 100, dueDay: 5)
        context.insert(expense)
        try context.save()

        let viewModel = ExpensesViewModel(context: context)
        try viewModel.load()

        #expect(viewModel.expenses.count == 1)

        viewModel.deleteExpense(expense)
        #expect(viewModel.expenses.isEmpty)
    }
}
