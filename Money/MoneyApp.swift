import SwiftUI
import SwiftData
import Observation
import WidgetKit

@main
struct MoneyApp: App {
    @State private var environment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .appEnvironment(environment)
        }
        .modelContainer(environment.container)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Reload widgets when app becomes active
            if newPhase == .active {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
