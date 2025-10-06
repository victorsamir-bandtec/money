import Foundation

@MainActor
protocol FeatureFlagsStoring: AnyObject {
    func load() -> FeatureFlags
    func save(_ featureFlags: FeatureFlags)
}

@MainActor
final class FeatureFlagsStore: FeatureFlagsStoring {
    private enum Keys {
        static let enableNotifications = "featureFlags.enableNotifications"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> FeatureFlags {
        let storedValue = defaults.object(forKey: Keys.enableNotifications) as? Bool
        return FeatureFlags(enableNotifications: storedValue ?? true)
    }

    func save(_ featureFlags: FeatureFlags) {
        defaults.set(featureFlags.enableNotifications, forKey: Keys.enableNotifications)
    }
}
