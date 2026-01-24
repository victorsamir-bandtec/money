import Foundation
import Testing
import SwiftData
@testable import Money

struct DebtorTests {
    @Test("Inicializa devedor com valores padrão") @MainActor
    func initializesWithDefaults() throws {
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

        let debtor = Debtor(name: "João Silva")!
        context.insert(debtor)

        #expect(debtor.name == "João Silva")
        #expect(debtor.phone == nil)
        #expect(debtor.note == nil)
        #expect(!debtor.archived)
        #expect(debtor.agreements.isEmpty)
        #expect(debtor.createdAt <= Date())
    }

    @Test("Armazena dados opcionais corretamente") @MainActor
    func storesOptionalDataCorrectly() throws {
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

        let debtor = Debtor(
            name: "Maria Santos",
            phone: "11999999999",
            note: "Cliente VIP",
            archived: true
        )!
        context.insert(debtor)

        #expect(debtor.name == "Maria Santos")
        #expect(debtor.phone == "11999999999")
        #expect(debtor.note == "Cliente VIP")
        #expect(debtor.archived)
    }

    @Test("Mantém relacionamento com acordos") @MainActor
    func maintainsAgreementRelationship() throws {
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

        let debtor = Debtor(name: "Pedro Oliveira")!
        context.insert(debtor)

        let agreement1 = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 12)!
        let agreement2 = DebtAgreement(debtor: debtor, principal: 500, startDate: .now, installmentCount: 6)!

        context.insert(agreement1)
        context.insert(agreement2)

        #expect(debtor.agreements.count == 2)
        #expect(debtor.agreements.contains(where: { $0.id == agreement1.id }))
        #expect(debtor.agreements.contains(where: { $0.id == agreement2.id }))
    }

    @Test("Cascade delete remove acordos relacionados") @MainActor
    func cascadeDeleteRemovesRelatedAgreements() throws {
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

        let debtor = Debtor(name: "Ana Costa")!
        context.insert(debtor)

        let agreement1 = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 12)!
        let agreement2 = DebtAgreement(debtor: debtor, principal: 500, startDate: .now, installmentCount: 6)!

        context.insert(agreement1)
        context.insert(agreement2)

        let installment1 = Installment(agreement: agreement1, number: 1, dueDate: .now, amount: 100)!
        let installment2 = Installment(agreement: agreement2, number: 1, dueDate: .now, amount: 100)!

        context.insert(installment1)
        context.insert(installment2)

        try context.save()

        // Verificar que tudo foi criado
        let allAgreements = try context.fetch(FetchDescriptor<DebtAgreement>())
        let allInstallments = try context.fetch(FetchDescriptor<Installment>())
        #expect(allAgreements.count == 2)
        #expect(allInstallments.count == 2)

        // Deletar devedor
        context.delete(debtor)
        try context.save()

        // Verificar cascade
        let remainingAgreements = try context.fetch(FetchDescriptor<DebtAgreement>())
        let remainingInstallments = try context.fetch(FetchDescriptor<Installment>())
        #expect(remainingAgreements.isEmpty)
        #expect(remainingInstallments.isEmpty)
    }

    @Test("ID é único para cada devedor") @MainActor
    func idIsUniqueForEachDebtor() throws {
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

        let debtor1 = Debtor(name: "Devedor 1")!
        let debtor2 = Debtor(name: "Devedor 2")!

        context.insert(debtor1)
        context.insert(debtor2)

        #expect(debtor1.id != debtor2.id)
    }

    @Test("CreatedAt é armazenado corretamente") @MainActor
    func createdAtIsStoredCorrectly() throws {
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

        let beforeCreation = Date()
        let debtor = Debtor(name: "Teste Data")!
        let afterCreation = Date()

        context.insert(debtor)

        #expect(debtor.createdAt >= beforeCreation)
        #expect(debtor.createdAt <= afterCreation)

        // Com createdAt customizado
        let customDate = Date(timeIntervalSince1970: 1000000)
        let customDebtor = Debtor(name: "Teste Custom", createdAt: customDate)!
        context.insert(customDebtor)
        #expect(customDebtor.createdAt == customDate)
    }

    @Test("Status de arquivado pode ser alterado") @MainActor
    func archivedStatusCanBeChanged() throws {
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

        let debtor = Debtor(name: "Teste Arquivar", archived: false)!
        context.insert(debtor)

        #expect(!debtor.archived)

        debtor.archived = true
        #expect(debtor.archived)

        debtor.archived = false
        #expect(!debtor.archived)
    }
}
