import Foundation
import SwiftData

struct FinancialSummarySnapshot: Equatable, Sendable {
    let salary: Decimal
    let received: Decimal
    let overdue: Decimal
    let fixedExpenses: Decimal
    let planned: Decimal
    let variableExpenses: Decimal
    let variableIncome: Decimal

    var remainingToReceive: Decimal {
        planned + overdue
    }

    var availableToSpend: Decimal {
        (salary + received + variableIncome) - (fixedExpenses + variableExpenses)
    }

    static let empty = FinancialSummarySnapshot(
        salary: .zero,
        received: .zero,
        overdue: .zero,
        fixedExpenses: .zero,
        planned: .zero,
        variableExpenses: .zero,
        variableIncome: .zero
    )
}

struct UpcomingInstallmentSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let agreementID: UUID
    let debtorName: String
    let agreementTitle: String?
    let dueDate: Date
    let amount: Decimal
    let number: Int
    let statusRaw: Int
    let isOverdue: Bool

    var status: InstallmentStatus {
        InstallmentStatus(rawValue: statusRaw) ?? .pending
    }

    var displayTitle: String {
        agreementTitle ?? debtorName
    }
}

protocol FinancialSummaryQuerying: Sendable {
    @MainActor
    func summary(for date: Date) throws -> FinancialSummarySnapshot

    @MainActor
    func upcomingInstallments(for date: Date, windowDays: Int) throws -> [UpcomingInstallmentSnapshot]

    @MainActor
    func history(from startDate: Date, to endDate: Date) throws -> [MonthlySnapshot]
}

@MainActor
final class FinancialReadModelService: FinancialSummaryQuerying {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func summary(for date: Date) throws -> FinancialSummarySnapshot {
        let monthStart = Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
        let descriptor = FetchDescriptor<MonthlySnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.referenceMonth == monthStart
            }
        )

        guard let snapshot = try context.fetch(descriptor).first else {
            return .empty
        }

        return FinancialSummarySnapshot(
            salary: snapshot.salary,
            received: snapshot.paymentsReceived,
            overdue: snapshot.overdueAmount,
            fixedExpenses: snapshot.fixedExpenses,
            planned: snapshot.plannedReceivables,
            variableExpenses: snapshot.variableExpenses,
            variableIncome: snapshot.variableIncome
        )
    }

    func upcomingInstallments(for date: Date, windowDays: Int = 14) throws -> [UpcomingInstallmentSnapshot] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let windowEnd = calendar.date(byAdding: .day, value: windowDays, to: startOfDay) ?? startOfDay
        let paidStatusRaw = InstallmentStatus.paid.rawValue

        var descriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
            installment.statusRaw != paidStatusRaw
                && installment.dueDate <= windowEnd
                && installment.amount > installment.paidAmount
        })
        descriptor.sortBy = [SortDescriptor(\.dueDate), SortDescriptor(\.number)]
        descriptor.relationshipKeyPathsForPrefetching = [\.agreement, \.agreement.debtor]

        let installments = try context.fetch(descriptor)
        return installments.map { installment in
            let agreement = installment.agreement
            return UpcomingInstallmentSnapshot(
                id: installment.id,
                agreementID: agreement.id,
                debtorName: agreement.debtor.name,
                agreementTitle: agreement.title,
                dueDate: installment.dueDate,
                amount: installment.remainingAmount,
                number: installment.number,
                statusRaw: installment.statusRaw,
                isOverdue: installment.isOverdue(relativeTo: startOfDay)
            )
        }
    }

    func history(from startDate: Date, to endDate: Date) throws -> [MonthlySnapshot] {
        let descriptor = FetchDescriptor<MonthlySnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.referenceMonth >= startDate && snapshot.referenceMonth <= endDate
            },
            sortBy: [SortDescriptor(\.referenceMonth, order: .forward)]
        )
        return try context.fetch(descriptor)
    }
}
