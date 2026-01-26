import Foundation
import UserNotifications

@MainActor
protocol NotificationScheduling: AnyObject {
    func requestAuthorization() async throws
    func scheduleReminder(for payload: InstallmentReminderPayload) async throws
    func cancelReminders(for agreementID: UUID) async
    func cancelReminders(for agreementID: UUID, installmentNumber: Int) async
}

@MainActor
protocol UserNotificationCentering: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func getPendingNotificationRequests(completionHandler: @escaping @Sendable ([UNNotificationRequest]) -> Void)
}

@MainActor
extension UNUserNotificationCenter: UserNotificationCentering {}

struct InstallmentReminderPayload: Sendable {
    let agreementID: UUID
    let installmentNumber: Int
    let dueDate: Date
    let remainingAmountFormatted: String
}

@MainActor
final class LocalNotificationScheduler: NotificationScheduling {
    private let center: UserNotificationCentering
    private let anticipationDays: Int

    init(center: UserNotificationCentering = UNUserNotificationCenter.current(), anticipationDays: Int = 2) {
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
        let identifiers = reminderIdentifiers(for: payload.agreementID, installmentNumber: payload.installmentNumber)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let isOverdue = payload.dueDate < startOfToday

        let content = UNMutableNotificationContent()
        if isOverdue {
            content.title = String(localized: "notification.installment.overdue.title", bundle: .appModule)
            let bodyTemplate = String(localized: "notification.installment.overdue.body", bundle: .appModule)
            content.body = String(
                format: bodyTemplate,
                locale: Locale.current,
                Int64(payload.installmentNumber),
                payload.remainingAmountFormatted
            )
        } else {
            content.title = String(localized: "notification.installment.title", bundle: .appModule)
            let bodyTemplate = String(localized: "notification.installment.body", bundle: .appModule)
            content.body = String(
                format: bodyTemplate,
                locale: Locale.current,
                Int64(payload.installmentNumber),
                payload.remainingAmountFormatted
            )
        }
        content.sound = .default

        if isOverdue {
            let trigger = overdueTrigger(for: payload.dueDate)
            let request = UNNotificationRequest(identifier: identifiers[2], content: content, trigger: trigger)
            try await center.add(request)
            return
        }

        let dueTrigger = trigger(for: payload.dueDate, daysOffset: 0)
        let warnTrigger = trigger(for: payload.dueDate, daysOffset: -anticipationDays)

        if let dueTrigger {
            let request = UNNotificationRequest(identifier: identifiers[0], content: content, trigger: dueTrigger)
            try await center.add(request)
        }
        if let warnTrigger {
            let warnContent = (content.mutableCopy() as? UNMutableNotificationContent) ?? {
                let fallback = UNMutableNotificationContent()
                fallback.title = content.title
                fallback.body = content.body
                fallback.sound = content.sound
                return fallback
            }()
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

    func cancelReminders(for agreementID: UUID, installmentNumber: Int) async {
        let identifiers = reminderIdentifiers(for: agreementID, installmentNumber: installmentNumber)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func identifier(agreementID: UUID, number: Int, type: String) -> String {
        "money.installment.\(agreementID.uuidString).\(number).\(type)"
    }

    private func reminderIdentifiers(for agreementID: UUID, installmentNumber: Int) -> [String] {
        [
            identifier(agreementID: agreementID, number: installmentNumber, type: "due"),
            identifier(agreementID: agreementID, number: installmentNumber, type: "warn"),
            identifier(agreementID: agreementID, number: installmentNumber, type: "overdue"),
        ]
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
        guard let triggerDate = calendar.date(from: components), triggerDate >= Date() else { return nil }
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private func overdueTrigger(for date: Date) -> UNCalendarNotificationTrigger {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = calendar.component(.weekday, from: date)
        components.hour = 9
        components.minute = 0
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    }

    private func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}

@MainActor
extension NotificationScheduling {
    func cancelReminders(for agreementID: UUID, installmentNumber: Int) async {
        await cancelReminders(for: agreementID)
    }

    func syncReminders(for installment: Installment) async {
        let formatter = CurrencyFormatter(locale: Locale.current, currencyCode: installment.agreement.currencyCode)
        let payload = InstallmentReminderPayload(
            agreementID: installment.agreement.id,
            installmentNumber: installment.number,
            dueDate: installment.dueDate,
            remainingAmountFormatted: formatter.string(from: installment.remainingAmount)
        )

        if installment.status == .paid || installment.remainingAmount == .zero {
            await cancelReminders(for: payload.agreementID, installmentNumber: payload.installmentNumber)
            return
        }

        try? await scheduleReminder(for: payload)
    }
}
