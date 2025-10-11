import SwiftUI

/// Centralized color palette for widgets
/// Ensures visual consistency across all widget sizes
extension Color {
    /// Primary brand color - SeaGreen (#2E8B57)
    /// Used for positive values, income, and primary actions
    static let seaGreen = Color(red: 46/255, green: 139/255, blue: 87/255)

    /// Dark expense red - Used for fixed expenses
    static let expenseRed = Color(red: 220/255, green: 38/255, blue: 38/255)

    /// Vibrant overdue red - Used for overdue amounts and alerts
    static let overdueRed = Color(red: 255/255, green: 59/255, blue: 48/255)

    /// Warning orange - Used for expense ratio warnings
    static let warningOrange = Color(red: 255/255, green: 149/255, blue: 0/255)
}
