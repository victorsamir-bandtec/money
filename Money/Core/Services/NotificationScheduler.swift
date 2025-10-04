import Foundation
import UserNotifications

@MainActor
protocol NotificationScheduling: AnyObject {
    func requestAuthorization() async throws
    func scheduleReminder(for payload: InstallmentReminderPayload) async throws
    func cancelReminders(for agreementID: UUID) async
}

struct InstallmentReminderPayload: Sendable {
    let agreementID: UUID
    let installmentNumber: Int
    let dueDate: Date
}

@MainActor
final class LocalNotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter
    private let anticipationDays: Int

    init(center: UNUserNotificationCenter, anticipationDays: Int = 2) {
        self.center = center
        self.anticipationDays = anticipationDays
    }

    func requestAuthorization() async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        if !granted {
            throw AppError.scheduling("error.notifications.denied")
        }
    }

    func scheduleReminder(for payload: InstallmentReminderPayload) async throws {
        let identifiers = [
            identifier(agreementID: payload.agreementID, number: payload.installmentNumber, type: "due"),
            identifier(agreementID: payload.agreementID, number: payload.installmentNumber, type: "warn")
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.installment.title", bundle: .appModule)
        let bodyTemplate = String(localized: "notification.installment.body", bundle: .appModule)
        content.body = String(format: bodyTemplate, locale: Locale.current, payload.installmentNumber)
        content.sound = .default

        let dueTrigger = trigger(for: payload.dueDate, daysOffset: 0)
        let warnTrigger = trigger(for: payload.dueDate, daysOffset: -anticipationDays)

        if let dueTrigger {
            let request = UNNotificationRequest(identifier: identifiers[0], content: content, trigger: dueTrigger)
            try await center.add(request)
        }
        if let warnTrigger {
            let warnContent = content.copy() as! UNMutableNotificationContent
            warnContent.subtitle = String(localized: "notification.installment.subtitle", bundle: .appModule)
            let request = UNNotificationRequest(identifier: identifiers[1], content: warnContent, trigger: warnTrigger)
            try await center.add(request)
        }
    }

    func cancelReminders(for agreementID: UUID) async {
        let pattern = identifierPrefix(for: agreementID)
        let all = await pendingRequests()
        let ids = all.compactMap { request -> String? in
            request.identifier.hasPrefix(pattern) ? request.identifier : nil
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func identifier(agreementID: UUID, number: Int, type: String) -> String {
        "money.installment.\(agreementID.uuidString).\(number).\(type)"
    }

    private func identifierPrefix(for agreementID: UUID) -> String {
        "money.installment.\(agreementID.uuidString)."
    }

    private func trigger(for date: Date, daysOffset: Int) -> UNCalendarNotificationTrigger? {
        let calendar = Calendar.current
        guard let target = calendar.date(byAdding: .day, value: daysOffset, to: date) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: target)
        components.hour = 9
        components.minute = 0
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}
