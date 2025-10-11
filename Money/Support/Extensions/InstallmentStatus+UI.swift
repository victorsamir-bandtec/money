import SwiftUI

/// UI extensions for InstallmentStatus enum.
/// Centralizes color, icon, and localized text logic that was duplicated across views.
///
/// **Before (duplicated in multiple views):**
/// ```swift
/// switch status {
/// case .paid: return .green
/// case .partial: return .yellow
/// case .overdue: return .orange
/// case .pending: return .cyan
/// }
/// ```
///
/// **After (using extension):**
/// ```swift
/// let color = status.tintColor
/// let icon = status.iconName
/// let badge = status.badge()
/// ```
extension InstallmentStatus {

    // MARK: - Color Mapping

    /// Returns the appropriate tint color for this status.
    /// Used across Dashboard, DebtorDetail, and Agreement views.
    var tintColor: Color {
        switch self {
        case .paid:
            return .green
        case .partial:
            return .yellow
        case .overdue:
            return .orange
        case .pending:
            return .cyan
        }
    }

    /// Returns a contextual tint color based on whether the agreement is closed.
    /// Pending items in closed agreements appear green instead of cyan.
    ///
    /// Usage:
    /// ```swift
    /// let color = installment.status.tintColor(isClosed: agreement.isClosed)
    /// ```
    func tintColor(isClosed: Bool) -> Color {
        if self == .pending && isClosed {
            return .green
        }
        return tintColor
    }

    // MARK: - Icon Mapping

    /// Returns the SF Symbol name for this status.
    var iconName: String {
        switch self {
        case .paid:
            return "checkmark.circle.fill"
        case .partial:
            return "circle.lefthalf.filled"
        case .overdue:
            return "exclamationmark.triangle.fill"
        case .pending:
            return "clock.fill"
        }
    }

    // MARK: - Localized Text

    /// Returns the localized string key for this status.
    var localizedKey: LocalizedStringKey {
        switch self {
        case .paid:
            return "status.paid"
        case .partial:
            return "status.partial"
        case .overdue:
            return "status.overdue"
        case .pending:
            return "status.pending"
        }
    }

    /// Returns the localized description text.
    var localizedDescription: String {
        switch self {
        case .paid:
            return String(localized: "status.paid")
        case .partial:
            return String(localized: "status.partial")
        case .overdue:
            return String(localized: "status.overdue")
        case .pending:
            return String(localized: "status.pending")
        }
    }

    // MARK: - Status Badge

    /// Creates a StatusBadge configured for this status.
    ///
    /// Usage:
    /// ```swift
    /// installment.status.badge() // Creates appropriate badge
    /// installment.status.badge(size: .small)
    /// ```
    func badge(size: StatusBadge.Size = .medium) -> StatusBadge {
        StatusBadge(localizedKey, tint: tintColor, size: size)
    }

    /// Creates a contextual badge for closed agreements.
    func badge(size: StatusBadge.Size = .medium, isClosed: Bool) -> StatusBadge {
        StatusBadge(localizedKey, tint: tintColor(isClosed: isClosed), size: size)
    }

    // MARK: - Status Priority

    /// Returns a priority value for sorting.
    /// Higher priority = more urgent.
    /// Useful for sorting installments by urgency.
    ///
    /// Usage:
    /// ```swift
    /// installments.sorted { $0.status.priority > $1.status.priority }
    /// ```
    var priority: Int {
        switch self {
        case .overdue:
            return 3
        case .partial:
            return 2
        case .pending:
            return 1
        case .paid:
            return 0
        }
    }

    // MARK: - Status Checks

    /// Returns true if this is a "problem" status (overdue or partial).
    var requiresAttention: Bool {
        self == .overdue || self == .partial
    }

    /// Returns true if payment is complete.
    var isComplete: Bool {
        self == .paid
    }

    /// Returns true if payment is incomplete (pending, partial, or overdue).
    var isIncomplete: Bool {
        !isComplete
    }

    // MARK: - Card Styling

    /// Returns card intensity for this status.
    func cardIntensity(isOverdue: Bool = false) -> MoneyCardIntensity {
        if self == .paid { return .subtle }
        if isOverdue || self == .overdue || self == .partial { return .standard }
        return .subtle
    }
}

// MARK: - Installment UI Extensions

extension Installment {
    /// Returns the tint color for this installment.
    var tintColor: Color {
        status.tintColor
    }

    /// Returns the icon name for this installment's status.
    var statusIconName: String {
        status.iconName
    }

    /// Creates a status badge for this installment.
    func statusBadge(size: StatusBadge.Size = .medium) -> StatusBadge {
        status.badge(size: size)
    }

    /// Returns true if this installment requires attention.
    var requiresAttention: Bool {
        status.requiresAttention
    }
}

// MARK: - Collection Extensions

extension Collection where Element == Installment {
    /// Returns installments that require attention (overdue or partial).
    var requiringAttention: [Installment] {
        self.filter { $0.requiresAttention }
    }

    /// Returns installments sorted by status priority (most urgent first).
    var sortedByPriority: [Installment] {
        self.sorted { $0.status.priority > $1.status.priority }
    }

    /// Returns count of installments by status.
    func count(for status: InstallmentStatus) -> Int {
        self.filter { $0.status == status }.count
    }

    /// Returns installments grouped by status.
    var groupedByStatus: [InstallmentStatus: [Installment]] {
        Dictionary(grouping: self, by: { $0.status })
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension InstallmentStatus {
    /// All status cases for previews and testing.
    static var allCases: [InstallmentStatus] {
        [.pending, .partial, .paid, .overdue]
    }

    /// Sample status for previews.
    static var sample: InstallmentStatus {
        .pending
    }
}
#endif
