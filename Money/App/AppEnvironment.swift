import Foundation
import SwiftData
import UserNotifications

@MainActor
final class AppEnvironment {
    var featureFlags: FeatureFlags
    let container: ModelContainer
    let modelContext: ModelContext
    let financeCalculator: FinanceCalculator
    let currencyFormatter: CurrencyFormatter
    let notificationScheduler: NotificationScheduling
    let sampleDataService: SampleDataService

    init(featureFlags: FeatureFlags = FeatureFlags(), configuration: ModelConfiguration? = nil) {
        self.featureFlags = featureFlags
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
}
