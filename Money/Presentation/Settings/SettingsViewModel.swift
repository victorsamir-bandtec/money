import Foundation
import SwiftData
import Combine
import SwiftUI

enum AppThemeOption: Int, CaseIterable, Identifiable {
    case system = 0
    case light = 1
    case dark = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .system: return "theme.system"
        case .light: return "theme.light"
        case .dark: return "theme.dark"
        }
    }

    var localizedLabel: String {
        NSLocalizedString(label, bundle: .main, comment: "")
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var notificationsEnabled: Bool
    @Published var salary: SalarySnapshot?
    @Published var salaryHistory: [SalarySnapshot] = []
    @Published var error: AppError?
    @Published var exportURL: URL?
    @Published var showingClearConfirmation = false
    @Published var currentTheme: AppThemeOption

    private let environment: AppEnvironment
    private let calendar: Calendar
    private let themeKey = "user_theme_preference"

    init(environment: AppEnvironment, calendar: Calendar = .current) {
        self.environment = environment
        self.calendar = calendar
        self.notificationsEnabled = environment.featureFlags.enableNotifications
        
        let savedTheme = UserDefaults.standard.integer(forKey: "user_theme_preference")
        self.currentTheme = AppThemeOption(rawValue: savedTheme) ?? .system
    }

    func load(referenceDate: Date = .now) {
        do {
            try fetchSalary(for: referenceDate)
            try fetchSalaryHistory(limit: 6)
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    func setTheme(_ theme: AppThemeOption) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
    }

    func toggleNotifications(_ enabled: Bool) {
        notificationsEnabled = enabled
        environment.featureFlags.enableNotifications = enabled
        environment.saveFeatureFlags()
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

    func updateSalary(amount: Decimal, month: Date, note: String?) {
        do {
            let snapshot = try environment.commandService.updateSalary(
                amount: amount,
                month: month,
                note: normalized(note),
                context: environment.modelContext,
                calendar: calendar
            )
            salary = snapshot
            refreshAfterSaving(month: month)
        } catch let appError as AppError {
            self.error = appError
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

    func populateSampleData() {
        do {
            try environment.sampleDataService.populateData()
            environment.bootstrapReadModels()
            Task {
                await environment.domainEventBus.publish(.debtorChanged)
                await environment.domainEventBus.publish(.agreementChanged)
                await environment.domainEventBus.publish(.paymentChanged)
                await environment.domainEventBus.publish(.salaryChanged)
                await environment.domainEventBus.publish(.transactionChanged)
            }
            NotificationCenter.default.postTransactionDataUpdates()
            load()
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    func clearAllData() {
        do {
            try environment.sampleDataService.clearAllData()
            environment.bootstrapReadModels()
            Task {
                await environment.domainEventBus.publish(.debtorChanged)
                await environment.domainEventBus.publish(.agreementChanged)
                await environment.domainEventBus.publish(.paymentChanged)
                await environment.domainEventBus.publish(.salaryChanged)
                await environment.domainEventBus.publish(.transactionChanged)
            }
            NotificationCenter.default.postDataStoreCleared()
            load()
        } catch {
            self.error = .persistence("error.generic")
        }
    }
    
    // MARK: - Support
    
    func openHelp() {
        // Placeholder URL
        openURL("https://example.com/help")
    }
    
    func rateApp() {
        // Placeholder App Store URL
        openURL("https://apps.apple.com/app/id123456789")
    }
    
    func openContact() {
        openURL("mailto:support@moneyapp.com")
    }
    
    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }

    private func fetchSalary(for month: Date) throws {
        let interval = calendar.dateInterval(of: .month, for: month) ?? DateInterval(start: month, end: month)
        let descriptor = FetchDescriptor<SalarySnapshot>(predicate: #Predicate { snapshot in
            snapshot.referenceMonth >= interval.start && snapshot.referenceMonth < interval.end
        })
        salary = try environment.modelContext.fetch(descriptor).first
    }

    private func fetchSalaryHistory(limit: Int) throws {
        var descriptor = FetchDescriptor<SalarySnapshot>(sortBy: [SortDescriptor(\.referenceMonth, order: .reverse)])
        descriptor.fetchLimit = limit
        salaryHistory = try environment.modelContext.fetch(descriptor)
    }

    private func refreshAfterSaving(month: Date) {
        load(referenceDate: month)
    }

    private func normalized(_ value: String?) -> String? {
        value.normalizedOrNil
    }
}
