import Foundation
import SwiftData
import UserNotifications

@MainActor
final class AppEnvironment {
    let featureFlagsStore: FeatureFlagsStoring
    var featureFlags: FeatureFlags
    let container: ModelContainer
    let modelContext: ModelContext
    let financeCalculator: FinanceCalculator
    let currencyFormatter: CurrencyFormatter
    let notificationScheduler: NotificationScheduling
    let sampleDataService: SampleDataService

    init(
        featureFlags: FeatureFlags? = nil,
        featureFlagsStore: FeatureFlagsStoring? = nil,
        configuration: ModelConfiguration? = nil
    ) {
        let store = featureFlagsStore ?? FeatureFlagsStore()
        self.featureFlagsStore = store
        let resolvedFeatureFlags: FeatureFlags
        if let featureFlags {
            resolvedFeatureFlags = featureFlags
            store.save(featureFlags)
        } else {
            resolvedFeatureFlags = store.load()
        }
        self.featureFlags = resolvedFeatureFlags
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            FixedExpense.self,
            SalarySnapshot.self
        ])
        let modelConfiguration = configuration ?? ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: modelConfiguration)
        } catch {
            fatalError("Não foi possível configurar SwiftData: \(error)")
        }
        modelContext = container.mainContext
        financeCalculator = FinanceCalculator()
        currencyFormatter = CurrencyFormatter()
        notificationScheduler = LocalNotificationScheduler(center: UNUserNotificationCenter.current())
        sampleDataService = SampleDataService(context: modelContext, financeCalculator: financeCalculator)
    }

    func saveFeatureFlags() {
        featureFlagsStore.save(featureFlags)
    }
}
