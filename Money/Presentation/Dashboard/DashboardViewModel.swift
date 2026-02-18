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
        // Saldo disponível: (Salário + Recebimentos + Renda Extra) - (Despesas Fixas + Despesas Variáveis)
        // Ignora previsões (planned/overdue) para focar na liquidez real/projetada segura.
        self.availableToSpend = (salary + received + variableIncome) - (fixedExpenses + variableExpenses)
    }

    var totalExpenses: Decimal {
        fixedExpenses + variableExpenses
    }
    
    var totalIncome: Decimal {
        salary + received + variableIncome
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

    init(installment: Installment, agreement: DebtAgreement, referenceDate: Date = .now) {
        self.id = installment.id
        self.agreementID = agreement.id
        self.debtorName = agreement.debtor.name
        self.agreementTitle = agreement.title
        self.dueDate = installment.dueDate
        self.amount = installment.amount
        self.status = installment.status
        self.number = installment.number
        self.isOverdue = installment.isOverdue(relativeTo: referenceDate)
    }

    var displayTitle: String {
        agreementTitle ?? debtorName
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    private let context: ModelContext
    private let currencyFormatter: CurrencyFormatter
    private let financialObserver = DebouncedNotificationObserver(.financialDataDidChange, debounceInterval: 0.4)
    private let paymentObserver = DebouncedNotificationObserver(.paymentDataDidChange, debounceInterval: 0.4)

    @Published var summary: DashboardSummary = .empty
    @Published var upcoming: [InstallmentOverview] = []
    @Published var alerts: [InstallmentOverview] = []

    init(context: ModelContext, currencyFormatter: CurrencyFormatter) {
        self.context = context
        self.currencyFormatter = currencyFormatter
        financialObserver.observe { [weak self] in try? self?.load() }
        paymentObserver.observe { [weak self] in try? self?.load() }
    }

    func load(currentDate: Date = .now) throws {
        try loadSummary(currentDate: currentDate)
        try loadInstallments(currentDate: currentDate)
    }

    func loadSummary(currentDate: Date = .now) throws {
        try fetchSummary(for: currentDate)
    }

    func loadInstallments(currentDate: Date = .now) throws {
        try fetchUpcoming(for: currentDate)
    }

    private func fetchSummary(for date: Date) throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let monthInterval = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: startOfDay, end: startOfDay)

        let paidStatusRaw = InstallmentStatus.paid.rawValue
        let openInstallmentsDescriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
            installment.dueDate < monthInterval.end
            && installment.statusRaw != paidStatusRaw
            && installment.amount > installment.paidAmount
        })
        let openInstallments = try context.fetch(openInstallmentsDescriptor)
        var planned = Decimal.zero
        var overdueTotal = Decimal.zero
        for installment in openInstallments {
            if installment.dueDate >= startOfDay {
                planned += installment.remainingAmount
            } else {
                overdueTotal += installment.remainingAmount
            }
        }

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
            transaction.date >= monthInterval.start
            && transaction.date < monthInterval.end
        })
        let transactions = try context.fetch(transactionsDescriptor)
        var variableExpenses = Decimal.zero
        var variableIncome = Decimal.zero
        for transaction in transactions {
            if transaction.typeRaw == CashTransactionType.expense.rawValue {
                variableExpenses += transaction.amount
            } else if transaction.typeRaw == CashTransactionType.income.rawValue {
                variableIncome += transaction.amount
            }
        }

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
        let paidStatusRaw = InstallmentStatus.paid.rawValue
        let predicate = #Predicate<Installment> { installment in
            installment.statusRaw != paidStatusRaw
            && installment.dueDate <= windowEnd
            && installment.amount > installment.paidAmount
        }
        var descriptor = FetchDescriptor<Installment>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.dueDate), SortDescriptor(\.number)]
        let allInstallments = try context.fetch(descriptor)

        let snapshots = allInstallments.map { installment in
            InstallmentOverview(installment: installment, agreement: installment.agreement, referenceDate: date)
        }

        if upcoming != snapshots {
            upcoming = snapshots
            alerts = snapshots
        }
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
