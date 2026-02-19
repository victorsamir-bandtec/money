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
        salary + received + variableIncome - (fixedExpenses + variableExpenses)
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
        return try await Task { @MainActor in
            let context = container.mainContext
            let monthStart = Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
            let descriptor = FetchDescriptor<MonthlySnapshot>(
                predicate: #Predicate { snapshot in
                    snapshot.referenceMonth == monthStart
                }
            )
            let summarySnapshot = try context.fetch(descriptor).first

            return WidgetSummary(
                salary: summarySnapshot?.salary ?? .zero,
                received: summarySnapshot?.paymentsReceived ?? .zero,
                overdue: summarySnapshot?.overdueAmount ?? .zero,
                fixedExpenses: summarySnapshot?.fixedExpenses ?? .zero,
                planned: summarySnapshot?.plannedReceivables ?? .zero,
                variableExpenses: summarySnapshot?.variableExpenses ?? .zero,
                variableIncome: summarySnapshot?.variableIncome ?? .zero
            )
        }.value
    }

    /// Fetches upcoming installments with optimized direct query and relationship prefetching
    /// - Parameters:
    ///   - limit: Maximum number of installments to return
    ///   - date: Reference date (defaults to now)
    /// - Returns: Array of upcoming installments sorted by due date
    func fetchUpcomingInstallments(limit: Int = 5, for date: Date = .now) async throws -> [WidgetInstallment] {
        return try await Task { @MainActor in
            let context = container.mainContext
            let startOfDay = Calendar.current.startOfDay(for: date)
            let windowEnd = Calendar.current.date(byAdding: .day, value: WidgetConstants.upcomingDaysWindow, to: startOfDay) ?? startOfDay
            let paidStatusRaw = InstallmentStatus.paid.rawValue

            var descriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
                installment.statusRaw != paidStatusRaw
                    && installment.dueDate <= windowEnd
                    && installment.amount > installment.paidAmount
            })
            descriptor.sortBy = [SortDescriptor(\.dueDate), SortDescriptor(\.number)]
            descriptor.relationshipKeyPathsForPrefetching = [\.agreement, \.agreement.debtor]
            let installments = try context.fetch(descriptor)

            return Array(
                installments.prefix(limit).map { installment in
                    let agreement = installment.agreement
                    return WidgetInstallment(
                        id: installment.id,
                        agreementID: agreement.id,
                        debtorName: agreement.debtor.name,
                        agreementTitle: agreement.title,
                        dueDate: installment.dueDate,
                        amount: installment.remainingAmount,
                        statusRaw: installment.statusRaw,
                        isOverdue: installment.isOverdue(relativeTo: startOfDay)
                    )
                }
            )
        }.value
    }
}
