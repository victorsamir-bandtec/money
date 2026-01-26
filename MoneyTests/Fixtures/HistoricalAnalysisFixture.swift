import Foundation
import SwiftData
@testable import Money

@MainActor
struct HistoricalAnalysisFixture {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Gera 6 meses de dados históricos (t-6 até t-1)
    func generateSixMonthsHistory(
        baseDate: Date = Date(),
        salary: Decimal = 5000,
        fixedExpenses: Decimal = 1000,
        variableIncome: Decimal = 500,
        variableExpense: Decimal = 300
    ) throws {
        let calendar = Calendar.current
        
        // 1. Fixed Expense (Active) - Inserido uma vez pois o Aggregator usa o estado atual
        if fixedExpenses > 0 {
            let expense = FixedExpense(name: "Test Fixed", amount: fixedExpenses, dueDay: 1)!
            context.insert(expense)
        }

        // Loop para os últimos 6 meses (excluindo o atual)
        for i in 1...6 {
            guard let date = calendar.date(byAdding: .month, value: -i, to: baseDate) else { continue }
            
            // 2. Salary
            if salary > 0 {
                let s = SalarySnapshot(referenceMonth: date, amount: salary)
                context.insert(s!)
            }
            
            // 3. Variable Income
            if variableIncome > 0 {
                let income = CashTransaction(
                    date: date,
                    amount: variableIncome,
                    type: .income,
                    category: "Variable",
                    note: "Variable Income Month \(i)"
                )
                context.insert(income!)
            }
            
            // 4. Variable Expense
            if variableExpense > 0 {
                 let expense = CashTransaction(
                    date: date,
                    amount: variableExpense,
                    type: .expense,
                    category: "Variable",
                    note: "Variable Expense Month \(i)"
                )
                context.insert(expense!)
            }
        }
        
        try context.save()
    }
    
    /// Gera dados para o mês atual (t-0) para testar exclusão
    func generateCurrentMonthData(
        baseDate: Date = Date(),
        variableExpense: Decimal = 999
    ) throws {
        let expense = CashTransaction(
            date: baseDate,
            amount: variableExpense,
            type: .expense,
            category: "Current Month",
            note: "Should be ignored"
        )
        context.insert(expense!)
        try context.save()
    }
}
