import Foundation
import Testing
import SwiftData
@testable import Money

struct FinancialReadModelServiceTests {
    @Test("Lê resumo financeiro do snapshot materializado") @MainActor
    func readsSummaryFromSnapshot() throws {
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            CashTransaction.self,
            FixedExpense.self,
            SalarySnapshot.self,
            MonthlySnapshot.self,
            DebtorCreditProfile.self,
            CashFlowProjection.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let monthStart = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
        let snapshot = MonthlySnapshot(
            referenceMonth: monthStart,
            salary: 4000,
            paymentsReceived: 500,
            variableIncome: 100,
            fixedExpenses: 1600,
            variableExpenses: 300,
            overdueAmount: 200,
            plannedReceivables: 450,
            activeDebtors: 2,
            activeAgreements: 3
        )
        context.insert(snapshot)
        try context.save()

        let service = FinancialReadModelService(context: context)
        let summary = try service.summary(for: .now)

        #expect(summary.salary == Decimal(4000))
        #expect(summary.received == Decimal(500))
        #expect(summary.planned == Decimal(450))
        #expect(summary.availableToSpend == Decimal(2700))
    }

    @Test("Busca próximas parcelas sem incluir quitadas") @MainActor
    func readsUpcomingInstallments() throws {
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            CashTransaction.self,
            FixedExpense.self,
            SalarySnapshot.self,
            MonthlySnapshot.self,
            DebtorCreditProfile.self,
            CashFlowProjection.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let debtor = Debtor(name: "Teste")!
        context.insert(debtor)
        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 2)!
        context.insert(agreement)

        let inWindow = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        let paidDate = Calendar.current.date(byAdding: .day, value: 5, to: .now) ?? .now

        let upcoming = Installment(agreement: agreement, number: 1, dueDate: inWindow, amount: 500, status: .pending)!
        let paid = Installment(agreement: agreement, number: 2, dueDate: paidDate, amount: 500, paidAmount: 500, status: .paid)!
        context.insert(upcoming)
        context.insert(paid)
        try context.save()

        let service = FinancialReadModelService(context: context)
        let installments = try service.upcomingInstallments(for: .now, windowDays: 14)

        #expect(installments.count == 1)
        #expect(installments.first?.id == upcoming.id)
    }
}
