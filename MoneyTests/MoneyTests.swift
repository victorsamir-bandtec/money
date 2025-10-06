import Foundation
import Testing
import SwiftData
@testable import Money

struct FinanceCalculatorTests {
    let calculator = FinanceCalculator()

    @Test("Gera cronograma linear sem juros")
    func generateLinearSchedule() throws {
        let schedule = try calculator.generateSchedule(
            principal: 1200,
            installments: 12,
            monthlyInterest: nil,
            firstDueDate: Date(timeIntervalSince1970: 0)
        )
        #expect(schedule.count == 12)
        #expect(schedule.first?.amount == 100)
        #expect(schedule.last?.amount == 100)
    }

    @Test("Dispara erro ao receber valor inválido")
    func invalidPrincipal() {
        #expect(throws: AppError.self) {
            _ = try calculator.generateSchedule(principal: 0, installments: 1, monthlyInterest: nil, firstDueDate: .now)
        }
    }

    @Test("Normaliza valores percentuais antes da amortização")
    func normalizesPercentageInterest() throws {
        let schedule = try calculator.generateSchedule(
            principal: 1000,
            installments: 12,
            monthlyInterest: 2, // 2%
            firstDueDate: Date(timeIntervalSince1970: 0)
        )
        let firstAmount = try #require(schedule.first?.amount)
        #expect(firstAmount == Decimal(string: "94.56"))
    }
}

struct CSVExporterTests {
    @Test("Exporta CSV com dados mínimos") @MainActor
    func exportCSV() throws {
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            FixedExpense.self,
            SalarySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let debtor = Debtor(name: "Teste")
        context.insert(debtor)
        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 1)
        context.insert(agreement)
        let installment = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 1000)
        context.insert(installment)
        context.insert(FixedExpense(name: "Aluguel", amount: 200, dueDay: 5))
        try context.save()

        let exporter = CSVExporter()
        let url = try exporter.export(from: context)
        #expect(FileManager.default.fileExists(atPath: url.appendingPathComponent("devedores.csv").path))
    }
}

struct DebtorDetailViewModelTests {
    @Test("Persiste acordos normalizando juros percentuais") @MainActor
    func createsAgreementWithNormalizedInterest() throws {
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            FixedExpense.self,
            SalarySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let debtor = Debtor(name: "Ana")
        context.insert(debtor)

        let viewModel = DebtorDetailViewModel(
            debtor: debtor,
            context: context,
            calculator: FinanceCalculator(),
            notificationScheduler: nil
        )

        var draft = AgreementDraft()
        draft.title = "Teste"
        draft.principal = 1000
        draft.installmentCount = 12
        draft.startDate = Date(timeIntervalSince1970: 0)
        draft.interestRate = 2 // 2%

        viewModel.createAgreement(from: draft)
        let agreements = try context.fetch(FetchDescriptor<DebtAgreement>())
        let agreement = try #require(agreements.first)
        let storedRate = agreement.interestRateMonthly
        #expect(storedRate == Decimal(string: "0.02"), "storedRate=\(storedRate as Any)")
    }
}

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
}

struct SettingsViewModelTests {
    @Test("Atualiza salário e histórico a partir de Ajustes") @MainActor
    func updatesSalary() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let environment = AppEnvironment(configuration: configuration)
        let viewModel = SettingsViewModel(environment: environment)

        let calendar = Calendar.current
        let referenceMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()

        viewModel.load(referenceDate: referenceMonth)
        #expect(viewModel.salary == nil)

        viewModel.updateSalary(amount: 4200, month: referenceMonth, note: "Remoto")
        let currentSalary = try #require(viewModel.salary)
        #expect(currentSalary.amount == Decimal(4200))
        #expect(viewModel.salaryHistory.first?.amount == Decimal(4200))

        viewModel.updateSalary(amount: 4500, month: referenceMonth, note: nil)
        let updatedSalary = try #require(viewModel.salary)
        #expect(updatedSalary.amount == Decimal(4500))
        #expect(updatedSalary.note == nil)
        #expect(viewModel.salaryHistory.first?.amount == Decimal(4500))
    }

    @Test("Alterna alertas de vencimento sincronizando ambiente") @MainActor
    func togglesNotifications() {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let environment = AppEnvironment(featureFlags: FeatureFlags(enableNotifications: false), configuration: configuration)
        let viewModel = SettingsViewModel(environment: environment)

        #expect(!viewModel.notificationsEnabled)

        viewModel.toggleNotifications(true)

        #expect(viewModel.notificationsEnabled)
        #expect(environment.featureFlags.enableNotifications)
    }
}
