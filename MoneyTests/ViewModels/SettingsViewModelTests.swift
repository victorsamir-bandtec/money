import Foundation
import Testing
import SwiftData
@testable import Money

@MainActor
final class FeatureFlagsStoreSpy: FeatureFlagsStoring {
    private(set) var savedFlags: [FeatureFlags] = []
    var storedFlags: FeatureFlags

    init(initialFlags: FeatureFlags) {
        self.storedFlags = initialFlags
    }

    func load() -> FeatureFlags {
        storedFlags
    }

    func save(_ featureFlags: FeatureFlags) {
        savedFlags.append(featureFlags)
        storedFlags = featureFlags
    }
}

struct SettingsViewModelTests {
    @Test("Atualiza salário e histórico a partir de Ajustes") @MainActor
    func updatesSalary() throws {
        let environment = AppEnvironment(isStoredInMemoryOnly: true)
        let viewModel = SettingsViewModel(environment: environment)

        let calendar = Calendar.current
        let referenceMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()

        viewModel.load(referenceDate: referenceMonth)
        #expect(viewModel.salary == nil)

        viewModel.updateSalary(amount: 4200, month: referenceMonth, note: "Remoto")
        let currentSalary = try #require(viewModel.salary)
        #expect(currentSalary.amount == Decimal(4200))
        #expect(viewModel.salaryHistory.first?.amount == Decimal(4200))

        viewModel.updateSalary(amount: 4500, month: referenceMonth, note: nil)
        let updatedSalary = try #require(viewModel.salary)
        #expect(updatedSalary.amount == Decimal(4500))
        #expect(updatedSalary.note == nil)
        #expect(viewModel.salaryHistory.first?.amount == Decimal(4500))
    }

    @Test("Alterna alertas de vencimento sincronizando ambiente") @MainActor
    func togglesNotifications() throws {
        let store = FeatureFlagsStoreSpy(initialFlags: FeatureFlags(enableNotifications: false))
        let environment = AppEnvironment(featureFlagsStore: store, isStoredInMemoryOnly: true)
        let viewModel = SettingsViewModel(environment: environment)

        #expect(!viewModel.notificationsEnabled)

        viewModel.toggleNotifications(true)

        #expect(viewModel.notificationsEnabled)
        #expect(environment.featureFlags.enableNotifications)
        let persistedFlags = try #require(store.savedFlags.last)
        #expect(persistedFlags.enableNotifications)
        #expect(store.savedFlags.count == 1)
    }

    @Test("Exporta CSV com sucesso gerando URL") @MainActor
    func exportCSVGeneratesURL() throws {
        let schema = Schema([
            Debtor.self,
            DebtAgreement.self,
            Installment.self,
            Payment.self,
            FixedExpense.self,
            SalarySnapshot.self,
            CashTransaction.self
        ])
        let environment = AppEnvironment(isStoredInMemoryOnly: true)
        let viewModel = SettingsViewModel(environment: environment)

        // Criar alguns dados para exportar
        let context = environment.modelContext
        let debtor = Debtor(name: "Export Teste")!
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 2)!
        context.insert(agreement)
        try context.save()

        // Exportar
        #expect(viewModel.exportURL == nil)

        viewModel.exportCSV()

        // Verificar que URL foi gerada
        #expect(viewModel.exportURL != nil)

        if let url = viewModel.exportURL {
            // Verificar que é um arquivo ZIP
            #expect(url.pathExtension == "zip")

            // Verificar que arquivo existe
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test("Solicita permissao de notificacao quando concedida") @MainActor
    func requestNotificationPermissionWhenGrantedSucceeds() async throws {
        @MainActor
        final class NotificationSchedulerMock: NotificationScheduling {
            var authorizationGranted = true

            func requestAuthorization() async throws {
                if !authorizationGranted {
                    throw AppError.scheduling("error.notifications.denied")
                }
            }

            func scheduleReminder(for payload: InstallmentReminderPayload) async throws {}
            func cancelReminders(for agreementID: UUID) async {}
            func cancelReminders(for agreementID: UUID, installmentNumber: Int) async {}
        }

        let store = FeatureFlagsStoreSpy(initialFlags: FeatureFlags(enableNotifications: true))
        let scheduler = NotificationSchedulerMock()

        let environment = AppEnvironment(
            featureFlagsStore: store,
            notificationScheduler: scheduler,
            isStoredInMemoryOnly: true
        )
        let viewModel = SettingsViewModel(environment: environment)

        #expect(viewModel.error == nil)

        await viewModel.requestNotificationPermission()

        // Deve ter sucesso sem erro
        #expect(viewModel.error == nil)
    }

    @Test("Solicita permissao de notificacao quando negada define erro") @MainActor
    func requestNotificationPermissionWhenDeniedSetsError() async throws {
        @MainActor
        final class NotificationSchedulerMock: NotificationScheduling {
            var authorizationGranted = false

            func requestAuthorization() async throws {
                if !authorizationGranted {
                    throw AppError.scheduling("error.notifications.denied")
                }
            }

            func scheduleReminder(for payload: InstallmentReminderPayload) async throws {}
            func cancelReminders(for agreementID: UUID) async {}
            func cancelReminders(for agreementID: UUID, installmentNumber: Int) async {}
        }

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let store = FeatureFlagsStoreSpy(initialFlags: FeatureFlags(enableNotifications: true))
        let scheduler = NotificationSchedulerMock()

        let environment = AppEnvironment(
            featureFlagsStore: store,
            notificationScheduler: scheduler,
            isStoredInMemoryOnly: true
        )
        let viewModel = SettingsViewModel(environment: environment)

        #expect(viewModel.error == nil)

        await viewModel.requestNotificationPermission()

        // Deve ter erro
        #expect(viewModel.error != nil)
    }

    @Test("Altera tema e persiste") @MainActor
    func changesTheme() {
        let environment = AppEnvironment(isStoredInMemoryOnly: true)
        let viewModel = SettingsViewModel(environment: environment)
        
        // Reset defaults for test
        UserDefaults.standard.removeObject(forKey: "user_theme_preference")
        
        viewModel.setTheme(.dark)
        #expect(viewModel.currentTheme == .dark)
        #expect(UserDefaults.standard.integer(forKey: "user_theme_preference") == 2)
        
        viewModel.setTheme(.light)
        #expect(viewModel.currentTheme == .light)
        #expect(UserDefaults.standard.integer(forKey: "user_theme_preference") == 1)
    }
}
