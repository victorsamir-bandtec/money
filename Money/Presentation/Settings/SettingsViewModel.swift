import Foundation
import SwiftData
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var featureFlags: FeatureFlags
    @Published var isLoadingSampleData = false
    @Published var error: AppError?
    @Published var exportURL: URL?

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        self.featureFlags = environment.featureFlags
    }

    func toggleCloudSync(_ enabled: Bool) {
        featureFlags.useCloudSync = enabled
        environment.featureFlags.useCloudSync = enabled
    }

    func toggleLiquidGlass(_ enabled: Bool) {
        featureFlags.useLiquidGlass = enabled
        environment.featureFlags.useLiquidGlass = enabled
    }

    func toggleNotifications(_ enabled: Bool) {
        featureFlags.enableNotifications = enabled
        environment.featureFlags.enableNotifications = enabled
    }

    func requestNotificationPermission() async {
        guard environment.featureFlags.enableNotifications else { return }
        do {
            try await environment.notificationScheduler.requestAuthorization()
        } catch let error as AppError {
            self.error = error
        } catch {
            self.error = .scheduling("error.notifications.denied")
        }
    }

    func loadSampleDataIfNeeded() {
        Task {
            await populateSample()
        }
    }

    func populateSample() async {
        isLoadingSampleData = true
        defer { isLoadingSampleData = false }
        do {
            try await Task.sleep(nanoseconds: 200_000_000)
            try environment.sampleDataService.populateIfNeeded()
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    func exportCSV() {
        do {
            let url = try CSVExporter().export(from: environment.modelContext)
            exportURL = url
        } catch let error as AppError {
            self.error = error
        } catch {
            self.error = .persistence("error.generic")
        }
    }
}
