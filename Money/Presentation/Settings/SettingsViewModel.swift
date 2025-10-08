import Foundation
import SwiftData
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var notificationsEnabled: Bool
    @Published var salary: SalarySnapshot?
    @Published var salaryHistory: [SalarySnapshot] = []
    @Published var error: AppError?
    @Published var exportURL: URL?
    @Published var showingClearConfirmation = false

    private let environment: AppEnvironment
    private let calendar: Calendar

    init(environment: AppEnvironment, calendar: Calendar = .current) {
        self.environment = environment
        self.calendar = calendar
        self.notificationsEnabled = environment.featureFlags.enableNotifications
    }

    func load(referenceDate: Date = .now) {
        do {
            try fetchSalary(for: referenceDate)
            try fetchSalaryHistory(limit: 6)
        } catch {
            self.error = .persistence("error.generic")
        }
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
        guard amount >= 0 else {
            error = .validation("error.salary.invalid")
            return
        }

        let context = environment.modelContext
        let interval = calendar.dateInterval(of: .month, for: month) ?? DateInterval(start: month, end: month)
        let descriptor = FetchDescriptor<SalarySnapshot>(predicate: #Predicate { snapshot in
            snapshot.referenceMonth >= interval.start && snapshot.referenceMonth < interval.end
        })

        do {
            let snapshots = try context.fetch(descriptor)
            if let existing = snapshots.first {
                existing.amount = amount
                existing.referenceMonth = month
                existing.note = normalized(note)
                salary = existing
            } else {
                let snapshot = SalarySnapshot(referenceMonth: month, amount: amount, note: normalized(note))
                context.insert(snapshot)
                salary = snapshot
            }

            try context.save()
            refreshAfterSaving(month: month)
        } catch {
            context.rollback()
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
            NotificationCenter.default.postTransactionDataUpdates()
            load()
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    func clearAllData() {
        do {
            try environment.sampleDataService.clearAllData()
            NotificationCenter.default.postDataStoreCleared()
            load()
        } catch {
            self.error = .persistence("error.generic")
        }
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
        NotificationCenter.default.post(name: .financialDataDidChange, object: nil)
        load(referenceDate: month)
    }

    private func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
