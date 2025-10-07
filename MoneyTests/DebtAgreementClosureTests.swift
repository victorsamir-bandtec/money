import Foundation
import Testing
import SwiftData
@testable import Money

@MainActor
final class NotificationSchedulerSpy: NotificationScheduling {
    enum Action: Equatable {
        case schedule(agreementID: UUID, installment: Int)
        case cancelAgreement(agreementID: UUID)
        case cancelInstallment(agreementID: UUID, installment: Int)
    }

    private(set) var actions: [Action] = []

    func requestAuthorization() async throws {}

    func scheduleReminder(for payload: InstallmentReminderPayload) async throws {
        actions.append(.schedule(agreementID: payload.agreementID, installment: payload.installmentNumber))
    }

    func cancelReminders(for agreementID: UUID) async {
        actions.append(.cancelAgreement(agreementID: agreementID))
    }

    func cancelReminders(for agreementID: UUID, installmentNumber: Int) async {
        actions.append(.cancelInstallment(agreementID: agreementID, installment: installmentNumber))
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
        #expect(scheduler.actions.contains(.cancelAgreement(agreementID: environment.agreement.id)))
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
        #expect(scheduler.actions.contains(.cancelAgreement(agreementID: environment.agreement.id)))
        #expect(scheduler.actions.contains(.schedule(agreementID: environment.agreement.id, installment: latestSecond.number)))
    }
}

struct InstallmentReminderSchedulingTests {
    @Test("Não reagenda lembretes para parcela quitada") @MainActor
    func doesNotScheduleWhenInstallmentPaid() async throws {
        let environment = try makeEnvironment()
        let scheduler = NotificationSchedulerSpy()
        let installment = try #require(environment.agreement.installments.first)

        installment.paidAmount = installment.amount
        installment.status = .paid

        await scheduler.syncReminders(for: installment)

        #expect(!scheduler.actions.contains(where: { action in
            if case .schedule = action { return true }
            return false
        }))
        #expect(scheduler.actions.contains(.cancelInstallment(agreementID: environment.agreement.id, installment: installment.number)))
    }

    @Test("Não reagenda lembretes para parcela sem saldo restante") @MainActor
    func doesNotScheduleWhenRemainingAmountIsZero() async throws {
        let environment = try makeEnvironment()
        let scheduler = NotificationSchedulerSpy()
        let installment = try #require(environment.agreement.installments.first)

        installment.status = .partial
        installment.paidAmount = installment.amount

        await scheduler.syncReminders(for: installment)

        #expect(!scheduler.actions.contains(where: { action in
            if case .schedule = action { return true }
            return false
        }))
        #expect(scheduler.actions.contains(.cancelInstallment(agreementID: environment.agreement.id, installment: installment.number)))
    }

    @Test("Não agenda lembretes para parcelas vencidas") @MainActor
    func doesNotScheduleWhenDueDateIsInThePast() async throws {
        let environment = try makeEnvironment()
        let scheduler = NotificationSchedulerSpy()
        let installment = try #require(environment.agreement.installments.first)

        installment.status = .pending
        installment.dueDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date().addingTimeInterval(-86_400)

        await scheduler.syncReminders(for: installment)

        #expect(!scheduler.actions.contains(where: { action in
            if case .schedule = action { return true }
            return false
        }))
        #expect(scheduler.actions.contains(.cancelInstallment(agreementID: environment.agreement.id, installment: installment.number)))
    }

    @Test("Agenda lembretes para parcelas pendentes futuras") @MainActor
    func schedulesForPendingUpcomingInstallments() async throws {
        let environment = try makeEnvironment()
        let scheduler = NotificationSchedulerSpy()
        let installment = try #require(environment.agreement.installments.first)

        installment.status = .pending
        installment.paidAmount = .zero
        installment.dueDate = Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date().addingTimeInterval(5 * 86_400)

        await scheduler.syncReminders(for: installment)

        #expect(scheduler.actions.contains(.schedule(agreementID: environment.agreement.id, installment: installment.number)))
        #expect(!scheduler.actions.contains(.cancelInstallment(agreementID: environment.agreement.id, installment: installment.number)))
    }
}

struct DebtorDeletionTests {
    @Test("Exclui devedor e acordos associados") @MainActor
    func deletesDebtorAndCascadeAgreements() async throws {
        let environment = try makeEnvironment()
        let viewModel = DebtorsListViewModel(context: environment.context)

        try viewModel.load()
        #expect(viewModel.debtors.count == 1)

        viewModel.deleteDebtor(environment.debtor)
        try viewModel.load()

        let remainingDebtors = try environment.context.fetch(FetchDescriptor<Debtor>())
        let remainingAgreements = try environment.context.fetch(FetchDescriptor<DebtAgreement>())
        let remainingInstallments = try environment.context.fetch(FetchDescriptor<Installment>())

        #expect(viewModel.debtors.isEmpty)
        #expect(remainingDebtors.isEmpty)
        #expect(remainingAgreements.isEmpty)
        #expect(remainingInstallments.isEmpty)
    }
}

struct AgreementDeletionTests {
    @Test("Exclui acordo e cancela lembretes pendentes") @MainActor
    func deletesAgreementAndCancelsReminders() async throws {
        let environment = try makeEnvironment()
        let scheduler = NotificationSchedulerSpy()
        let viewModel = DebtorDetailViewModel(
            debtor: environment.debtor,
            context: environment.context,
            calculator: FinanceCalculator(),
            notificationScheduler: scheduler
        )

        try viewModel.load()

        let agreement = try #require(viewModel.agreements.first)
        let agreementID = agreement.id

        viewModel.deleteAgreement(agreement)
#if DEBUG
        await viewModel.reminderSyncTaskForTesting?.value
#endif

        let remainingAgreements = try environment.context.fetch(FetchDescriptor<DebtAgreement>())
        let remainingInstallments = try environment.context.fetch(FetchDescriptor<Installment>())

        #expect(viewModel.agreements.isEmpty)
        #expect(remainingAgreements.isEmpty)
        #expect(remainingInstallments.isEmpty)
        #expect(scheduler.actions.contains(.cancelAgreement(agreementID: agreementID)))
    }
}

@MainActor
private func makeEnvironment() throws -> (context: ModelContext, debtor: Debtor, agreement: DebtAgreement) {
    let schema = Schema([
        Debtor.self,
        DebtAgreement.self,
        Installment.self,
        Payment.self,
        CashTransaction.self,
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
