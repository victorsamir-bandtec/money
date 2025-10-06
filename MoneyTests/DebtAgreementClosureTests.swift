import Foundation
import Testing
import SwiftData
@testable import Money

@MainActor
final class NotificationSchedulerSpy: NotificationScheduling {
    enum Action: Equatable {
        case schedule(agreementID: UUID, installment: Int)
        case cancel(agreementID: UUID)
    }

    private(set) var actions: [Action] = []

    func requestAuthorization() async throws {}

    func scheduleReminder(for payload: InstallmentReminderPayload) async throws {
        actions.append(.schedule(agreementID: payload.agreementID, installment: payload.installmentNumber))
    }

    func cancelReminders(for agreementID: UUID) async {
        actions.append(.cancel(agreementID: agreementID))
    }

    func reset() {
        actions.removeAll()
    }
}

struct DebtAgreementClosureTests {
    @Test("Encerra acordo ao quitar parcelas no detalhe do devedor") @MainActor
    func closesAgreementAfterMarkingInstallmentsPaid() async throws {
        let environment = try makeEnvironment()
        let scheduler = NotificationSchedulerSpy()
        let viewModel = DebtorDetailViewModel(
            debtor: environment.debtor,
            context: environment.context,
            calculator: FinanceCalculator(),
            notificationScheduler: scheduler
        )
        try viewModel.load()

        let firstInstallment = try #require(viewModel.installments.first)
        viewModel.mark(installment: firstInstallment, as: .paid)
        await viewModel.reminderSyncTaskForTesting?.value

        #expect(!environment.agreement.closed)
        #expect(scheduler.actions.contains(.schedule(agreementID: environment.agreement.id, installment: 2)))

        let refreshedSecond = try #require(viewModel.installments.last)
        viewModel.mark(installment: refreshedSecond, as: .paid)
        await viewModel.reminderSyncTaskForTesting?.value

        #expect(environment.agreement.closed)
        #expect(scheduler.actions.contains(.cancel(agreementID: environment.agreement.id)))
    }

    @Test("Reabre acordo ao marcar parcela como pendente") @MainActor
    func reopensAgreementWhenMarkingPending() async throws {
        let environment = try makeEnvironment()
        let scheduler = NotificationSchedulerSpy()
        let viewModel = DebtorDetailViewModel(
            debtor: environment.debtor,
            context: environment.context,
            calculator: FinanceCalculator(),
            notificationScheduler: scheduler
        )
        try viewModel.load()

        let first = try #require(viewModel.installments.first)
        let second = try #require(viewModel.installments.last)

        viewModel.mark(installment: first, as: .paid)
        await viewModel.reminderSyncTaskForTesting?.value
        viewModel.mark(installment: second, as: .paid)
        await viewModel.reminderSyncTaskForTesting?.value

        #expect(environment.agreement.closed)
        scheduler.reset()

        // Reabrir acordo marcando parcela como pendente
        let latestSecond = try #require(viewModel.installments.last)
        viewModel.mark(installment: latestSecond, as: .pending)
        await viewModel.reminderSyncTaskForTesting?.value

        #expect(!environment.agreement.closed)
        #expect(scheduler.actions.contains(.cancel(agreementID: environment.agreement.id)))
        #expect(scheduler.actions.contains(.schedule(agreementID: environment.agreement.id, installment: latestSecond.number)))
    }
}

@MainActor
private func makeEnvironment() throws -> (context: ModelContext, debtor: Debtor, agreement: DebtAgreement) {
    let schema = Schema([
        Debtor.self,
        DebtAgreement.self,
        Installment.self,
        Payment.self,
        FixedExpense.self,
        SalarySnapshot.self
    ])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: configuration)
    let context = container.mainContext

    let debtor = Debtor(name: "Cliente Teste")
    context.insert(debtor)

    let agreement = DebtAgreement(
        debtor: debtor,
        title: "Acordo",
        principal: 1200,
        startDate: Date(),
        installmentCount: 2
    )
    context.insert(agreement)

    let firstDue = Date().addingTimeInterval(7 * 24 * 60 * 60)
    let secondDue = Date().addingTimeInterval(37 * 24 * 60 * 60)

    let firstInstallment = Installment(agreement: agreement, number: 1, dueDate: firstDue, amount: 600)
    let secondInstallment = Installment(agreement: agreement, number: 2, dueDate: secondDue, amount: 600)
    context.insert(firstInstallment)
    context.insert(secondInstallment)

    try context.save()

    return (context, debtor, agreement)
}
