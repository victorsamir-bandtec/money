import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class SampleDataService {
    private let context: ModelContext
    private let financeCalculator: FinanceCalculator

    init(context: ModelContext, financeCalculator: FinanceCalculator) {
        self.context = context
        self.financeCalculator = financeCalculator
    }

    func populateIfNeeded() throws {
        let fetch = FetchDescriptor<Debtor>()
        let count = try context.fetch(fetch).count
        guard count == 0 else { return }
        try createScenarioMarlon()
        try context.save()
    }

    func createScenarioMarlon() throws {
        let marlon = Debtor(name: "Marlon")
        context.insert(marlon)

        let agreement = DebtAgreement(
            debtor: marlon,
            title: String(localized: "sample.marlon.title"),
            principal: Decimal(1500),
            startDate: Calendar.current.date(byAdding: .month, value: -2, to: .now) ?? .now,
            installmentCount: 12
        )
        context.insert(agreement)

        let specs = try financeCalculator.generateSchedule(
            principal: Decimal(1500),
            installments: 12,
            monthlyInterest: nil,
            firstDueDate: agreement.startDate
        )

        for spec in specs {
            let installment = Installment(
                agreement: agreement,
                number: spec.number,
                dueDate: spec.dueDate,
                amount: spec.amount
            )
            if spec.number <= 3 {
                installment.paidAmount = installment.amount
                installment.status = .paid
            }
            context.insert(installment)
        }

        let expense = FixedExpense(name: "Aluguel escritório", amount: Decimal(800), category: "Infra", dueDay: 5)
        context.insert(expense)

        let salary = SalarySnapshot(referenceMonth: Date(), amount: Decimal(4200))
        context.insert(salary)

        let calendar = Calendar.current
        let groceriesDate = calendar.date(byAdding: .day, value: -3, to: .now) ?? .now
        let transportDate = calendar.date(byAdding: .day, value: -1, to: .now) ?? .now
        let freelanceDate = calendar.date(byAdding: .day, value: -6, to: .now) ?? .now

        let groceries = CashTransaction(
            date: groceriesDate,
            amount: Decimal(120.50),
            type: .expense,
            category: "Mercado",
            note: String(localized: "sample.transaction.groceries")
        )
        context.insert(groceries)

        let transport = CashTransaction(
            date: transportDate,
            amount: Decimal(35),
            type: .expense,
            category: "Transporte",
            note: String(localized: "sample.transaction.transport")
        )
        context.insert(transport)

        let freelance = CashTransaction(
            date: freelanceDate,
            amount: Decimal(750),
            type: .income,
            category: "Freelancer",
            note: String(localized: "sample.transaction.freelance")
        )
        context.insert(freelance)
    }
}
