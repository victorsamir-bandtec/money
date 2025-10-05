import Foundation

/// Notification names for cross-ViewModel data synchronization
extension Notification.Name {
    /// Posted when payment data is modified (payments added, removed, installments updated)
    static let paymentDataDidChange = Notification.Name("com.money.paymentDataDidChange")

    /// Posted when agreement data is modified (agreements created, updated, closed)
    static let agreementDataDidChange = Notification.Name("com.money.agreementDataDidChange")

    /// Posted when debtor data is modified (debtors created, updated, archived)
    static let debtorDataDidChange = Notification.Name("com.money.debtorDataDidChange")

    /// Posted when any financial data changes (catch-all for dashboard updates)
    static let financialDataDidChange = Notification.Name("com.money.financialDataDidChange")
}
