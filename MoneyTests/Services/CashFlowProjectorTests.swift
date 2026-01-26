import Testing
import Foundation
import SwiftData
@testable import Money

@MainActor
struct CashFlowProjectorTests {
    
    @Test("Calculates average ignoring current month")
    func calculatesAverageIgnoringCurrentMonth() async throws {
        let schema = Schema([
            CashTransaction.self,
            SalarySnapshot.self,
            FixedExpense.self,
            Installment.self,
            DebtAgreement.self,
            Debtor.self,
            MonthlySnapshot.self,
            CashFlowProjection.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext
        
        let fixture = HistoricalAnalysisFixture(context: context)
        let today = Date()
        let calendar = Calendar.current
        
        // Setup:
        // 6 months of history (t-6 to t-1)
        // Variable Expense: 300 per month
        // Variable Income: 500 per month
        // Salary: 5000 per month
        try fixture.generateSixMonthsHistory(
            baseDate: today,
            salary: 5000,
            fixedExpenses: 1000,
            variableIncome: 500,
            variableExpense: 300
        )
        
        // Add data for CURRENT MONTH (t-0) - Should be IGNORED
        try fixture.generateCurrentMonthData(baseDate: today, variableExpense: 10000)
        
        // Execute
        let projector = CashFlowProjector()
        // Project for 1 month
        let projections = try projector.projectCashFlow(months: 1, scenario: .realistic, context: context)
        
        guard let projection = projections.first else {
            Issue.record("Should return a projection")
            return
        }
        
        // Verification (Realistic Scenario = Average)
        // Expected Average Variable Expense: 300
        // (Current month 10000 should be ignored)
        // (Fixed Expenses are projected separately, usually summed from active. Fixture adds 1 active fixed expense of 1000)
        
        // Projected Variable Expenses should be 300 (average of 300 * 6 / 6)
        #expect(projection.projectedVariableExpenses == 300, "Should match 6-month average of 300")
        
        // Projected Fixed Expenses should be 1000 (active fixed expense)
        #expect(projection.projectedFixedExpenses == 1000)
        
        // Total Expenses
        #expect(projection.totalProjectedExpenses == 1300)
    }
    
    @Test("Optimistic Scenario applies correct multipliers (+10% Income, -10% Expense)")
    func optimisticScenarioMultipliers() async throws {
        let schema = Schema([
            CashTransaction.self,
            SalarySnapshot.self,
            FixedExpense.self,
            Installment.self,
            DebtAgreement.self,
            Debtor.self,
            MonthlySnapshot.self,
            CashFlowProjection.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext
        
        let fixture = HistoricalAnalysisFixture(context: context)
        let today = Date()
        
        // Setup: Base Average Income 500, Expense 300
        try fixture.generateSixMonthsHistory(
            baseDate: today,
            salary: 0,
            fixedExpenses: 0,
            variableIncome: 500,
            variableExpense: 300
        )
        
        let projector = CashFlowProjector()
        let projections = try projector.projectCashFlow(months: 1, scenario: .optimistic, context: context)
        let projection = projections[0]
        
        // Optimistic:
        // Income: +10% of 500 = 550
        // Expense: -10% of 300 = 270
        
        #expect(projection.projectedVariableIncome == 550, "Optimistic Income should be +10%")
        #expect(projection.projectedVariableExpenses == 270, "Optimistic Expense should be -10%")
    }
    
    @Test("Pessimistic Scenario applies correct multipliers (-10% Income, +10% Expense)")
    func pessimisticScenarioMultipliers() async throws {
        let schema = Schema([
            CashTransaction.self,
            SalarySnapshot.self,
            FixedExpense.self,
            Installment.self,
            DebtAgreement.self,
            Debtor.self,
            MonthlySnapshot.self,
            CashFlowProjection.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext
        
        let fixture = HistoricalAnalysisFixture(context: context)
        let today = Date()
        
        // Setup: Base Average Income 500, Expense 300
        try fixture.generateSixMonthsHistory(
            baseDate: today,
            salary: 0,
            fixedExpenses: 0,
            variableIncome: 500,
            variableExpense: 300
        )
        
        let projector = CashFlowProjector()
        let projections = try projector.projectCashFlow(months: 1, scenario: .pessimistic, context: context)
        let projection = projections[0]
        
        // Pessimistic:
        // Income: -10% of 500 = 450
        // Expense: +10% of 300 = 330
        
        #expect(projection.projectedVariableIncome == 450, "Pessimistic Income should be -10%")
        #expect(projection.projectedVariableExpenses == 330, "Pessimistic Expense should be +10%")
    }
}
