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

struct InstallmentOverview: Identifiable, Equatable, Sendable {
    let id: UUID
    let agreementID: UUID
    let debtorName: String
    let agreementTitle: String?
    let dueDate: Date
    let amount: Decimal
    let status: InstallmentStatus
    let number: Int
    let isOverdue: Bool

    init(installment: Installment, agreement: DebtAgreement) {
        self.id = installment.id
        self.agreementID = agreement.id
        self.debtorName = agreement.debtor.name
        self.agreementTitle = agreement.title
        self.dueDate = installment.dueDate
        self.amount = installment.amount
        self.status = installment.status
        self.number = installment.number
        self.isOverdue = installment.isOverdue
    }

    var displayTitle: String {
        agreementTitle ?? debtorName
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    private let context: ModelContext
    private let currencyFormatter: CurrencyFormatter
    private let observers = NotificationObservers()

    @Published var summary: DashboardSummary = .empty
    @Published var upcoming: [InstallmentOverview] = []
    @Published var alerts: [InstallmentOverview] = []

    init(context: ModelContext, currencyFormatter: CurrencyFormatter) {
        self.context = context
        self.currencyFormatter = currencyFormatter
        observers.observe(.financialDataDidChange) { [weak self] in try? self?.load() }
        observers.observe(.paymentDataDidChange) { [weak self] in try? self?.load() }
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

        let agreementDescriptor = FetchDescriptor<DebtAgreement>()
        let agreements = try context.fetch(agreementDescriptor)
        var overdueSnapshots: [InstallmentOverview] = []
        var upcomingSnapshots: [InstallmentOverview] = []

        for agreement in agreements {
            for installment in agreement.installments {
                let remaining = installment.remainingAmount
                guard remaining > .zero else { continue }

                if installment.status == .paid { continue }

                let snapshot = InstallmentOverview(installment: installment, agreement: agreement)

                if installment.dueDate < startOfDay {
                    overdueSnapshots.append(snapshot)
                } else if installment.dueDate <= windowEnd {
                    upcomingSnapshots.append(snapshot)
                }
            }
        }

        overdueSnapshots.sort(by: Self.installmentSorter)
        upcomingSnapshots.sort(by: Self.installmentSorter)

        let existingIds = Set(overdueSnapshots.map(\.id))
        let filteredUpcoming = upcomingSnapshots.filter { !existingIds.contains($0.id) }
        var combined = overdueSnapshots + filteredUpcoming
        combined.sort(by: Self.installmentSorter)

        let snapshots = combined
        upcoming = snapshots
        alerts = snapshots
    }

    func formatted(_ value: Decimal) -> String {
        currencyFormatter.string(from: value)
    }

    private static func installmentSorter(_ lhs: InstallmentOverview, _ rhs: InstallmentOverview) -> Bool {
        if lhs.dueDate == rhs.dueDate {
            return lhs.number < rhs.number
        }
        return lhs.dueDate < rhs.dueDate
    }
}
