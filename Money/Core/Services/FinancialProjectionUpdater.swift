import Foundation
import SwiftData

protocol FinancialProjectionUpdating: Sendable {
    @MainActor
    func refreshForCurrentMonth(context: ModelContext, referenceDate: Date) throws

    @MainActor
    func refreshForHistory(context: ModelContext, referenceDate: Date, monthsBack: Int) throws
}

@MainActor
final class FinancialProjectionUpdater: FinancialProjectionUpdating {
    func refreshForCurrentMonth(context: ModelContext, referenceDate: Date = .now) throws {
        let monthStart = Calendar.current.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
        _ = try rebuildSnapshot(for: monthStart, asOf: referenceDate, context: context)
    }

    func refreshForHistory(context: ModelContext, referenceDate: Date = .now, monthsBack: Int = 12) throws {
        let calendar = Calendar.current
        let endMonth = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
        let startMonth = calendar.date(byAdding: .month, value: -max(monthsBack, 0), to: endMonth) ?? endMonth

        var monthCursor = startMonth
        while monthCursor <= endMonth {
            let monthInterval = calendar.dateInterval(of: .month, for: monthCursor)
                ?? DateInterval(start: monthCursor, end: monthCursor)
            let isCurrentMonth = monthCursor == endMonth
            let asOfDate = isCurrentMonth ? referenceDate : monthInterval.end
            _ = try rebuildSnapshot(for: monthCursor, asOf: asOfDate, context: context)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthCursor) else { break }
            monthCursor = nextMonth
        }
    }

    @discardableResult
    private func rebuildSnapshot(for monthStart: Date, asOf referenceDate: Date, context: ModelContext) throws -> MonthlySnapshot {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: monthStart) ?? DateInterval(start: monthStart, end: monthStart)
        let paidStatusRaw = InstallmentStatus.paid.rawValue
        let startOfMonth = monthInterval.start
        let endOfMonth = monthInterval.end
        let cutoffDate = min(max(referenceDate, startOfMonth), endOfMonth)

        let existingSnapshotDescriptor = FetchDescriptor<MonthlySnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.referenceMonth == startOfMonth
            }
        )
        let existingSnapshot = try context.fetch(existingSnapshotDescriptor).first
        let snapshot = existingSnapshot ?? MonthlySnapshot(referenceMonth: startOfMonth)

        let salaryDescriptor = FetchDescriptor<SalarySnapshot>(predicate: #Predicate { salary in
            salary.referenceMonth >= startOfMonth && salary.referenceMonth < endOfMonth
        })
        snapshot.salary = try context.fetch(salaryDescriptor).reduce(.zero) { $0 + $1.amount }

        let paymentsDescriptor = FetchDescriptor<Payment>(predicate: #Predicate { payment in
            payment.date >= startOfMonth && payment.date < endOfMonth
        })
        snapshot.paymentsReceived = try context.fetch(paymentsDescriptor).reduce(.zero) { $0 + $1.amount }

        let transactionsDescriptor = FetchDescriptor<CashTransaction>(predicate: #Predicate { transaction in
            transaction.date >= startOfMonth && transaction.date < endOfMonth
        })
        let transactions = try context.fetch(transactionsDescriptor)
        snapshot.variableIncome = transactions
            .filter { $0.type == .income }
            .reduce(.zero) { $0 + $1.amount }
        snapshot.variableExpenses = transactions
            .filter { $0.type == .expense }
            .reduce(.zero) { $0 + $1.amount }

        let expensesDescriptor = FetchDescriptor<FixedExpense>(predicate: #Predicate { expense in
            expense.active
        })
        snapshot.fixedExpenses = try context.fetch(expensesDescriptor).reduce(.zero) { $0 + $1.amount }

        let overdueDescriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
            installment.dueDate < endOfMonth && installment.statusRaw != paidStatusRaw
        })
        let receivableInstallments = try context.fetch(overdueDescriptor)
        snapshot.overdueAmount = receivableInstallments
            .filter { $0.dueDate < cutoffDate && $0.remainingAmount > .zero }
            .reduce(.zero) { $0 + $1.remainingAmount }
        snapshot.plannedReceivables = receivableInstallments
            .filter { $0.dueDate >= cutoffDate && $0.dueDate < endOfMonth && $0.remainingAmount > .zero }
            .reduce(.zero) { $0 + $1.remainingAmount }

        let agreementsDescriptor = FetchDescriptor<DebtAgreement>(predicate: #Predicate { agreement in
            !agreement.closed
        })
        let activeAgreements = try context.fetch(agreementsDescriptor)
        snapshot.activeAgreements = activeAgreements.count
        snapshot.activeDebtors = Set(activeAgreements.map { $0.debtor.id }).count

        snapshot.totalIncome = snapshot.salary + snapshot.paymentsReceived + snapshot.variableIncome
        snapshot.totalExpenses = snapshot.fixedExpenses + snapshot.variableExpenses
        snapshot.netBalance = snapshot.totalIncome - snapshot.totalExpenses

        if existingSnapshot == nil {
            context.insert(snapshot)
        }

        try context.save()
        return snapshot
    }
}
