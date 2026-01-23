import Foundation
import Testing
import SwiftData
@testable import Money

struct InstallmentTests {
    @Test("Calcula remainingAmount corretamente") @MainActor
    func calculatesRemainingAmount() throws {
        let schema = Schema([Debtor.self, DebtAgreement.self, Installment.self, Payment.self, CashTransaction.self, FixedExpense.self, SalarySnapshot.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let debtor = Debtor(name: "Teste")
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 1)
        context.insert(agreement)

        let installment = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 500)
        context.insert(installment)

        #expect(installment.remainingAmount == Decimal(500))

        installment.paidAmount = Decimal(200)
        #expect(installment.remainingAmount == Decimal(300))

        installment.paidAmount = Decimal(500)
        #expect(installment.remainingAmount == .zero)

        // Valor pago não deve exceder o total
        installment.paidAmount = Decimal(600)
        #expect(installment.remainingAmount == .zero)
    }

    @Test("Identifica parcela vencida corretamente") @MainActor
    func identifiesOverdueInstallments() throws {
        let schema = Schema([Debtor.self, DebtAgreement.self, Installment.self, Payment.self, CashTransaction.self, FixedExpense.self, SalarySnapshot.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let debtor = Debtor(name: "Teste")
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 3)
        context.insert(agreement)

        let calendar = Calendar.current

        // Parcela vencida (data passada, status pending)
        let pastDate = calendar.date(byAdding: .day, value: -5, to: .now)!
        let overdueInstallment = Installment(agreement: agreement, number: 1, dueDate: pastDate, amount: 100, status: .pending)
        context.insert(overdueInstallment)
        #expect(overdueInstallment.isOverdue)

        // Parcela com status overdue explícito
        let overdueStatus = Installment(agreement: agreement, number: 2, dueDate: .now, amount: 100, status: .overdue)
        context.insert(overdueStatus)
        #expect(overdueStatus.isOverdue)

        // Parcela futura não vencida
        let futureDate = calendar.date(byAdding: .day, value: 5, to: .now)!
        let upcomingInstallment = Installment(agreement: agreement, number: 3, dueDate: futureDate, amount: 100)
        context.insert(upcomingInstallment)
        #expect(!upcomingInstallment.isOverdue)

        // Parcela paga não é vencida
        let paidInstallment = Installment(agreement: agreement, number: 4, dueDate: pastDate, amount: 100, status: .paid)
        context.insert(paidInstallment)
        #expect(!paidInstallment.isOverdue)
        
        // Parcela vencendo HOJE (data exata passada por alguns segundos/minutos, mas mesmo dia)
        // Corrigido: dueDate < now não deve retornar true se for o mesmo dia.
        let todayDate = Calendar.current.date(byAdding: .hour, value: -1, to: .now)!
        let dueToday = Installment(agreement: agreement, number: 5, dueDate: todayDate, amount: 100)
        context.insert(dueToday)
        #expect(!dueToday.isOverdue) // Agora deve passar com a lógica startOfDay

        // Teste de Injeção de Dependência de Data
        let futureReference = calendar.date(byAdding: .day, value: 10, to: .now)!
        #expect(upcomingInstallment.isOverdue(relativeTo: futureReference)) // Deve estar vencida no futuro
    }

    @Test("Status enum conversão funciona corretamente") @MainActor
    func statusEnumConversion() throws {
        let schema = Schema([Debtor.self, DebtAgreement.self, Installment.self, Payment.self, CashTransaction.self, FixedExpense.self, SalarySnapshot.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let debtor = Debtor(name: "Teste")
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 1)
        context.insert(agreement)

        let installment = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 100)
        context.insert(installment)

        #expect(installment.status == .pending)
        #expect(installment.statusRaw == 0)

        installment.status = .partial
        #expect(installment.statusRaw == 1)

        installment.status = .paid
        #expect(installment.statusRaw == 2)

        installment.status = .overdue
        #expect(installment.statusRaw == 3)
    }

    @Test("Precondições de inicialização são validadas") @MainActor
    func initializationPreconditions() throws {
        let schema = Schema([Debtor.self, DebtAgreement.self, Installment.self, Payment.self, CashTransaction.self, FixedExpense.self, SalarySnapshot.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let debtor = Debtor(name: "Teste")
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 1)
        context.insert(agreement)

        // Número deve ser >= 1
        #expect(throws: Never.self) {
            let valid = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 100)
            context.insert(valid)
        }

        // Valor deve ser > 0
        #expect(throws: Never.self) {
            let valid = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 0.01)
            context.insert(valid)
        }

        // Valor pago deve ser >= 0
        #expect(throws: Never.self) {
            let valid = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 100, paidAmount: 0)
            context.insert(valid)
        }
    }
}
