import Foundation
import SwiftData
import SwiftUI

// MARK: - Core Finance Models

@Model final class Debtor {
    @Attribute(.unique) var id: UUID
    var name: String
    var phone: String?
    var note: String?
    @Relationship(deleteRule: .cascade) var agreements: [DebtAgreement]
    @Relationship(deleteRule: .nullify, inverse: \DebtorCreditProfile.debtor) var creditProfile: DebtorCreditProfile?
    var createdAt: Date
    var archived: Bool

    var currentScore: Int {
        return creditProfile?.score ?? 50
    }

    init(
        id: UUID = UUID(),
        name: String,
        phone: String? = nil,
        note: String? = nil,
        createdAt: Date = .now,
        archived: Bool = false
    ) {
        precondition(!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        self.id = id
        self.name = name
        self.phone = phone
        self.note = note
        self.agreements = []
        self.createdAt = createdAt
        self.archived = archived
    }
}

@Model final class DebtAgreement {
    @Attribute(.unique) var id: UUID
    @Relationship var debtor: Debtor
    var title: String?
    var principal: Decimal
    var startDate: Date
    var installmentCount: Int
    var currencyCode: String
    var interestRateMonthly: Decimal?
    @Relationship(deleteRule: .cascade) var installments: [Installment]
    var closed: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        debtor: Debtor,
        title: String? = nil,
        principal: Decimal,
        startDate: Date,
        installmentCount: Int,
        currencyCode: String = "BRL",
        interestRateMonthly: Decimal? = nil,
        closed: Bool = false,
        createdAt: Date = .now
    ) {
        precondition(principal > 0)
        precondition(installmentCount >= 1)
        self.id = id
        self.debtor = debtor
        self.title = title
        self.principal = principal
        self.startDate = startDate
        self.installmentCount = installmentCount
        self.currencyCode = currencyCode
        self.interestRateMonthly = interestRateMonthly
        self.installments = []
        self.closed = closed
        self.createdAt = createdAt
    }
}

extension DebtAgreement {
    /// Synchronizes the `closed` flag with the current state of the installments.
    /// - Returns: `true` when the stored value was modified.
    @discardableResult
    func updateClosedStatus() -> Bool {
        let shouldClose = !installments.isEmpty && installments.allSatisfy { $0.status == .paid }
        guard closed != shouldClose else { return false }
        closed = shouldClose
        return true
    }
}

enum InstallmentStatus: Int, Codable, Sendable {
    case pending, partial, paid, overdue
}

@Model final class Installment {
    @Attribute(.unique) var id: UUID
    @Relationship var agreement: DebtAgreement
    var number: Int
    var dueDate: Date
    var amount: Decimal
    var paidAmount: Decimal
    var statusRaw: Int
    @Relationship(deleteRule: .cascade) var payments: [Payment]

    var status: InstallmentStatus {
        get { InstallmentStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        agreement: DebtAgreement,
        number: Int,
        dueDate: Date,
        amount: Decimal,
        paidAmount: Decimal = .zero,
        status: InstallmentStatus = .pending
    ) {
        precondition(number >= 1)
        precondition(amount > 0)
        precondition(paidAmount >= 0)
        self.id = id
        self.agreement = agreement
        self.number = number
        self.dueDate = dueDate
        self.amount = amount
        self.paidAmount = paidAmount
        self.statusRaw = status.rawValue
        self.payments = []
    }
}

@Model final class Payment {
    @Attribute(.unique) var id: UUID
    @Relationship var installment: Installment
    var date: Date
    var amount: Decimal
    var methodRaw: String
    var note: String?

    var method: PaymentMethod {
        get { PaymentMethod(rawValue: methodRaw) ?? .other }
        set { methodRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        installment: Installment,
        date: Date,
        amount: Decimal,
        method: PaymentMethod,
        note: String? = nil
    ) {
        precondition(amount > 0)
        self.id = id
        self.installment = installment
        self.date = date
        self.amount = amount
        self.methodRaw = method.rawValue
        self.note = note
    }
}

enum PaymentMethod: String, Codable, CaseIterable, Sendable {
    case pix, cash, transfer, other
}

enum CashTransactionType: String, Codable, CaseIterable, Sendable {
    case expense
    case income

    var titleKey: String.LocalizationValue {
        switch self {
        case .expense:
            return "transactions.type.expense"
        case .income:
            return "transactions.type.income"
        }
    }
}

@Model final class CashTransaction {
    @Attribute(.unique) var id: UUID
    var date: Date
    var amount: Decimal
    var typeRaw: String
    var category: String?
    var note: String?
    var createdAt: Date

    var type: CashTransactionType {
        get { CashTransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        amount: Decimal,
        type: CashTransactionType,
        category: String? = nil,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        precondition(amount > 0)
        self.id = id
        self.date = date
        self.amount = amount
        self.typeRaw = type.rawValue
        self.category = category
        self.note = note
        self.createdAt = createdAt
    }
}

@Model final class FixedExpense {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var category: String?
    var dueDay: Int
    var active: Bool
    var note: String?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        category: String? = nil,
        dueDay: Int,
        active: Bool = true,
        note: String? = nil
    ) {
        precondition(!name.trimmingCharacters(in: .whitespaces).isEmpty)
        precondition(amount >= 0)
        precondition((1...31).contains(dueDay))
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.dueDay = dueDay
        self.active = active
        self.note = note
    }
}

// MARK: - FixedExpense Extensions

extension FixedExpense {
    /// Returns the next calendar date matching the stored `dueDay`, rolling over to the following month when needed.
    func nextDueDate(reference: Date = .now, calendar: Calendar = .current) -> Date? {
        var components = calendar.dateComponents([.year, .month], from: reference)
        components.day = min(dueDay, calendar.range(of: .day, in: .month, for: reference)?.count ?? dueDay)
        guard let candidate = calendar.date(from: components) else { return nil }

        if candidate >= calendar.startOfDay(for: reference) {
            return candidate
        }

        guard let nextMonth = calendar.date(byAdding: DateComponents(month: 1), to: candidate) else { return candidate }
        var nextComponents = calendar.dateComponents([.year, .month], from: nextMonth)
        nextComponents.day = min(dueDay, calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? dueDay)
        return calendar.date(from: nextComponents)
    }
}

// MARK: - CashTransaction Extensions

extension CashTransaction {
    var signedAmount: Decimal {
        type == .expense ? -amount : amount
    }
}

@Model final class SalarySnapshot {
    @Attribute(.unique) var id: UUID
    var referenceMonth: Date
    var amount: Decimal
    var note: String?

    init(id: UUID = UUID(), referenceMonth: Date, amount: Decimal, note: String? = nil) {
        precondition(amount >= 0)
        self.id = id
        self.referenceMonth = referenceMonth
        self.amount = amount
        self.note = note
    }
}

extension Installment {
    var remainingAmount: Decimal {
        (amount - paidAmount).clamped(to: .zero...amount)
    }

    func isOverdue(relativeTo referenceDate: Date, calendar: Calendar = .current) -> Bool {
        status == .overdue || (status != .paid && calendar.startOfDay(for: referenceDate) > calendar.startOfDay(for: dueDate))
    }

    var isOverdue: Bool {
        isOverdue(relativeTo: .now)
    }
}

extension Decimal {
    func rounded(_ scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }

    func clamped(to range: ClosedRange<Decimal>) -> Decimal {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Credit Models

@Model final class DebtorCreditProfile {
    @Attribute(.unique) var id: UUID
    @Relationship var debtor: Debtor

    var score: Int
    var riskLevelRaw: String
    var lastCalculated: Date

    var totalAgreements: Int
    var totalInstallments: Int
    var paidOnTimeCount: Int
    var paidLateCount: Int
    var overdueCount: Int
    var averageDaysLate: Double
    var onTimePaymentRate: Double

    var totalLent: Decimal
    var totalPaid: Decimal
    var totalInterestEarned: Decimal
    var currentOutstanding: Decimal

    var firstAgreementDate: Date?
    var lastPaymentDate: Date?
    var consecutiveOnTimePayments: Int
    var longestDelayDays: Int

    var riskLevel: RiskLevel {
        get { RiskLevel(rawValue: riskLevelRaw) ?? .medium }
        set { riskLevelRaw = newValue.rawValue }
    }

    var returnOnInvestment: Decimal {
        guard totalLent > 0 else { return 0 }
        return (totalInterestEarned / totalLent) * 100
    }

    var profitMargin: Decimal {
        guard totalPaid > 0 else { return 0 }
        return (totalInterestEarned / totalPaid) * 100
    }

    var collectionRate: Double {
        guard totalLent > 0 else { return 0 }
        return Double(truncating: (totalPaid / totalLent) as NSDecimalNumber)
    }

    init(
        id: UUID = UUID(),
        debtor: Debtor,
        score: Int = 50,
        riskLevel: RiskLevel = .medium,
        lastCalculated: Date = .now
    ) {
        self.id = id
        self.debtor = debtor
        self.score = score
        self.riskLevelRaw = riskLevel.rawValue
        self.lastCalculated = lastCalculated
        self.totalAgreements = 0
        self.totalInstallments = 0
        self.paidOnTimeCount = 0
        self.paidLateCount = 0
        self.overdueCount = 0
        self.averageDaysLate = 0
        self.onTimePaymentRate = 0
        self.totalLent = .zero
        self.totalPaid = .zero
        self.totalInterestEarned = .zero
        self.currentOutstanding = .zero
        self.consecutiveOnTimePayments = 0
        self.longestDelayDays = 0
    }
}

enum RiskLevel: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    var icon: String {
        switch self {
        case .low: return "checkmark.shield.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "xmark.shield.fill"
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .low: return "credit.risk.low"
        case .medium: return "credit.risk.medium"
        case .high: return "credit.risk.high"
        }
    }

    var descriptionKey: LocalizedStringKey {
        switch self {
        case .low: return "credit.risk.low.description"
        case .medium: return "credit.risk.medium.description"
        case .high: return "credit.risk.high.description"
        }
    }
}

// MARK: - Analytics Models

/// Snapshot agregado de todas as métricas financeiras de um mês específico.
/// Calculado sob demanda ao carregar a tela de análise histórica.
@Model final class MonthlySnapshot {
    @Attribute(.unique) var id: UUID
    var referenceMonth: Date // Primeiro dia do mês (ex: 2024-01-01)

    // Receitas
    var salary: Decimal
    var paymentsReceived: Decimal // Pagamentos de devedores
    var variableIncome: Decimal // Receitas variáveis (CashTransaction.income)
    var totalIncome: Decimal // Soma de todas as receitas

    // Despesas
    var fixedExpenses: Decimal // Soma de FixedExpense ativos
    var variableExpenses: Decimal // CashTransaction.expense
    var totalExpenses: Decimal // Soma de todas as despesas

    // Saldo
    var netBalance: Decimal // totalIncome - totalExpenses

    // Métricas de devedores
    var overdueAmount: Decimal // Valor em atraso no final do mês
    var activeDebtors: Int // Devedores com saldo devedor
    var activeAgreements: Int // Acordos ativos

    var createdAt: Date

    init(
        id: UUID = UUID(),
        referenceMonth: Date,
        salary: Decimal = .zero,
        paymentsReceived: Decimal = .zero,
        variableIncome: Decimal = .zero,
        fixedExpenses: Decimal = .zero,
        variableExpenses: Decimal = .zero,
        overdueAmount: Decimal = .zero,
        activeDebtors: Int = 0,
        activeAgreements: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.referenceMonth = referenceMonth
        self.salary = salary
        self.paymentsReceived = paymentsReceived
        self.variableIncome = variableIncome
        self.totalIncome = salary + paymentsReceived + variableIncome
        self.fixedExpenses = fixedExpenses
        self.variableExpenses = variableExpenses
        self.totalExpenses = fixedExpenses + variableExpenses
        self.netBalance = (salary + paymentsReceived + variableIncome) - (fixedExpenses + variableExpenses)
        self.overdueAmount = overdueAmount
        self.activeDebtors = activeDebtors
        self.activeAgreements = activeAgreements
        self.createdAt = createdAt
    }
}

/// Projeção de fluxo de caixa para meses futuros.
@Model final class CashFlowProjection {
    @Attribute(.unique) var id: UUID
    var targetMonth: Date // Mês da projeção
    var scenario: String // realistic, optimistic, pessimistic

    // Projeções de receita
    var projectedSalary: Decimal
    var projectedPayments: Decimal // Parcelas confirmadas a receber
    var projectedVariableIncome: Decimal // Estimativa baseada em média histórica
    var totalProjectedIncome: Decimal

    // Projeções de despesa
    var projectedFixedExpenses: Decimal // Despesas fixas confirmadas
    var projectedVariableExpenses: Decimal // Estimativa baseada em média histórica
    var totalProjectedExpenses: Decimal

    // Saldo projetado
    var projectedBalance: Decimal // totalProjectedIncome - totalProjectedExpenses
    var confidenceLevel: Double // 0.0 - 1.0 (quão confiável é a projeção)

    var calculatedAt: Date

    var scenarioType: ProjectionScenario {
        get { ProjectionScenario(rawValue: scenario) ?? .realistic }
        set { scenario = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        targetMonth: Date,
        scenario: ProjectionScenario = .realistic,
        projectedSalary: Decimal = .zero,
        projectedPayments: Decimal = .zero,
        projectedVariableIncome: Decimal = .zero,
        projectedFixedExpenses: Decimal = .zero,
        projectedVariableExpenses: Decimal = .zero,
        confidenceLevel: Double = 0.7,
        calculatedAt: Date = .now
    ) {
        self.id = id
        self.targetMonth = targetMonth
        self.scenario = scenario.rawValue
        self.projectedSalary = projectedSalary
        self.projectedPayments = projectedPayments
        self.projectedVariableIncome = projectedVariableIncome
        self.totalProjectedIncome = projectedSalary + projectedPayments + projectedVariableIncome
        self.projectedFixedExpenses = projectedFixedExpenses
        self.projectedVariableExpenses = projectedVariableExpenses
        self.totalProjectedExpenses = projectedFixedExpenses + projectedVariableExpenses
        self.projectedBalance = (projectedSalary + projectedPayments + projectedVariableIncome) - (projectedFixedExpenses + projectedVariableExpenses)
        self.confidenceLevel = confidenceLevel
        self.calculatedAt = calculatedAt
    }
}

enum ProjectionScenario: String, Codable, CaseIterable, Sendable {
    case optimistic // +20% receitas, -10% despesas
    case realistic // Média histórica
    case pessimistic // -20% receitas, +10% despesas

    var titleKey: LocalizedStringKey {
        switch self {
        case .optimistic: return "projection.scenario.optimistic"
        case .realistic: return "projection.scenario.realistic"
        case .pessimistic: return "projection.scenario.pessimistic"
        }
    }

    var color: Color {
        switch self {
        case .optimistic: return .green
        case .realistic: return .blue
        case .pessimistic: return .orange
        }
    }

    var iconName: String {
        switch self {
        case .optimistic: return "arrow.up.right.circle.fill"
        case .realistic: return "equal.circle.fill"
        case .pessimistic: return "arrow.down.right.circle.fill"
        }
    }
}
