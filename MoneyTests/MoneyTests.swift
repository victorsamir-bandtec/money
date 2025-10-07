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
            CashTransaction.self,
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
        #expect(FileManager.default.fileExists(atPath: url.appendingPathComponent("transacoes.csv").path))
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
            CashTransaction.self,
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

    @Test("Emite notificações ao criar acordo") @MainActor
    func postsNotificationsAfterCreatingAgreement() throws {
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

        var recorded: [Notification.Name: Int] = [:]
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .agreementDataDidChange,
            .paymentDataDidChange,
            .financialDataDidChange
        ]
        let tokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: nil) { _ in
                recorded[name, default: 0] += 1
            }
        }
        defer { tokens.forEach(center.removeObserver) }

        viewModel.createAgreement(from: draft)

        #expect(recorded[.agreementDataDidChange] == 1)
        #expect(recorded[.paymentDataDidChange] == 1)
        #expect(recorded[.financialDataDidChange] == 1)
    }
}

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
            SalarySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let debtor = Debtor(name: "Cliente Teste")
        context.insert(debtor)

        let now = Date(timeIntervalSince1970: 1_700_000_000) // referência fixa para estabilidade dos testes
        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: now, installmentCount: 3)
        context.insert(agreement)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let overdueDate = calendar.date(byAdding: .day, value: -10, to: now)!
        let upcomingDate = calendar.date(byAdding: .day, value: 5, to: now)!
        let futurePaidDate = calendar.date(byAdding: .day, value: 25, to: now)!

        let overdueInstallment = Installment(agreement: agreement, number: 1, dueDate: overdueDate, amount: 100)
        overdueInstallment.paidAmount = 20
        overdueInstallment.status = .partial
        context.insert(overdueInstallment)

        let upcomingInstallment = Installment(agreement: agreement, number: 2, dueDate: upcomingDate, amount: 150)
        context.insert(upcomingInstallment)

        let paidInstallment = Installment(agreement: agreement, number: 3, dueDate: futurePaidDate, amount: 200, status: .paid)
        paidInstallment.paidAmount = 200
        context.insert(paidInstallment)

        try context.save()

        let viewModel = DashboardViewModel(context: context, currencyFormatter: CurrencyFormatter())
        try viewModel.load(currentDate: now)

        #expect(viewModel.summary.planned == Decimal(150))
        #expect(viewModel.summary.overdue == Decimal(80))
        #expect(viewModel.summary.remainingToReceive == Decimal(230))
        #expect(viewModel.summary.availableToSpend == Decimal(70))
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
            SalarySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceDate = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15, hour: 12))!

        context.insert(CashTransaction(date: referenceDate, amount: 120, type: .expense, category: "Mercado"))
        context.insert(CashTransaction(date: referenceDate, amount: 60, type: .income, category: "Freelancer"))
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: referenceDate)!
        context.insert(CashTransaction(date: previousMonth, amount: 50, type: .expense, category: "Viagem"))
        try context.save()

        let viewModel = DashboardViewModel(context: context, currencyFormatter: CurrencyFormatter())
        try viewModel.load(currentDate: referenceDate)

        #expect(viewModel.summary.variableExpenses == Decimal(120))
        #expect(viewModel.summary.variableIncome == Decimal(60))
        #expect(viewModel.summary.availableToSpend == Decimal(-60))
        #expect(viewModel.summary.totalExpenses == Decimal(120))
        #expect(viewModel.summary.variableBalance == Decimal(-60))
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
            variableExpenses: 150
        )

        #expect(summary.remainingToReceive == Decimal(1000))
        #expect(summary.availableToSpend == summary.salary + summary.received + summary.planned + summary.variableIncome - (summary.fixedExpenses + summary.overdue + summary.variableExpenses))
        #expect(summary.totalExpenses == Decimal(1350))
        #expect(summary.variableBalance == Decimal(-150))
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
}

@MainActor
final class FeatureFlagsStoreSpy: FeatureFlagsStoring {
    private(set) var savedFlags: [FeatureFlags] = []
    var storedFlags: FeatureFlags

    init(initialFlags: FeatureFlags) {
        self.storedFlags = initialFlags
    }

    func load() -> FeatureFlags {
        storedFlags
    }

    func save(_ featureFlags: FeatureFlags) {
        savedFlags.append(featureFlags)
        storedFlags = featureFlags
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
    func togglesNotifications() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let store = FeatureFlagsStoreSpy(initialFlags: FeatureFlags(enableNotifications: false))
        let environment = AppEnvironment(featureFlagsStore: store, configuration: configuration)
        let viewModel = SettingsViewModel(environment: environment)

        #expect(!viewModel.notificationsEnabled)

        viewModel.toggleNotifications(true)

        #expect(viewModel.notificationsEnabled)
        #expect(environment.featureFlags.enableNotifications)
        let persistedFlags = try #require(store.savedFlags.last)
        #expect(persistedFlags.enableNotifications)
        #expect(store.savedFlags.count == 1)
    }
}
