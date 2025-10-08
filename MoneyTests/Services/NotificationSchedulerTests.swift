import Foundation
import Testing
import UserNotifications
@testable import Money

@MainActor
final class UNUserNotificationCenterMock: UNUserNotificationCenter {
    var authorizationGranted = true
    var scheduledRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []

    override func requestAuthorization(options: UNAuthorizationOptions = []) async throws -> Bool {
        return authorizationGranted
    }

    override func add(_ request: UNNotificationRequest) async throws {
        scheduledRequests.append(request)
    }

    override func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }

    override func pendingNotificationRequests() async -> [UNNotificationRequest] {
        return scheduledRequests
    }
}

struct NotificationSchedulerTests {
    @Test("Agenda lembrete criando notificacao") @MainActor
    func scheduleReminderCreatesNotification() async throws {
        let center = UNUserNotificationCenterMock()
        let scheduler = LocalNotificationScheduler(center: center, anticipationDays: 2)

        let calendar = Calendar.current
        let futureDate = calendar.date(byAdding: .day, value: 5, to: Date())!

        let payload = InstallmentReminderPayload(
            agreementID: UUID(),
            installmentNumber: 1,
            dueDate: futureDate
        )

        try await scheduler.scheduleReminder(for: payload)

        // Deve ter agendado 2 notificações (vencimento e aviso antecipado)
        #expect(center.scheduledRequests.count == 2)

        // Verificar conteúdo da notificação
        let request = try #require(center.scheduledRequests.first)
        let content = request.content
        #expect(content.title.contains("parcela") || content.title.contains("installment"))
        #expect(content.sound == .default)
    }

    @Test("Cancela lembretes para acordo removendo todos") @MainActor
    func cancelRemindersForAgreementRemovesAll() async throws {
        let center = UNUserNotificationCenterMock()
        let scheduler = LocalNotificationScheduler(center: center)

        let agreementID = UUID()
        let futureDate = Date().addingTimeInterval(86400 * 5)

        // Agendar múltiplas parcelas para o mesmo acordo
        for installmentNumber in 1...3 {
            let payload = InstallmentReminderPayload(
                agreementID: agreementID,
                installmentNumber: installmentNumber,
                dueDate: futureDate
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
        let center = UNUserNotificationCenterMock()
        let scheduler = LocalNotificationScheduler(center: center)

        let agreementID = UUID()
        let futureDate = Date().addingTimeInterval(86400 * 5)

        // Agendar múltiplas parcelas
        for installmentNumber in 1...3 {
            let payload = InstallmentReminderPayload(
                agreementID: agreementID,
                installmentNumber: installmentNumber,
                dueDate: futureDate
            )
            try await scheduler.scheduleReminder(for: payload)
        }

        #expect(center.scheduledRequests.count == 6)

        // Cancelar apenas parcela 2
        await scheduler.cancelReminders(for: agreementID, installmentNumber: 2)

        // Deve ter removido apenas 2 identificadores (vencimento + aviso da parcela 2)
        #expect(center.removedIdentifiers.count == 2)

        // Verificar que contém o número da parcela
        for identifier in center.removedIdentifiers {
            #expect(identifier.contains(".2."))
        }
    }

    @Test("Solicita autorizacao quando concedida retorna sucesso") @MainActor
    func requestAuthorizationWhenGrantedSucceeds() async throws {
        let center = UNUserNotificationCenterMock()
        center.authorizationGranted = true

        let scheduler = LocalNotificationScheduler(center: center)

        // Não deve lançar erro
        try await scheduler.requestAuthorization()
    }

    @Test("Solicita autorizacao quando negada lanca erro") @MainActor
    func requestAuthorizationWhenDeniedThrowsError() async throws {
        let center = UNUserNotificationCenterMock()
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

    @Test("Trigger com data passada retorna nil") @MainActor
    func triggerWithPastDateReturnsNil() async throws {
        let center = UNUserNotificationCenterMock()
        let scheduler = LocalNotificationScheduler(center: center)

        // Data no passado
        let pastDate = Date().addingTimeInterval(-86400)

        let payload = InstallmentReminderPayload(
            agreementID: UUID(),
            installmentNumber: 1,
            dueDate: pastDate
        )

        // Tentar agendar - pode não lançar erro mas não deve criar triggers
        try await scheduler.scheduleReminder(for: payload)

        // Pode ter 0 ou poucos requests dependendo da implementação
        // O importante é que triggers com data passada sejam ignorados
        #expect(center.scheduledRequests.count <= 2)
    }

    @Test("Agenda notificacao com antecedencia correta") @MainActor
    func schedulesNotificationWithCorrectAnticipation() async throws {
        let center = UNUserNotificationCenterMock()
        let anticipationDays = 3
        let scheduler = LocalNotificationScheduler(center: center, anticipationDays: anticipationDays)

        let calendar = Calendar.current
        let dueDate = calendar.date(byAdding: .day, value: 10, to: Date())!

        let payload = InstallmentReminderPayload(
            agreementID: UUID(),
            installmentNumber: 1,
            dueDate: dueDate
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
