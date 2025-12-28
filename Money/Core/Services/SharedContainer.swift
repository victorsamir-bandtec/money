import Foundation
import SwiftData

/// Manages shared container configuration for app and widget extension
enum SharedContainer {
    /// App Group identifier for sharing data between app and widget
    static let appGroupIdentifier = "group.victor-samir.Money"

    /// Returns the shared container URL for the app group
    static var sharedContainerURL: URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            fatalError("App Group container não configurado. Verifique Signing & Capabilities no Xcode.")
        }
        return containerURL
    }

    /// Returns the ModelConfiguration configured for the shared container
    static var modelConfiguration: ModelConfiguration {
        let storeURL = sharedContainerURL.appendingPathComponent("Money.sqlite")
        return ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
    }

    /// Creates a ModelContainer configured for the shared container
    /// - Parameter isStoredInMemoryOnly: If true, creates in-memory container for testing
    /// - Returns: Configured ModelContainer
    static func createModelContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        #if APPEX
        // Widget extension - deve incluir mesmos modelos da aplicação principal
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            CashTransaction.self,
            FixedExpense.self,
            SalarySnapshot.self,
            MonthlySnapshot.self,
            CashFlowProjection.self
        ])
        #else
        // App principal - todos os modelos incluindo analytics
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            CashTransaction.self,
            FixedExpense.self,
            SalarySnapshot.self,
            MonthlySnapshot.self,
            CashFlowProjection.self
        ])
        #endif

        let configuration = isStoredInMemoryOnly ? ModelConfiguration(isStoredInMemoryOnly: true) : modelConfiguration

        return try ModelContainer(for: schema, configurations: configuration)
    }
}
