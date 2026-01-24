import Foundation
import SwiftData

struct DebtService: Sendable {
    private let calculator: FinanceCalculator
    
    init(calculator: FinanceCalculator) {
        self.calculator = calculator
    }
    
    @MainActor
    func createAgreement(
        debtor: Debtor,
        title: String,
        principal: Decimal,
        startDate: Date,
        installmentCount: Int,
        currencyCode: String,
        interestRate: Decimal?, // Taxa já normalizada (0.01 = 1%) ou crua? 
                                // O FinanceCalculator espera normalizada. 
                                // O VM passava 'draft.interestRate.map { $0 / 100 }'.
                                // Vamos assumir que o Service recebe a taxa RAW (em porcentagem) e normaliza, 
                                // OU recebe normalizada. 
                                // Para evitar confusão, vamos nomear `monthlyInterestRatePercentage` se for %, 
                                // ou `monthlyInterestRate` se for fator.
                                // O ViewModel fazia `draft.interestRate` (que parecia ser %) / 100.
                                // Vamos receber `monthlyInterestRatePercentage` opcional.
        context: ModelContext
    ) throws -> DebtAgreement {
        let normalizedRate = interestRate.map { $0 / 100 }
        
        guard let agreement = DebtAgreement(
            debtor: debtor,
            title: title.normalizedOrNil,
            principal: principal,
            startDate: startDate,
            installmentCount: installmentCount,
            currencyCode: currencyCode,
            interestRateMonthly: normalizedRate
        ) else {
            throw AppError.validation("error.agreement.invalid")
        }
        context.insert(agreement)
        
        let schedule = try calculator.generateSchedule(
            principal: principal,
            installments: installmentCount,
            monthlyInterest: interestRate,
            firstDueDate: startDate
        )
        
        for spec in schedule {
            guard let installment = Installment(
                agreement: agreement,
                number: spec.number,
                dueDate: spec.dueDate,
                amount: spec.amount
            ) else {
                context.delete(agreement)
                throw AppError.validation("error.installment.invalid")
            }
            context.insert(installment)
        }
        
        return agreement
    }
}


