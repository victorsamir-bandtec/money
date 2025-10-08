import Foundation
import Testing
import SwiftData
@testable import Money

struct SampleDataServiceTests {
    @Test("Popula dados de exemplo quando banco está vazio") @MainActor
    func populatesSampleDataWhenDatabaseIsEmpty() throws {
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

        let service = SampleDataService(context: context, financeCalculator: FinanceCalculator())

        // Verificar que está vazio
        let initialDebtors = try context.fetch(FetchDescriptor<Debtor>())
        #expect(initialDebtors.isEmpty)

        // Popular
        try service.populateIfNeeded()

        // Verificar que foi populado
        let debtors = try context.fetch(FetchDescriptor<Debtor>())
        #expect(!debtors.isEmpty)
        #expect(debtors.count == 1)
        #expect(debtors.first?.name == "Marlon")
    }

    @Test("Não popula se já existem devedores") @MainActor
    func doesNotPopulateIfDebtorsExist() throws {
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

        // Criar um devedor manualmente
        let existingDebtor = Debtor(name: "Existente")
        context.insert(existingDebtor)
        try context.save()

        let service = SampleDataService(context: context, financeCalculator: FinanceCalculator())

        // Tentar popular
        try service.populateIfNeeded()

        // Verificar que não adicionou Marlon
        let debtors = try context.fetch(FetchDescriptor<Debtor>())
        #expect(debtors.count == 1)
        #expect(debtors.first?.name == "Existente")
    }

    @Test("Cria cenário Marlon completo") @MainActor
    func createsCompleteScenarioMarlon() throws {
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

        let service = SampleDataService(context: context, financeCalculator: FinanceCalculator())

        try service.createScenarioMarlon()
        try context.save()

        // Verificar devedor
        let debtors = try context.fetch(FetchDescriptor<Debtor>())
        #expect(debtors.count == 1)
        let marlon = try #require(debtors.first)
        #expect(marlon.name == "Marlon")

        // Verificar acordo
        let agreements = try context.fetch(FetchDescriptor<DebtAgreement>())
        #expect(agreements.count == 1)
        let agreement = try #require(agreements.first)
        #expect(agreement.principal == Decimal(1500))
        #expect(agreement.installmentCount == 12)
        #expect(agreement.debtor.id == marlon.id)

        // Verificar parcelas
        let installments = try context.fetch(FetchDescriptor<Installment>())
        #expect(installments.count == 12)

        // Verificar que 3 primeiras parcelas estão pagas
        let paidInstallments = installments.filter { $0.status == .paid }
        #expect(paidInstallments.count == 3)
        #expect(paidInstallments.allSatisfy { $0.paidAmount == $0.amount })

        // Verificar despesa fixa
        let expenses = try context.fetch(FetchDescriptor<FixedExpense>())
        #expect(expenses.count == 1)
        let expense = try #require(expenses.first)
        #expect(expense.name == "Aluguel escritório")
        #expect(expense.amount == Decimal(800))
        #expect(expense.category == "Infra")

        // Verificar salário
        let salaries = try context.fetch(FetchDescriptor<SalarySnapshot>())
        #expect(salaries.count == 1)
        let salary = try #require(salaries.first)
        #expect(salary.amount == Decimal(4200))

        // Verificar transações
        let transactions = try context.fetch(FetchDescriptor<CashTransaction>())
        #expect(transactions.count == 3)

        let expenses_tx = transactions.filter { $0.type == .expense }
        #expect(expenses_tx.count == 2)

        let income_tx = transactions.filter { $0.type == .income }
        #expect(income_tx.count == 1)
    }

    @Test("Parcelas criadas têm valores corretos") @MainActor
    func installmentsHaveCorrectValues() throws {
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

        let service = SampleDataService(context: context, financeCalculator: FinanceCalculator())

        try service.createScenarioMarlon()
        try context.save()

        let installments = try context.fetch(FetchDescriptor<Installment>())
        let sortedInstallments = installments.sorted { $0.number < $1.number }

        // 1500 / 12 = 125 por parcela
        #expect(sortedInstallments.first?.amount == Decimal(125))

        // Primeira parcela está paga
        #expect(sortedInstallments[0].status == .paid)
        #expect(sortedInstallments[1].status == .paid)
        #expect(sortedInstallments[2].status == .paid)

        // Demais pendentes
        for i in 3..<sortedInstallments.count {
            #expect(sortedInstallments[i].status == .pending)
            #expect(sortedInstallments[i].paidAmount == .zero)
        }
    }

    @Test("Transações têm categorias corretas") @MainActor
    func transactionsHaveCorrectCategories() throws {
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

        let service = SampleDataService(context: context, financeCalculator: FinanceCalculator())

        try service.createScenarioMarlon()
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<CashTransaction>())

        let groceries = transactions.first { $0.category == "Mercado" }
        #expect(groceries != nil)
        #expect(groceries?.type == .expense)

        let transport = transactions.first { $0.category == "Transporte" }
        #expect(transport != nil)
        #expect(transport?.type == .expense)

        let freelance = transactions.first { $0.category == "Freelancer" }
        #expect(freelance != nil)
        #expect(freelance?.type == .income)
    }

    @Test("Acordo tem data de início retroativa") @MainActor
    func agreementHasRetrospectiveStartDate() throws {
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

        let service = SampleDataService(context: context, financeCalculator: FinanceCalculator())

        try service.createScenarioMarlon()
        try context.save()

        let agreements = try context.fetch(FetchDescriptor<DebtAgreement>())
        let agreement = try #require(agreements.first)

        let now = Date()
        let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: now)!

        // Verificar que a data de início é aproximadamente 2 meses atrás
        #expect(agreement.startDate < now)
        #expect(abs(agreement.startDate.timeIntervalSince(twoMonthsAgo)) < 86400) // Menos de 1 dia de diferença
    }

    @Test("Limpar dados remove todas as entidades persistidas") @MainActor
    func clearAllDataRemovesPersistedEntities() throws {
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

        let service = SampleDataService(context: context, financeCalculator: FinanceCalculator())

        try service.createScenarioMarlon()
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Debtor>()).isEmpty == false)
        #expect(try context.fetch(FetchDescriptor<CashTransaction>()).isEmpty == false)

        try service.clearAllData()

        #expect(try context.fetch(FetchDescriptor<Debtor>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DebtAgreement>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Installment>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Payment>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CashTransaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FixedExpense>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SalarySnapshot>()).isEmpty)
    }
}
