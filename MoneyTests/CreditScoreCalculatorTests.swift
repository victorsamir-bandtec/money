import Foundation
import Testing
import SwiftData
@testable import Money

@Suite("CreditScoreCalculator Tests")
struct CreditScoreCalculatorTests {
    @MainActor
    @Test("Score neutro para devedor sem histórico")
    func testNoHistory() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Schema([Debtor.self, DebtAgreement.self, Installment.self, Payment.self, DebtorCreditProfile.self]),
            configurations: config
        )
        let context = container.mainContext

        let debtor = Debtor(name: "Test User")!
        context.insert(debtor)
        try context.save()

        let calculator = CreditScoreCalculator()
        let profile = try calculator.calculateProfile(for: debtor, context: context)

        #expect(profile.score == 50)
        #expect(profile.riskLevel == .medium)
        #expect(profile.totalAgreements == 0)
    }

    @MainActor
    @Test("Score alto para devedor com 100% pontualidade")
    func testPerfectScore() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Schema([Debtor.self, DebtAgreement.self, Installment.self, Payment.self, DebtorCreditProfile.self]),
            configurations: config
        )
        let context = container.mainContext

        let debtor = Debtor(name: "Perfect Payer")!
        context.insert(debtor)

        let agreement = DebtAgreement(
            debtor: debtor,
            principal: 1000,
            startDate: Calendar.current.date(byAdding: .month, value: -3, to: .now)!,
            installmentCount: 3
        )!
        context.insert(agreement)

        let installmentAmount = Decimal(1000) / 3
        for i in 1...3 {
            let dueDate = Calendar.current.date(byAdding: .month, value: i - 4, to: .now)!
            let installment = Installment(
                agreement: agreement,
                number: i,
                dueDate: dueDate,
                amount: installmentAmount.rounded(2),
                paidAmount: installmentAmount.rounded(2),
                status: .paid
            )!
            context.insert(installment)

            let payment = Payment(
                installment: installment,
                date: dueDate,
                amount: installmentAmount.rounded(2),
                method: .pix
            )!
            context.insert(payment)
            installment.payments.append(payment)
        }

        try context.save()

        let calculator = CreditScoreCalculator()
        let profile = try calculator.calculateProfile(for: debtor, context: context)

        #expect(profile.score >= 75)
        #expect(profile.riskLevel == .low)
        #expect(profile.paidOnTimeCount == 3)
        #expect(profile.paidLateCount == 0)
    }

    @MainActor
    @Test("Score baixo para devedor com muitos atrasos")
    func testLowScore() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Schema([Debtor.self, DebtAgreement.self, Installment.self, Payment.self, DebtorCreditProfile.self]),
            configurations: config
        )
        let context = container.mainContext

        let debtor = Debtor(name: "Late Payer")!
        context.insert(debtor)

        let agreement = DebtAgreement(
            debtor: debtor,
            principal: 1000,
            startDate: Calendar.current.date(byAdding: .month, value: -3, to: .now)!,
            installmentCount: 3
        )!
        context.insert(agreement)

        let installmentAmount = Decimal(1000) / 3
        for i in 1...3 {
            let dueDate = Calendar.current.date(byAdding: .month, value: i - 4, to: .now)!
            let paymentDate = Calendar.current.date(byAdding: .day, value: 30, to: dueDate)!
            let installment = Installment(
                agreement: agreement,
                number: i,
                dueDate: dueDate,
                amount: installmentAmount.rounded(2),
                paidAmount: installmentAmount.rounded(2),
                status: .paid
            )!
            context.insert(installment)

            let payment = Payment(
                installment: installment,
                date: paymentDate,
                amount: installmentAmount.rounded(2),
                method: .pix
            )!
            context.insert(payment)
            installment.payments.append(payment)
        }

        try context.save()

        let calculator = CreditScoreCalculator()
        let profile = try calculator.calculateProfile(for: debtor, context: context)

        #expect(profile.score < 50)
        #expect(profile.paidOnTimeCount == 0)
        #expect(profile.paidLateCount == 3)
        #expect(profile.averageDaysLate == 30.0)
    }

    @MainActor
    @Test("Bônus por streak de pagamentos pontuais")
    func testStreakBonus() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Schema([Debtor.self, DebtAgreement.self, Installment.self, Payment.self, DebtorCreditProfile.self]),
            configurations: config
        )
        let context = container.mainContext

        let debtor = Debtor(name: "Streak Payer")!
        context.insert(debtor)

        let agreement = DebtAgreement(
            debtor: debtor,
            principal: 1000,
            startDate: Calendar.current.date(byAdding: .month, value: -5, to: .now)!,
            installmentCount: 5
        )!
        context.insert(agreement)

        let installmentAmount = Decimal(1000) / 5
        for i in 1...5 {
            let dueDate = Calendar.current.date(byAdding: .month, value: i - 6, to: .now)!
            let installment = Installment(
                agreement: agreement,
                number: i,
                dueDate: dueDate,
                amount: installmentAmount.rounded(2),
                paidAmount: installmentAmount.rounded(2),
                status: .paid
            )!
            context.insert(installment)

            let payment = Payment(
                installment: installment,
                date: dueDate,
                amount: installmentAmount.rounded(2),
                method: .pix
            )!
            context.insert(payment)
            installment.payments.append(payment)
        }

        try context.save()

        let calculator = CreditScoreCalculator()
        let profile = try calculator.calculateProfile(for: debtor, context: context)

        #expect(profile.consecutiveOnTimePayments == 5)
        #expect(profile.score >= 80)
    }
}