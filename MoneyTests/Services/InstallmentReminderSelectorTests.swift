import Foundation
import SwiftData
import Testing
@testable import Money

struct InstallmentReminderSelectorTests {
    @Test("Seleciona a parcela vencida mais antiga") @MainActor
    func selectsOldestOverdueInstallment() throws {
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            CashTransaction.self,
            FixedExpense.self,
            SalarySnapshot.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let debtor = Debtor(name: "Teste")!
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 3)!
        context.insert(agreement)

        let calendar = Calendar.current
        let overdueOld = Installment(
            agreement: agreement,
            number: 1,
            dueDate: try #require(calendar.date(byAdding: .day, value: -10, to: .now)),
            amount: 100
        )!
        context.insert(overdueOld)

        let overdueNew = Installment(
            agreement: agreement,
            number: 2,
            dueDate: try #require(calendar.date(byAdding: .day, value: -2, to: .now)),
            amount: 100
        )!
        context.insert(overdueNew)

        let upcoming = Installment(
            agreement: agreement,
            number: 3,
            dueDate: try #require(calendar.date(byAdding: .day, value: 5, to: .now)),
            amount: 100
        )!
        context.insert(upcoming)

        let selected = InstallmentReminderSelector.selectTarget(from: [overdueOld, overdueNew, upcoming])
        #expect(selected?.id == overdueOld.id)
    }

    @Test("Seleciona a parcela futura mais proxima quando nao ha vencidas") @MainActor
    func selectsNearestUpcomingWhenNoOverdue() throws {
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            CashTransaction.self,
            FixedExpense.self,
            SalarySnapshot.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let debtor = Debtor(name: "Teste")!
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 2)!
        context.insert(agreement)

        let calendar = Calendar.current
        let later = Installment(
            agreement: agreement,
            number: 2,
            dueDate: try #require(calendar.date(byAdding: .day, value: 10, to: .now)),
            amount: 100
        )!
        context.insert(later)

        let sooner = Installment(
            agreement: agreement,
            number: 1,
            dueDate: try #require(calendar.date(byAdding: .day, value: 3, to: .now)),
            amount: 100
        )!
        context.insert(sooner)

        let selected = InstallmentReminderSelector.selectTarget(from: [later, sooner])
        #expect(selected?.id == sooner.id)
    }

    @Test("Ignora parcelas quitadas ao selecionar alvo") @MainActor
    func ignoresPaidInstallments() throws {
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            CashTransaction.self,
            FixedExpense.self,
            SalarySnapshot.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let debtor = Debtor(name: "Teste")!
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 2)!
        context.insert(agreement)

        let calendar = Calendar.current
        let overduePaid = Installment(
            agreement: agreement,
            number: 1,
            dueDate: try #require(calendar.date(byAdding: .day, value: -10, to: .now)),
            amount: 100,
            paidAmount: 100,
            status: .paid
        )!
        context.insert(overduePaid)

        let upcomingOpen = Installment(
            agreement: agreement,
            number: 2,
            dueDate: try #require(calendar.date(byAdding: .day, value: 5, to: .now)),
            amount: 100
        )!
        context.insert(upcomingOpen)

        let selected = InstallmentReminderSelector.selectTarget(from: [overduePaid, upcomingOpen])
        #expect(selected?.id == upcomingOpen.id)
    }
}
