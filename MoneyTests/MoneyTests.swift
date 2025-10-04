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
