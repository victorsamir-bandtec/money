import Testing
@testable import Money
import Foundation

@Suite("Model Stability Tests")
struct ModelStabilityTests {
    
    // NOTE: These tests are commented out because the current implementation uses preconditions
    // which cause fatal crashes. We will enable them as we refactor the models to use failable initializers.
    
    /*
    @Test("Debtor initialization fails with empty name")
    func debtorStability() {
        // Should return nil instead of crashing
        #expect(Debtor(name: "") == nil)
        #expect(Debtor(name: "   ") == nil)
    }
    
    @Test("DebtAgreement initialization fails with invalid parameters")
    func agreementStability() {
        let debtor = Debtor(name: "Test")!
        
        // Invalid principal
        #expect(DebtAgreement(debtor: debtor, principal: 0, startDate: .now, installmentCount: 1) == nil)
        #expect(DebtAgreement(debtor: debtor, principal: -100, startDate: .now, installmentCount: 1) == nil)
        
        // Invalid installment count
        #expect(DebtAgreement(debtor: debtor, principal: 100, startDate: .now, installmentCount: 0) == nil)
    }

    @Test("Installment initialization fails with invalid amount")
    func installmentStability() {
        let debtor = Debtor(name: "Test")!
        let agreement = DebtAgreement(debtor: debtor, principal: 100, startDate: .now, installmentCount: 1)!
        
        // Invalid amount
        #expect(Installment(agreement: agreement, number: 1, dueDate: .now, amount: 0) == nil)
        #expect(Installment(agreement: agreement, number: 1, dueDate: .now, amount: -10) == nil)
        
        // Invalid number
        #expect(Installment(agreement: agreement, number: 0, dueDate: .now, amount: 10) == nil)
    }
    
    @Test("Payment initialization fails with invalid amount")
    func paymentStability() {
        let debtor = Debtor(name: "Test")!
        let agreement = DebtAgreement(debtor: debtor, principal: 100, startDate: .now, installmentCount: 1)!
        let installment = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 10)!
        
        // Invalid amount
        #expect(Payment(installment: installment, date: .now, amount: 0, method: .cash) == nil)
        #expect(Payment(installment: installment, date: .now, amount: -50, method: .pix) == nil)
    }
    
    @Test("FixedExpense initialization fails with invalid parameters")
    func fixedExpenseStability() {
        // Invalid name
        #expect(FixedExpense(name: "", amount: 100, dueDay: 1) == nil)
        
        // Invalid amount
        #expect(FixedExpense(name: "Rent", amount: -100, dueDay: 1) == nil)
        
        // Invalid due day
        #expect(FixedExpense(name: "Rent", amount: 100, dueDay: 0) == nil)
        #expect(FixedExpense(name: "Rent", amount: 100, dueDay: 32) == nil)
    }
    
    @Test("CashTransaction initialization fails with invalid amount")
    func cashTransactionStability() {
        #expect(CashTransaction(date: .now, amount: 0, type: .expense) == nil)
        #expect(CashTransaction(date: .now, amount: -10, type: .income) == nil)
    }
    */
}
