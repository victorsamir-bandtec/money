import Foundation
import Testing
import SwiftData
@testable import Money

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

        let debtor = Debtor(name: "Teste")!
        context.insert(debtor)
        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 1)!
        context.insert(agreement)
        let installment = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 1000)!
        context.insert(installment)
        context.insert(FixedExpense(name: "Aluguel", amount: 200, dueDay: 5)!)
        try context.save()

        let exporter = CSVExporter()
        let url = try exporter.export(from: context)
        #expect(FileManager.default.fileExists(atPath: url.appendingPathComponent("devedores.csv").path))
        #expect(FileManager.default.fileExists(atPath: url.appendingPathComponent("transacoes.csv").path))
    }

    @Test("Exporta todos os arquivos CSV necessários") @MainActor
    func exportsAllRequiredFiles() throws {
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

        // Criar dados completos
        let debtor = Debtor(name: "Cliente Teste")!
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 2)!
        context.insert(agreement)

        let installment1 = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 500)!
        let installment2 = Installment(agreement: agreement, number: 2, dueDate: .now, amount: 500)!
        context.insert(installment1)
        context.insert(installment2)

        let payment = Payment(installment: installment1, date: .now, amount: 500, method: .pix)!
        context.insert(payment)

        let expense = FixedExpense(name: "Aluguel", amount: 1000, dueDay: 5)!
        context.insert(expense)

        let transaction = CashTransaction(date: .now, amount: 100, type: .expense, category: "Mercado")!
        context.insert(transaction)

        try context.save()

        let exporter = CSVExporter()
        let exportURL = try exporter.export(from: context)

        // Validar que todos os arquivos foram criados
        let expectedFiles = [
            "devedores.csv",
            "acordos.csv",
            "parcelas.csv",
            "pagamentos.csv",
            "despesas.csv",
            "transacoes.csv"
        ]

        for filename in expectedFiles {
            let fileURL = exportURL.appendingPathComponent(filename)
            #expect(FileManager.default.fileExists(atPath: fileURL.path), "Arquivo \(filename) não encontrado")
        }
    }

    @Test("CSV de devedores contém cabeçalhos corretos") @MainActor
    func debtorsCSVHasCorrectHeaders() throws {
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

        let debtor = Debtor(name: "Teste", phone: "123456789", note: "Nota teste")!
        context.insert(debtor)
        try context.save()

        let exporter = CSVExporter()
        let exportURL = try exporter.export(from: context)

        let debtorsCSV = exportURL.appendingPathComponent("devedores.csv")
        let content = try String(contentsOf: debtorsCSV, encoding: .utf8)
        let lines = content.components(separatedBy: "\n")

        #expect(lines.first == "id;name;phone;note;createdAt;archived")
        #expect(lines.count >= 2) // Header + at least one data line
        #expect(lines[1].contains("Teste"))
        #expect(lines[1].contains("123456789"))
    }
}
