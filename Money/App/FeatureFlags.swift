import Foundation

struct FeatureFlags: Sendable {
    var useLiquidGlass: Bool
    var useCloudSync: Bool
    var enableWidgets: Bool
    var enableNotifications: Bool

    init(
        useLiquidGlass: Bool = true,
        useCloudSync: Bool = false,
        enableWidgets: Bool = true,
        enableNotifications: Bool = true
    ) {
        self.useLiquidGlass = useLiquidGlass
        self.useCloudSync = useCloudSync
        self.enableWidgets = enableWidgets
        self.enableNotifications = enableNotifications
    }
}
