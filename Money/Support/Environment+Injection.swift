import SwiftUI
import Observation

private struct AppEnvironmentKey: EnvironmentKey {
    @MainActor static var defaultValue: AppEnvironment { AppEnvironment() }
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

extension View {
    func appEnvironment(_ environment: AppEnvironment) -> some View {
        self.environment(\.appEnvironment, environment)
    }
}
