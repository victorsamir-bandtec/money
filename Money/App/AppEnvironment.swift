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
    let debtService: DebtService
    let notificationScheduler: NotificationScheduling
    let sampleDataService: SampleDataService

    init(
        featureFlags: FeatureFlags? = nil,
        featureFlagsStore: FeatureFlagsStoring? = nil,
        notificationScheduler: NotificationScheduling? = nil,
        isStoredInMemoryOnly: Bool = false
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

        // Use SharedContainer for app group support (widget data sharing)
        do {
            container = try SharedContainer.createModelContainer(isStoredInMemoryOnly: isStoredInMemoryOnly)
        } catch {
            fatalError("Não foi possível configurar SwiftData: \(error)")
        }
        modelContext = container.mainContext
        financeCalculator = FinanceCalculator()
        currencyFormatter = CurrencyFormatter()
        debtService = DebtService(calculator: financeCalculator)
        if let notificationScheduler {
            self.notificationScheduler = notificationScheduler
        } else {
            self.notificationScheduler = LocalNotificationScheduler(center: UNUserNotificationCenter.current())
        }
        sampleDataService = SampleDataService(
            context: modelContext,
            financeCalculator: financeCalculator,
            notificationScheduler: self.notificationScheduler
        )
    }

    func saveFeatureFlags() {
        featureFlagsStore.save(featureFlags)
    }
}
