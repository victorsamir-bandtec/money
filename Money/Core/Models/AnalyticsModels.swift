import Foundation
import SwiftData
import SwiftUI

// MARK: - MonthlySnapshot

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

// MARK: - CashFlowProjection

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

// MARK: - ProjectionScenario

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
