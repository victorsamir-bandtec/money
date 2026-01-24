import Foundation
import Testing
import SwiftData
@testable import Money

struct DebtorsListViewModelTests {
    @Test("Adiciona devedor com validação de nome") @MainActor
    func addsDebtorWithValidation() throws {
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

        let viewModel = DebtorsListViewModel(context: context)
        try viewModel.load()

        #expect(viewModel.debtors.isEmpty)

        viewModel.addDebtor(name: "João Silva", phone: "11999999999", note: "Cliente importante")
        #expect(viewModel.debtors.count == 1)
        #expect(viewModel.debtors.first?.name == "João Silva")
        #expect(viewModel.debtors.first?.phone == "11999999999")
    }

    @Test("Rejeita devedor com nome vazio") @MainActor
    func rejectsDebtorWithEmptyName() throws {
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

        let viewModel = DebtorsListViewModel(context: context)
        try viewModel.load()

        viewModel.addDebtor(name: "", phone: nil, note: nil)
        #expect(viewModel.error != nil)
        #expect(viewModel.debtors.isEmpty)

        viewModel.error = nil
        viewModel.addDebtor(name: "   ", phone: nil, note: nil)
        #expect(viewModel.error != nil)
        #expect(viewModel.debtors.isEmpty)
    }

    @Test("Aplica trimming ao nome do devedor") @MainActor
    func trimsDebtorName() throws {
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

        let viewModel = DebtorsListViewModel(context: context)
        try viewModel.load()

        viewModel.addDebtor(name: "  Maria Santos  ", phone: nil, note: nil)
        #expect(viewModel.debtors.count == 1)
        #expect(viewModel.debtors.first?.name == "Maria Santos")
    }

    @Test("Arquiva e desarquiva devedor") @MainActor
    func archivesAndUnarchivesDebtor() throws {
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

        let debtor = Debtor(name: "Teste Arquivar")!
        context.insert(debtor)
        try context.save()

        let viewModel = DebtorsListViewModel(context: context)
        try viewModel.load()

        #expect(viewModel.debtors.count == 1)
        #expect(!debtor.archived)

        viewModel.toggleArchive(debtor)
        #expect(debtor.archived)
        #expect(viewModel.debtors.isEmpty) // Não mostra arquivados por padrão

        viewModel.showArchived = true
        try viewModel.load()
        #expect(viewModel.debtors.count == 1)

        viewModel.toggleArchive(debtor)
        #expect(!debtor.archived)
    }

    @Test("Deleta devedor e acordos relacionados") @MainActor
    func deletesDebtorWithCascade() throws {
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

        let debtor = Debtor(name: "Deletar")!
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 1)!
        context.insert(agreement)

        let installment = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 1000)!
        context.insert(installment)
        try context.save()

        let viewModel = DebtorsListViewModel(context: context)
        try viewModel.load()

        #expect(viewModel.debtors.count == 1)

        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(forName: .debtorDataDidChange, object: nil, queue: nil) { _ in
            notificationReceived = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        viewModel.deleteDebtor(debtor)
        #expect(viewModel.debtors.isEmpty)
        #expect(notificationReceived)

        let remainingDebtors = try context.fetch(FetchDescriptor<Debtor>())
        let remainingAgreements = try context.fetch(FetchDescriptor<DebtAgreement>())
        let remainingInstallments = try context.fetch(FetchDescriptor<Installment>())

        #expect(remainingDebtors.isEmpty)
        #expect(remainingAgreements.isEmpty)
        #expect(remainingInstallments.isEmpty)
    }

    @Test("Filtra devedores por texto de busca") @MainActor
    func filtersDebtorsBySearchText() throws {
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

        context.insert(Debtor(name: "João Silva")!)
        context.insert(Debtor(name: "Maria Santos")!)
        context.insert(Debtor(name: "Pedro Oliveira")!)
        try context.save()

        let viewModel = DebtorsListViewModel(context: context)
        try viewModel.load()

        #expect(viewModel.debtors.count == 3)

        viewModel.searchText = "Maria"
        try viewModel.load()
        #expect(viewModel.debtors.count == 1)
        #expect(viewModel.debtors.first?.name == "Maria Santos")

        viewModel.searchText = "silva"
        try viewModel.load()
        #expect(viewModel.debtors.count == 1)
        #expect(viewModel.debtors.first?.name == "João Silva")

        viewModel.searchText = "  "
        try viewModel.load()
        #expect(viewModel.debtors.count == 3)
    }

    @Test("Calcula resumo de devedor corretamente") @MainActor
    func calculatesDebtorSummaryCorrectly() throws {
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

        let debtor = Debtor(name: "Teste Resumo")!
        context.insert(debtor)

        let agreement1 = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 2)!
        context.insert(agreement1)

        let installment1 = Installment(agreement: agreement1, number: 1, dueDate: .now, amount: 500, paidAmount: 500, status: .paid)!
        let installment2 = Installment(agreement: agreement1, number: 2, dueDate: .now, amount: 500, paidAmount: 200, status: .partial)!
        context.insert(installment1)
        context.insert(installment2)

        let agreement2 = DebtAgreement(debtor: debtor, principal: 600, startDate: .now, installmentCount: 1, closed: true)!
        context.insert(agreement2)

        let installment3 = Installment(agreement: agreement2, number: 1, dueDate: .now, amount: 600, paidAmount: 600, status: .paid)!
        context.insert(installment3)

        try context.save()

        let viewModel = DebtorsListViewModel(context: context)
        try viewModel.load()

        let summary = viewModel.summary(for: debtor)

        #expect(summary.totalAgreements == 2)
        #expect(summary.activeAgreements == 1)
        #expect(summary.totalInstallments == 2) // Apenas do acordo ativo
        #expect(summary.paidInstallments == 1)
        #expect(summary.openInstallments == 1)
        #expect(summary.totalAmount == Decimal(1000))
        #expect(summary.paidAmount == Decimal(700))
        #expect(summary.remainingAmount == Decimal(300))
    }

    @Test("Conta devedores ativos e arquivados") @MainActor
    func countsActiveAndArchivedDebtors() throws {
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

        context.insert(Debtor(name: "Ativo 1", archived: false)!)
        context.insert(Debtor(name: "Ativo 2", archived: false)!)
        context.insert(Debtor(name: "Arquivado 1", archived: true)!)
        context.insert(Debtor(name: "Arquivado 2", archived: true)!)
        context.insert(Debtor(name: "Arquivado 3", archived: true)!)
        try context.save()

        let viewModel = DebtorsListViewModel(context: context)
        try viewModel.load()

        #expect(viewModel.totalCount == 5)
        #expect(viewModel.archivedCount == 3)
        #expect(viewModel.activeCount == 2)
    }

    @Test("Atualiza status de acordo fechado ao calcular resumo") @MainActor
    func updatesClosedStatusWhenComputingSummary() throws {
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

        let debtor = Debtor(name: "Teste Auto-Close")!
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 500, startDate: .now, installmentCount: 1, closed: false)!
        context.insert(agreement)

        let installment = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 500, paidAmount: 500, status: .paid)!
        context.insert(installment)
        try context.save()

        #expect(!agreement.closed)

        let viewModel = DebtorsListViewModel(context: context)
        try viewModel.load()

        // Após calcular o resumo, o acordo deve estar fechado
        #expect(agreement.closed)

        let summary = viewModel.summary(for: debtor)
        #expect(summary.activeAgreements == 0)
    }
}
