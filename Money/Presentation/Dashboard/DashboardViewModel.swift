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
    private var notificationObservers: [Any] = []

    @Published var summary: DashboardSummary = .empty
    @Published var upcoming: [Installment] = []
    @Published var alerts: [Installment] = []

    init(context: ModelContext, currencyFormatter: CurrencyFormatter) {
        self.context = context
        self.currencyFormatter = currencyFormatter
        setupNotificationObservers()
    }

    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func setupNotificationObservers() {
        // Observe financial data changes to reload dashboard metrics
        let financialObserver = NotificationCenter.default.addObserver(
            forName: .financialDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? self?.load()
            }
        }
        notificationObservers.append(financialObserver)

        // Also observe payment data changes specifically
        let paymentObserver = NotificationCenter.default.addObserver(
            forName: .paymentDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? self?.load()
            }
        }
        notificationObservers.append(paymentObserver)
    }

    func load(currentDate: Date = .now) throws {
        try fetchSummary(for: currentDate)
        try fetchUpcoming(for: currentDate)
    }

    private func fetchSummary(for date: Date) throws {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, end: date)

        // Income for the month is based on installments due in this month
        let installmentDescriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
            installment.dueDate >= monthInterval.start && installment.dueDate < monthInterval.end
        })
        let installments = try context.fetch(installmentDescriptor)

        // Force access to ensure fresh data from ModelContext (not cached)
        installments.forEach { _ = $0.paidAmount }

        var monthIncome: Decimal = .zero
        var overdue: Decimal = .zero
        for installment in installments {
            monthIncome += installment.amount
            if installment.isOverdue {
                overdue += installment.remainingAmount
            }
        }

        // Received in the month is derived from actual payments logged in the month,
        // regardless of the installment's due month. This ensures the dashboard reacts
        // immediately after a payment is registered.
        let paymentsDescriptor = FetchDescriptor<Payment>(predicate: #Predicate { payment in
            payment.date >= monthInterval.start && payment.date < monthInterval.end
        })
        let payments = try context.fetch(paymentsDescriptor)
        let received: Decimal = payments.reduce(.zero) { $0 + $1.amount }

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

        // Force access to ensure fresh data from ModelContext (not cached)
        installments.forEach { _ = $0.paidAmount }

        upcoming = installments
        alerts = installments.filter { $0.isOverdue || $0.remainingAmount > .zero }
    }

    func formatted(_ value: Decimal) -> String {
        currencyFormatter.string(from: value)
    }
}
