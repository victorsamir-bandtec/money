import Foundation
import Testing
import SwiftData
@testable import Money

struct DebtorDetailViewModelTests {
    @Test("Persiste acordos normalizando juros percentuais") @MainActor
    func createsAgreementWithNormalizedInterest() throws {
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

        let debtor = Debtor(name: "Ana")
        context.insert(debtor)

        let calculator = FinanceCalculator()
        let debtService = DebtService(calculator: calculator)
        let viewModel = DebtorDetailViewModel(
            debtor: debtor,
            context: context,
            calculator: calculator,
            debtService: debtService,
            notificationScheduler: nil
        )

        var draft = AgreementDraft()
        draft.title = "Teste"
        draft.principal = 1000
        draft.installmentCount = 12
        draft.startDate = Date(timeIntervalSince1970: 0)
        draft.interestRate = 2 // 2%

        viewModel.createAgreement(from: draft)
        let agreements = try context.fetch(FetchDescriptor<DebtAgreement>())
        let agreement = try #require(agreements.first)
        let storedRate = agreement.interestRateMonthly
        #expect(storedRate == Decimal(string: "0.02"), "storedRate=\(storedRate as Any)")
    }

    @Test("Emite notificações ao criar acordo") @MainActor
    func postsNotificationsAfterCreatingAgreement() throws {
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

        let debtor = Debtor(name: "Ana")
        context.insert(debtor)

        let calculator = FinanceCalculator()
        let debtService = DebtService(calculator: calculator)
        let viewModel = DebtorDetailViewModel(
            debtor: debtor,
            context: context,
            calculator: calculator,
            debtService: debtService,
            notificationScheduler: nil
        )

        var draft = AgreementDraft()
        draft.title = "Teste"
        draft.principal = 1000
        draft.installmentCount = 12
        draft.startDate = Date(timeIntervalSince1970: 0)

        var recorded: [Notification.Name: Int] = [:]
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .agreementDataDidChange,
            .paymentDataDidChange,
            .financialDataDidChange
        ]
        let tokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: nil) { _ in
                recorded[name, default: 0] += 1
            }
        }
        defer { tokens.forEach(center.removeObserver) }

        viewModel.createAgreement(from: draft)

        #expect(recorded[.agreementDataDidChange] == 1)
        #expect(recorded[.paymentDataDidChange] == 1)
        #expect(recorded[.financialDataDidChange] == 1)
    }

    @Test("Deleta acordo e cancela notificações") @MainActor
    func deletesAgreementAndCancelsNotifications() async throws {
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

        let debtor = Debtor(name: "Teste")
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 2)
        context.insert(agreement)

        let installment1 = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 500)
        let installment2 = Installment(agreement: agreement, number: 2, dueDate: .now, amount: 500)
        context.insert(installment1)
        context.insert(installment2)
        try context.save()

        let scheduler = NotificationSchedulerSpy()
        let calculator = FinanceCalculator()
        let debtService = DebtService(calculator: calculator)
        let viewModel = DebtorDetailViewModel(
            debtor: debtor,
            context: context,
            calculator: calculator,
            debtService: debtService,
            notificationScheduler: scheduler
        )

        try viewModel.load()
        #expect(viewModel.agreements.count == 1)

        let agreementID = agreement.id
        viewModel.deleteAgreement(agreement)

#if DEBUG
        await viewModel.reminderSyncTaskForTesting?.value
#endif

        try viewModel.load()
        #expect(viewModel.agreements.isEmpty)
        #expect(scheduler.actions.contains(.cancelAgreement(agreementID: agreementID)))
    }

    @Test("Marca parcela como paga e atualiza métricas") @MainActor
    func markInstallmentAsPaidUpdatesMetrics() async throws {
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

        let debtor = Debtor(name: "Teste")
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 2)
        context.insert(agreement)

        let installment1 = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 500)
        let installment2 = Installment(agreement: agreement, number: 2, dueDate: .now, amount: 500)
        context.insert(installment1)
        context.insert(installment2)
        try context.save()

        let calculator = FinanceCalculator()
        let debtService = DebtService(calculator: calculator)
        let viewModel = DebtorDetailViewModel(
            debtor: debtor,
            context: context,
            calculator: calculator,
            debtService: debtService,
            notificationScheduler: nil
        )

        try viewModel.load()
        #expect(viewModel.totalAgreementsValue == Decimal(1000))
        #expect(viewModel.totalPaid == Decimal(0))
        #expect(viewModel.totalRemaining == Decimal(1000))

        viewModel.mark(installment: installment1, as: .paid)

        try viewModel.load()
        #expect(installment1.status == .paid)
        #expect(installment1.paidAmount == Decimal(500))
        #expect(viewModel.totalPaid == Decimal(500))
        #expect(viewModel.totalRemaining == Decimal(500))
        #expect(!agreement.closed)
    }

    @Test("Calcula overview de acordo corretamente") @MainActor
    func calculatesAgreementOverviewCorrectly() throws {
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

        let debtor = Debtor(name: "Teste")
        context.insert(debtor)

        let agreement = DebtAgreement(debtor: debtor, principal: 1200, startDate: .now, installmentCount: 3)
        context.insert(agreement)

        let installment1 = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 400, paidAmount: 400, status: .paid)
        let installment2 = Installment(agreement: agreement, number: 2, dueDate: .now, amount: 400, paidAmount: 200, status: .partial)
        let installment3 = Installment(agreement: agreement, number: 3, dueDate: .now, amount: 400)
        context.insert(installment1)
        context.insert(installment2)
        context.insert(installment3)
        try context.save()

        let calculator = FinanceCalculator()
        let debtService = DebtService(calculator: calculator)
        let viewModel = DebtorDetailViewModel(
            debtor: debtor,
            context: context,
            calculator: calculator,
            debtService: debtService,
            notificationScheduler: nil
        )

        try viewModel.load()
        let overview = viewModel.overview(for: agreement)

        #expect(overview.totalInstallments == 3)
        #expect(overview.paidInstallments == 1)
        #expect(overview.openInstallments == 2)
        #expect(overview.totalAmount == Decimal(1200))
        #expect(overview.paidAmount == Decimal(600))
        #expect(overview.remainingAmount == Decimal(600))
        #expect(!overview.isClosed)
    }
}
