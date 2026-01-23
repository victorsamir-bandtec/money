import Foundation
import Testing
import UserNotifications
@testable import Money

@MainActor
final class UserNotificationCenterMock: UserNotificationCentering {
    var authorizationGranted = true
    var scheduledRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []

    func requestAuthorization(options: UNAuthorizationOptions = []) async throws -> Bool {
        return authorizationGranted
    }

    func add(_ request: UNNotificationRequest) async throws {
        scheduledRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }

    func getPendingNotificationRequests(completionHandler: @escaping ([UNNotificationRequest]) -> Void) {
        completionHandler(scheduledRequests)
    }
}

struct NotificationSchedulerTests {
    @Test("Agenda lembrete criando notificacao") @MainActor
    func scheduleReminderCreatesNotification() async throws {
        let center = UserNotificationCenterMock()
        let scheduler = LocalNotificationScheduler(center: center, anticipationDays: 2)

        let calendar = Calendar.current
        let futureDate = calendar.date(byAdding: .day, value: 5, to: Date())!
        let remainingAmount = "R$ 120,00"

        let payload = InstallmentReminderPayload(
            agreementID: UUID(),
            installmentNumber: 1,
            dueDate: futureDate,
            remainingAmountFormatted: remainingAmount
        )

        try await scheduler.scheduleReminder(for: payload)

        // Deve ter agendado 2 notificações (vencimento e aviso antecipado)
        #expect(center.scheduledRequests.count == 2)

        // Verificar conteúdo da notificação
        let request = try #require(center.scheduledRequests.first)
        let content = request.content
        #expect(content.title.contains("parcela") || content.title.contains("installment"))
        #expect(content.body.contains(remainingAmount))
        #expect(content.sound == .default)
    }

    @Test("Agenda lembrete semanal para parcela vencida") @MainActor
    func scheduleOverdueReminderCreatesWeeklyNotification() async throws {
        let center = UserNotificationCenterMock()
        let scheduler = LocalNotificationScheduler(center: center)

        let calendar = Calendar.current
        let pastDate = calendar.date(byAdding: .day, value: -10, to: Date())!
        let remainingAmount = "R$ 50,00"

        let payload = InstallmentReminderPayload(
            agreementID: UUID(),
            installmentNumber: 2,
            dueDate: pastDate,
            remainingAmountFormatted: remainingAmount
        )

        try await scheduler.scheduleReminder(for: payload)

        #expect(center.scheduledRequests.count == 1)

        let request = try #require(center.scheduledRequests.first)
        #expect(request.identifier.contains(".overdue"))
        #expect(request.content.body.contains(remainingAmount))

        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
    }

    @Test("Cancela lembretes para acordo removendo todos") @MainActor
    func cancelRemindersForAgreementRemovesAll() async throws {
        let center = UserNotificationCenterMock()
        let scheduler = LocalNotificationScheduler(center: center)

        let agreementID = UUID()
        let futureDate = Date().addingTimeInterval(86400 * 5)
        let remainingAmount = "R$ 10,00"

        // Agendar múltiplas parcelas para o mesmo acordo
        for installmentNumber in 1...3 {
            let payload = InstallmentReminderPayload(
                agreementID: agreementID,
                installmentNumber: installmentNumber,
                dueDate: futureDate,
                remainingAmountFormatted: remainingAmount
            )
            try await scheduler.scheduleReminder(for: payload)
        }

        #expect(center.scheduledRequests.count == 6) // 3 parcelas × 2 notificações cada

        // Cancelar todos os lembretes do acordo
        await scheduler.cancelReminders(for: agreementID)

        // Deve ter removido 6 identificadores
        #expect(center.removedIdentifiers.count == 6)

        // Verificar que os identificadores contêm o UUID do acordo
        let agreementUUIDString = agreementID.uuidString
        for identifier in center.removedIdentifiers {
            #expect(identifier.contains(agreementUUIDString))
        }
    }

    @Test("Cancela lembretes para parcela especifica removendo apenas dela") @MainActor
    func cancelRemindersForInstallmentRemovesSpecific() async throws {
        let center = UserNotificationCenterMock()
        let scheduler = LocalNotificationScheduler(center: center)

        let agreementID = UUID()
        let futureDate = Date().addingTimeInterval(86400 * 5)
        let remainingAmount = "R$ 10,00"

        // Agendar múltiplas parcelas
        for installmentNumber in 1...3 {
            let payload = InstallmentReminderPayload(
                agreementID: agreementID,
                installmentNumber: installmentNumber,
                dueDate: futureDate,
                remainingAmountFormatted: remainingAmount
            )
            try await scheduler.scheduleReminder(for: payload)
        }

        #expect(center.scheduledRequests.count == 6)

        // Cancelar apenas parcela 2
        await scheduler.cancelReminders(for: agreementID, installmentNumber: 2)

        // Deve ter removido identificadores da parcela 2 (vencimento + aviso + vencida)
        #expect(center.removedIdentifiers.count == 3)

        // Verificar que contém o número da parcela
        for identifier in center.removedIdentifiers {
            #expect(identifier.contains(".2."))
        }
    }

    @Test("Solicita autorizacao quando concedida retorna sucesso") @MainActor
    func requestAuthorizationWhenGrantedSucceeds() async throws {
        let center = UserNotificationCenterMock()
        center.authorizationGranted = true

        let scheduler = LocalNotificationScheduler(center: center)

        // Não deve lançar erro
        try await scheduler.requestAuthorization()
    }

    @Test("Solicita autorizacao quando negada lanca erro") @MainActor
    func requestAuthorizationWhenDeniedThrowsError() async throws {
        let center = UserNotificationCenterMock()
        center.authorizationGranted = false

        let scheduler = LocalNotificationScheduler(center: center)

        // Deve lançar erro do tipo AppError.scheduling
        var errorThrown = false
        do {
            try await scheduler.requestAuthorization()
        } catch let error as AppError {
            if case .scheduling = error {
                errorThrown = true
            }
        }

        #expect(errorThrown)
    }

    @Test("Agenda notificacao com antecedencia correta") @MainActor
    func schedulesNotificationWithCorrectAnticipation() async throws {
        let center = UserNotificationCenterMock()
        let anticipationDays = 3
        let scheduler = LocalNotificationScheduler(center: center, anticipationDays: anticipationDays)

        let calendar = Calendar.current
        let dueDate = calendar.date(byAdding: .day, value: 10, to: Date())!
        let remainingAmount = "R$ 10,00"

        let payload = InstallmentReminderPayload(
            agreementID: UUID(),
            installmentNumber: 1,
            dueDate: dueDate,
            remainingAmountFormatted: remainingAmount
        )

        try await scheduler.scheduleReminder(for: payload)

        // Deve ter 2 notificações agendadas
        #expect(center.scheduledRequests.count == 2)

        // Verificar identificadores
        let identifiers = center.scheduledRequests.map { $0.identifier }
        #expect(identifiers.contains { $0.contains(".due") })
        #expect(identifiers.contains { $0.contains(".warn") })
    }
}
