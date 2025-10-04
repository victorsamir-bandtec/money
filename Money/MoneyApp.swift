import SwiftUI
import SwiftData
import Observation

@main
struct MoneyApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .appEnvironment(environment)
        }
        .modelContainer(environment.container)
    }
}
