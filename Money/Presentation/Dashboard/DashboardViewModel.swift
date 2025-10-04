import Foundation
import SwiftData
import Combine

struct DashboardSummary: Sendable, Equatable {
    var monthIncome: Decimal
    var received: Decimal
    var overdue: Decimal
    var fixedExpenses: Decimal
    var salary: Decimal

    var netBalance: Decimal {
        salary + received - fixedExpenses
    }

    static let empty = DashboardSummary(monthIncome: .zero, received: .zero, overdue: .zero, fixedExpenses: .zero, salary: .zero)
}

@MainActor
final class DashboardViewModel: ObservableObject {
    private let context: ModelContext
    private let currencyFormatter: CurrencyFormatter

    @Published var summary: DashboardSummary = .empty
    @Published var upcoming: [Installment] = []
    @Published var alerts: [Installment] = []

    init(context: ModelContext, currencyFormatter: CurrencyFormatter) {
        self.context = context
        self.currencyFormatter = currencyFormatter
    }

    func load(currentDate: Date = .now) throws {
        try fetchSummary(for: currentDate)
        try fetchUpcoming(for: currentDate)
    }

    private func fetchSummary(for date: Date) throws {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, end: date)

        let installmentDescriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
            installment.dueDate >= monthInterval.start && installment.dueDate < monthInterval.end
        })
        let installments = try context.fetch(installmentDescriptor)

        var monthIncome: Decimal = .zero
        var overdue: Decimal = .zero
        var received: Decimal = .zero

        for installment in installments {
            monthIncome += installment.amount
            if installment.isOverdue {
                overdue += installment.remainingAmount
            }
            received += installment.paidAmount
        }

        let expenseDescriptor = FetchDescriptor<FixedExpense>(predicate: #Predicate { expense in
            expense.active
        })
        let expenses = try context.fetch(expenseDescriptor)
        let fixedExpenses = expenses.reduce(into: Decimal.zero) { $0 += $1.amount }

        let salaryDescriptor = FetchDescriptor<SalarySnapshot>(predicate: #Predicate { snapshot in
            snapshot.referenceMonth >= monthInterval.start && snapshot.referenceMonth < monthInterval.end
        })
        let salary = try context.fetch(salaryDescriptor).map(\.amount).reduce(.zero, +)

        summary = DashboardSummary(
            monthIncome: monthIncome,
            received: received,
            overdue: overdue,
            fixedExpenses: fixedExpenses,
            salary: salary
        )
    }

    private func fetchUpcoming(for date: Date) throws {
        let calendar = Calendar.current
        let nextInterval = calendar.date(byAdding: .day, value: 14, to: date) ?? date
        let descriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
            installment.dueDate >= date && installment.dueDate <= nextInterval
        }, sortBy: [SortDescriptor(\.dueDate)])
        let installments = try context.fetch(descriptor)
        upcoming = installments
        alerts = installments.filter { $0.isOverdue || $0.remainingAmount > .zero }
    }

    func formatted(_ value: Decimal) -> String {
        currencyFormatter.string(from: value)
    }
}
