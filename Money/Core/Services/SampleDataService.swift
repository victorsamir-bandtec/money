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
    }
}
