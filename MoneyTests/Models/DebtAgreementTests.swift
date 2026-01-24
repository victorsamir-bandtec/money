import Foundation
import Testing
import SwiftData
@testable import Money

struct DebtAgreementTests {
    @Test("Atualiza status de acordo fechado corretamente") @MainActor
    func updatesClosedStatus() throws {
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

        let agreement = DebtAgreement(debtor: debtor, principal: 900, startDate: .now, installmentCount: 3)!
        context.insert(agreement)

        let installment1 = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 300)!
        let installment2 = Installment(agreement: agreement, number: 2, dueDate: .now, amount: 300)!
        let installment3 = Installment(agreement: agreement, number: 3, dueDate: .now, amount: 300)!

        context.insert(installment1)
        context.insert(installment2)
        context.insert(installment3)

        // Inicialmente não fechado
        #expect(!agreement.closed)
        let result1 = agreement.updateClosedStatus()
        #expect(!result1) // Não modificou
        #expect(!agreement.closed)

        // Pagar apenas uma parcela
        installment1.status = .paid
        let result2 = agreement.updateClosedStatus()
        #expect(!result2) // Não modificou
        #expect(!agreement.closed)

        // Pagar duas parcelas
        installment2.status = .paid
        let result3 = agreement.updateClosedStatus()
        #expect(!result3) // Não modificou
        #expect(!agreement.closed)

        // Pagar todas as parcelas
        installment3.status = .paid
        let result4 = agreement.updateClosedStatus()
        #expect(result4) // Modificou!
        #expect(agreement.closed)

        // Chamar novamente não deve modificar
        let result5 = agreement.updateClosedStatus()
        #expect(!result5) // Não modificou
        #expect(agreement.closed)
    }

    @Test("Reabre acordo quando parcela é marcada como pendente") @MainActor
    func reopensAgreementWhenInstallmentPending() throws {
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

        let agreement = DebtAgreement(debtor: debtor, principal: 500, startDate: .now, installmentCount: 2)!
        context.insert(agreement)

        let installment1 = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 250, status: .paid)!
        let installment2 = Installment(agreement: agreement, number: 2, dueDate: .now, amount: 250, status: .paid)!

        context.insert(installment1)
        context.insert(installment2)

        // Fechar acordo
        let closed = agreement.updateClosedStatus()
        #expect(closed)
        #expect(agreement.closed)

        // Marcar parcela como pendente
        installment2.status = .pending
        let reopened = agreement.updateClosedStatus()
        #expect(reopened) // Modificou!
        #expect(!agreement.closed)
    }

    @Test("Acordo sem parcelas não fecha") @MainActor
    func agreementWithoutInstallmentsDoesNotClose() throws {
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

        // Sem parcelas
        let result = agreement.updateClosedStatus()
        #expect(!result)
        #expect(!agreement.closed)
    }

    @Test("Valida precondições de inicialização") @MainActor
    func validatesPreconditions() throws {
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

        // Principal > 0
        let validPrincipal = DebtAgreement(debtor: debtor, principal: 0.01, startDate: .now, installmentCount: 1)
        #expect(validPrincipal != nil)
        
        let invalidPrincipal = DebtAgreement(debtor: debtor, principal: 0, startDate: .now, installmentCount: 1)
        #expect(invalidPrincipal == nil)

        // InstallmentCount >= 1
        let validCount = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 1)
        #expect(validCount != nil)
        
        let invalidCount = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 0)
        #expect(invalidCount == nil)
    }

    @Test("Normaliza taxa de juros percentual") @MainActor
    func normalizesInterestRate() throws {
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

        // Taxa em formato decimal (já normalizada)
        let agreement1 = DebtAgreement(
            debtor: debtor,
            principal: 1000,
            startDate: .now,
            installmentCount: 12,
            interestRateMonthly: Decimal(string: "0.02")
        )!
        context.insert(agreement1)
        #expect(agreement1.interestRateMonthly == Decimal(string: "0.02"))

        // Taxa nil
        let agreement2 = DebtAgreement(
            debtor: debtor,
            principal: 1000,
            startDate: .now,
            installmentCount: 12,
            interestRateMonthly: nil
        )!
        context.insert(agreement2)
        #expect(agreement2.interestRateMonthly == nil)
    }

    @Test("Armazena título opcional") @MainActor
    func storesOptionalTitle() throws {
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

        // Com título
        let withTitle = DebtAgreement(
            debtor: debtor,
            title: "Empréstimo Pessoal",
            principal: 1000,
            startDate: .now,
            installmentCount: 12
        )!
        context.insert(withTitle)
        #expect(withTitle.title == "Empréstimo Pessoal")

        // Sem título
        let withoutTitle = DebtAgreement(
            debtor: debtor,
            principal: 1000,
            startDate: .now,
            installmentCount: 12
        )!
        context.insert(withoutTitle)
        #expect(withoutTitle.title == nil)
    }
}
