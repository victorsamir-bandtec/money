import Foundation

/// Notification names for cross-ViewModel data synchronization
extension Notification.Name {
    /// Posted when payment data is modified (payments added, removed, installments updated)
    nonisolated static let paymentDataDidChange = Notification.Name("com.money.paymentDataDidChange")

    /// Posted when agreement data is modified (agreements created, updated, closed)
    nonisolated static let agreementDataDidChange = Notification.Name("com.money.agreementDataDidChange")

    /// Posted when debtor data is modified (debtors created, updated, archived)
    nonisolated static let debtorDataDidChange = Notification.Name("com.money.debtorDataDidChange")

    /// Posted when any financial data changes (catch-all for dashboard updates)
    nonisolated static let financialDataDidChange = Notification.Name("com.money.financialDataDidChange")

    /// Posted when cash transactions are modified (variable expenses/income)
    nonisolated static let cashTransactionDataDidChange = Notification.Name("com.money.cashTransactionDataDidChange")
}

extension NotificationCenter {
    /// Posts standard data change notifications so other view models can refresh state.
    @MainActor
    func postFinanceDataUpdates(agreementChanged: Bool) {
        post(name: .paymentDataDidChange, object: nil)
        post(name: .financialDataDidChange, object: nil)
        if agreementChanged {
            post(name: .agreementDataDidChange, object: nil)
        }
    }

    /// Convenience method for broadcasting updates when transactions change.
    @MainActor
    func postTransactionDataUpdates() {
        post(name: .cashTransactionDataDidChange, object: nil)
        post(name: .financialDataDidChange, object: nil)
    }

    /// Broadcasts a full data reset so all dashboards and lists can refresh immediately.
    @MainActor
    func postDataStoreCleared() {
        post(name: .debtorDataDidChange, object: nil)
        post(name: .agreementDataDidChange, object: nil)
        post(name: .paymentDataDidChange, object: nil)
        post(name: .cashTransactionDataDidChange, object: nil)
        post(name: .financialDataDidChange, object: nil)
    }
}
