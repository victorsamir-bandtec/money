import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            DashboardScene(environment: environment, context: modelContext)
                .tabItem {
                    Label(String(localized: "tab.dashboard"), systemImage: "chart.bar.xaxis")
                }
            HistoricalAnalysisScene(environment: environment, context: modelContext)
                .tabItem {
                    Label(String(localized: "tab.analytics"), systemImage: "chart.xyaxis.line")
                }
            DebtorsScene(environment: environment, context: modelContext)
                .tabItem {
                    Label(String(localized: "tab.debtors"), systemImage: "person.3")
                }
            TransactionsScene(environment: environment, context: modelContext)
                .tabItem {
                    Label(String(localized: "tab.transactions"), systemImage: "list.bullet.rectangle")
                }
            SettingsScene(environment: environment)
                .tabItem {
                    Label(String(localized: "tab.settings"), systemImage: "gear")
                }
        }
        .tint(.appThemeColor)
    }
}
