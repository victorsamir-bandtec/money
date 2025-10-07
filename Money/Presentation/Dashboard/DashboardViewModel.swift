import Foundation
import SwiftData
import Combine

struct DashboardSummary: Sendable, Equatable {
    var salary: Decimal
    var received: Decimal
    var overdue: Decimal
    var fixedExpenses: Decimal
    var planned: Decimal
    var variableExpenses: Decimal
    var variableIncome: Decimal
    var remainingToReceive: Decimal
    var availableToSpend: Decimal

    init(
        salary: Decimal,
        received: Decimal,
        overdue: Decimal,
        fixedExpenses: Decimal,
        planned: Decimal,
        variableExpenses: Decimal = .zero,
        variableIncome: Decimal = .zero
    ) {
        self.salary = salary
        self.received = received
        self.overdue = overdue
        self.fixedExpenses = fixedExpenses
        self.planned = planned
        self.variableExpenses = variableExpenses
        self.variableIncome = variableIncome
        self.remainingToReceive = planned + overdue
        self.availableToSpend = salary + received + planned + variableIncome - (fixedExpenses + overdue + variableExpenses)
    }

    var totalExpenses: Decimal {
        fixedExpenses + variableExpenses
    }

    var variableBalance: Decimal {
        variableIncome - variableExpenses
    }

    static let empty = DashboardSummary(salary: .zero, received: .zero, overdue: .zero, fixedExpenses: .zero, planned: .zero)
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
        let startOfDay = calendar.startOfDay(for: date)
        let monthInterval = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: startOfDay, end: startOfDay)

        // Parcelas previstas para o restante do mês (a receber)
        let monthlyDescriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
            installment.dueDate >= monthInterval.start && installment.dueDate < monthInterval.end
        })
        var monthInstallments = try context.fetch(monthlyDescriptor)
        monthInstallments.forEach { _ = $0.paidAmount }
        let plannedInstallments = monthInstallments.filter { installment in
            installment.dueDate >= startOfDay && installment.status != .paid && installment.remainingAmount > .zero
        }
        let planned = plannedInstallments.reduce(into: Decimal.zero) { $0 += $1.remainingAmount }

        // Total em atraso acumulado (qualquer parcela vencida com valor restante)
        let paidStatusRawValue = InstallmentStatus.paid.rawValue
        let overdueDescriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
            installment.dueDate < startOfDay && installment.statusRaw != paidStatusRawValue
        })
        var overdueInstallments = try context.fetch(overdueDescriptor)
        overdueInstallments.forEach { _ = $0.paidAmount }
        overdueInstallments = overdueInstallments.filter { $0.remainingAmount > .zero }
        let overdueTotal = overdueInstallments.reduce(into: Decimal.zero) { $0 += $1.remainingAmount }

        // Recebido no mês corrente
        let paymentsDescriptor = FetchDescriptor<Payment>(predicate: #Predicate { payment in
            payment.date >= monthInterval.start && payment.date < monthInterval.end
        })
        let payments = try context.fetch(paymentsDescriptor)
        let received: Decimal = payments.reduce(.zero) { $0 + $1.amount }

        // Despesas fixas ativas
        let expenseDescriptor = FetchDescriptor<FixedExpense>(predicate: #Predicate { expense in
            expense.active
        })
        let expenses = try context.fetch(expenseDescriptor)
        let fixedExpenses = expenses.reduce(into: Decimal.zero) { $0 += $1.amount }

        // Salário registrado para o mês corrente
        let salaryDescriptor = FetchDescriptor<SalarySnapshot>(predicate: #Predicate { snapshot in
            snapshot.referenceMonth >= monthInterval.start && snapshot.referenceMonth < monthInterval.end
        })
        let salary = try context.fetch(salaryDescriptor).map(\.amount).reduce(.zero, +)

        let transactionsDescriptor = FetchDescriptor<CashTransaction>(predicate: #Predicate { transaction in
            transaction.date >= monthInterval.start && transaction.date < monthInterval.end
        })
        let transactions = try context.fetch(transactionsDescriptor)
        let variableExpenses = transactions
            .filter { $0.type == .expense }
            .reduce(into: Decimal.zero) { $0 += $1.amount }
        let variableIncome = transactions
            .filter { $0.type == .income }
            .reduce(into: Decimal.zero) { $0 += $1.amount }

        summary = DashboardSummary(
            salary: salary,
            received: received,
            overdue: overdueTotal,
            fixedExpenses: fixedExpenses,
            planned: planned,
            variableExpenses: variableExpenses,
            variableIncome: variableIncome
        )
    }

    private func fetchUpcoming(for date: Date) throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let windowEnd = calendar.date(byAdding: .day, value: 14, to: startOfDay) ?? startOfDay

        let paidStatusRawValue = InstallmentStatus.paid.rawValue
        let overdueDescriptor = FetchDescriptor<Installment>(
            predicate: #Predicate { installment in
                installment.dueDate < startOfDay && installment.statusRaw != paidStatusRawValue
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        var overdueInstallments = try context.fetch(overdueDescriptor)
        overdueInstallments.forEach { _ = $0.paidAmount }
        overdueInstallments = overdueInstallments.filter { $0.remainingAmount > .zero }

        let upcomingDescriptor = FetchDescriptor<Installment>(
            predicate: #Predicate { installment in
                installment.dueDate >= startOfDay && installment.dueDate <= windowEnd && installment.statusRaw != paidStatusRawValue
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        var upcomingInstallments = try context.fetch(upcomingDescriptor)
        upcomingInstallments.forEach { _ = $0.paidAmount }
        upcomingInstallments = upcomingInstallments.filter { $0.remainingAmount > .zero }

        var combined = overdueInstallments
        let existingIds = Set(combined.map(\.id))
        let filteredUpcoming = upcomingInstallments.filter { !existingIds.contains($0.id) }
        combined.append(contentsOf: filteredUpcoming)
        combined.sort { lhs, rhs in
            if lhs.dueDate == rhs.dueDate {
                return lhs.number < rhs.number
            }
            return lhs.dueDate < rhs.dueDate
        }

        upcoming = combined
        alerts = combined
    }

    func formatted(_ value: Decimal) -> String {
        currencyFormatter.string(from: value)
    }
}
