import Foundation

struct FeatureFlags: Sendable {
    var enableNotifications: Bool

    nonisolated init(enableNotifications: Bool = true) {
        self.enableNotifications = enableNotifications
    }
}
