import Foundation
import SwiftData
import SwiftUI

// MARK: - Constants

/// Configuration constants for widget behavior and data fetching
enum WidgetConstants {
    /// Number of days ahead to fetch upcoming installments
    static let upcomingDaysWindow = 14

    /// Maximum installments to display in large widget
    static let maxInstallmentsToDisplay = 5
}

// MARK: - Data Structures

/// Lightweight data structure optimized for widget display
struct WidgetSummary: Sendable, Codable {
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
        salary + received + planned + variableIncome - (fixedExpenses + overdue + variableExpenses)
    }

    static let empty = WidgetSummary(
        salary: .zero,
        received: .zero,
        overdue: .zero,
        fixedExpenses: .zero,
        planned: .zero,
        variableExpenses: .zero,
        variableIncome: .zero
    )
}

/// Compact installment data for widget display
struct WidgetInstallment: Sendable, Codable, Identifiable {
    let id: UUID
    let agreementID: UUID
    let debtorName: String
    let agreementTitle: String?
    let dueDate: Date
    let amount: Decimal
    let statusRaw: Int
    let isOverdue: Bool

    var status: InstallmentStatus {
        InstallmentStatus(rawValue: statusRaw) ?? .pending
    }

    var displayTitle: String {
        agreementTitle ?? debtorName
    }
}

// MARK: - Shared Helpers

extension WidgetSummary {
    /// Shared formatter for all widget views - eliminates duplicate instances
    static let formatter = CurrencyFormatter()

    /// Semantic color for available balance
    var availableTint: Color {
        availableToSpend >= .zero ? .seaGreen : .red
    }

    /// Check if summary has no data
    var isEmpty: Bool {
        salary == .zero &&
        received == .zero &&
        overdue == .zero &&
        planned == .zero &&
        fixedExpenses == .zero
    }
}

/// Optimized data provider for widget extension
/// Uses efficient queries and minimal memory footprint
final class WidgetDataProvider: Sendable {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    /// Convenience initializer using shared container
    static func shared() throws -> WidgetDataProvider {
        let container = try SharedContainer.createModelContainer()
        return WidgetDataProvider(container: container)
    }

    /// Fetches widget summary with optimized queries using direct date predicates
    /// - Parameter date: Reference date for calculations (defaults to now)
    /// - Returns: WidgetSummary with current financial metrics
    func fetchWidgetSummary(for date: Date = .now) async throws -> WidgetSummary {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let monthInterval = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: startOfDay, end: startOfDay)

        return try await Task { @MainActor in
            let context = container.mainContext

            // Query 1a: Overdue installments (direct predicate - no memory filtering)
            let paidStatusRaw = InstallmentStatus.paid.rawValue
            let overdueDescriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
                installment.dueDate < startOfDay && installment.statusRaw != paidStatusRaw
            })
            let overdueInstallments = try context.fetch(overdueDescriptor)
            overdueInstallments.forEach { _ = $0.paidAmount } // Trigger paidAmount computation
            let overdueTotal = overdueInstallments
                .filter { $0.remainingAmount > .zero }
                .reduce(Decimal.zero) { $0 + $1.remainingAmount }

            // Query 1b: Planned installments for rest of month (direct predicate)
            let plannedDescriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
                installment.dueDate >= startOfDay &&
                installment.dueDate < monthInterval.end &&
                installment.statusRaw != paidStatusRaw
            })
            let plannedInstallments = try context.fetch(plannedDescriptor)
            plannedInstallments.forEach { _ = $0.paidAmount }
            let planned = plannedInstallments
                .filter { $0.remainingAmount > .zero }
                .reduce(Decimal.zero) { $0 + $1.remainingAmount }

            // Query 2: Payments received this month
            let paymentsDescriptor = FetchDescriptor<Payment>(predicate: #Predicate { payment in
                payment.date >= monthInterval.start && payment.date < monthInterval.end
            })
            let received = try context.fetch(paymentsDescriptor).reduce(Decimal.zero) { $0 + $1.amount }

            // Query 3: Active fixed expenses + salary (separate but adjacent)
            let expenseDescriptor = FetchDescriptor<FixedExpense>(predicate: #Predicate { $0.active })
            let fixedExpenses = try context.fetch(expenseDescriptor).reduce(Decimal.zero) { $0 + $1.amount }

            let salaryDescriptor = FetchDescriptor<SalarySnapshot>(predicate: #Predicate { snapshot in
                snapshot.referenceMonth >= monthInterval.start && snapshot.referenceMonth < monthInterval.end
            })
            let salary = try context.fetch(salaryDescriptor).reduce(Decimal.zero) { $0 + $1.amount }

            // Query 4: Variable transactions (income + expenses in single query)
            let transactionsDescriptor = FetchDescriptor<CashTransaction>(predicate: #Predicate { transaction in
                transaction.date >= monthInterval.start && transaction.date < monthInterval.end
            })
            let transactions = try context.fetch(transactionsDescriptor)

            var variableExpenses = Decimal.zero
            var variableIncome = Decimal.zero
            for transaction in transactions {
                if transaction.type == .expense {
                    variableExpenses += transaction.amount
                } else {
                    variableIncome += transaction.amount
                }
            }

            return WidgetSummary(
                salary: salary,
                received: received,
                overdue: overdueTotal,
                fixedExpenses: fixedExpenses,
                planned: planned,
                variableExpenses: variableExpenses,
                variableIncome: variableIncome
            )
        }.value
    }

    /// Fetches upcoming installments with optimized direct query and relationship prefetching
    /// - Parameters:
    ///   - limit: Maximum number of installments to return
    ///   - date: Reference date (defaults to now)
    /// - Returns: Array of upcoming installments sorted by due date
    func fetchUpcomingInstallments(limit: Int = 5, for date: Date = .now) async throws -> [WidgetInstallment] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let windowEnd = calendar.date(byAdding: .day, value: WidgetConstants.upcomingDaysWindow, to: startOfDay) ?? startOfDay

        return try await Task { @MainActor in
            let context = container.mainContext

            // Direct query with prefetching to avoid N+1 problem
            let paidStatusRaw = InstallmentStatus.paid.rawValue
            var descriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
                installment.dueDate < windowEnd && installment.statusRaw != paidStatusRaw
            })
            descriptor.sortBy = [SortDescriptor(\.dueDate)]
            descriptor.relationshipKeyPathsForPrefetching = [\.agreement, \.agreement.debtor]

            let installments = try context.fetch(descriptor)

            // Map to widget format, filter remaining > 0, and limit
            let snapshots = installments
                .filter { $0.remainingAmount > .zero }
                .prefix(limit)
                .map { installment -> WidgetInstallment in
                    let agreement = installment.agreement
                    return WidgetInstallment(
                        id: installment.id,
                        agreementID: agreement.id,
                        debtorName: agreement.debtor.name,
                        agreementTitle: agreement.title,
                        dueDate: installment.dueDate,
                        amount: installment.amount,
                        statusRaw: installment.statusRaw,
                        isOverdue: installment.dueDate < startOfDay
                    )
                }

            return Array(snapshots)
        }.value
    }
}
