import Foundation
import SwiftData

/// Calcula projeções de fluxo de caixa para meses futuros.
/// Usa média histórica dos últimos 6 meses + ajustes de cenário.
struct CashFlowProjector: Sendable {

    private let aggregator = HistoricalAggregator()

    /// Projeta fluxo de caixa para os próximos N meses.
    /// - Parameters:
    ///   - months: Número de meses futuros a projetar
    ///   - scenario: Cenário de projeção (realistic, optimistic, pessimistic)
    ///   - context: ModelContext para acesso aos dados
    ///   - calendar: Calendar para cálculos de data
    /// - Returns: Array de CashFlowProjection para os próximos N meses
    func projectCashFlow(
        months: Int,
        scenario: ProjectionScenario = .realistic,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> [CashFlowProjection] {
        guard months > 0 else { return [] }

        let today = Date.now

        // Remover ou reutilizar projeções existentes para o intervalo solicitado
        let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: today) ?? today
        let projectionStart = calendar.dateInterval(of: .month, for: nextMonthDate)?.start ?? nextMonthDate
        let projectionEnd = calendar.date(byAdding: .month, value: months, to: projectionStart) ?? projectionStart

        let existingDescriptor = FetchDescriptor<CashFlowProjection>(
            predicate: #Predicate { projection in
                projection.scenario == scenario.rawValue &&
                projection.targetMonth >= projectionStart &&
                projection.targetMonth < projectionEnd
            }
        )
        let existingProjections = try context.fetch(existingDescriptor).sorted { lhs, rhs in
            if lhs.targetMonth == rhs.targetMonth {
                return lhs.calculatedAt > rhs.calculatedAt
            }
            return lhs.targetMonth < rhs.targetMonth
        }

        var reusableProjections: [Date: CashFlowProjection] = [:]
        var duplicatesToDelete: [CashFlowProjection] = []
        for projection in existingProjections {
            if reusableProjections[projection.targetMonth] == nil {
                reusableProjections[projection.targetMonth] = projection
            } else {
                duplicatesToDelete.append(projection)
            }
        }
        duplicatesToDelete.forEach { context.delete($0) }

        // 1. Buscar histórico (últimos 6 meses para média)
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: today) ?? today
        let historicalStartMonth = calendar.dateInterval(of: .month, for: sixMonthsAgo)?.start ?? sixMonthsAgo
        let historicalSnapshots = try aggregator.fetchSnapshots(
            from: historicalStartMonth,
            to: today,
            context: context
        )

        guard !historicalSnapshots.isEmpty else {
            throw AppError.validation("projection.error.insufficient.data")
        }

        // 2. Calcular médias históricas
        let avgVariableIncome = historicalSnapshots.reduce(.zero) { $0 + $1.variableIncome } / Decimal(historicalSnapshots.count)
        let avgVariableExpenses = historicalSnapshots.reduce(.zero) { $0 + $1.variableExpenses } / Decimal(historicalSnapshots.count)
        let avgSalary = historicalSnapshots.reduce(.zero) { $0 + $1.salary } / Decimal(historicalSnapshots.count)

        // 3. Gerar projeções para cada mês
        var projections: [CashFlowProjection] = []

        for monthOffset in 1...months {
            guard let targetMonth = calendar.date(byAdding: .month, value: monthOffset, to: today) else { continue }
            let monthInterval = calendar.dateInterval(of: .month, for: targetMonth)
                ?? DateInterval(start: targetMonth, end: targetMonth)

            // Projetar salário (usar média histórica)
            let projectedSalary = try fetchOrEstimateSalary(
                for: targetMonth,
                avgSalary: avgSalary,
                context: context,
                calendar: calendar
            )

            // Projetar pagamentos confirmados (parcelas a receber)
            let confirmedPayments = try fetchConfirmedPayments(
                for: monthInterval,
                context: context
            )

            // Projetar despesas fixas
            let projectedFixedExpenses = try fetchFixedExpenses(context: context)

            // Aplicar ajuste de cenário
            let adjustedIncome = applyScenarioAdjustment(
                base: avgVariableIncome,
                scenario: scenario,
                type: .income
            )
            let adjustedExpenses = applyScenarioAdjustment(
                base: avgVariableExpenses,
                scenario: scenario,
                type: .expense
            )

            // Calcular confiança (mais próximo = mais confiável)
            let confidence = calculateConfidence(monthOffset: monthOffset)

            let monthStart = monthInterval.start
            let projection: CashFlowProjection
            if let existingProjection = reusableProjections.removeValue(forKey: monthStart) {
                projection = existingProjection
            } else {
                projection = CashFlowProjection(targetMonth: monthStart, scenario: scenario)
                context.insert(projection)
            }

            projection.targetMonth = monthStart
            projection.scenarioType = scenario
            projection.projectedSalary = projectedSalary
            projection.projectedPayments = confirmedPayments
            projection.projectedVariableIncome = adjustedIncome
            projection.projectedFixedExpenses = projectedFixedExpenses
            projection.projectedVariableExpenses = adjustedExpenses
            let totalIncome = projectedSalary + confirmedPayments + adjustedIncome
            let totalExpenses = projectedFixedExpenses + adjustedExpenses
            projection.totalProjectedIncome = totalIncome
            projection.totalProjectedExpenses = totalExpenses
            projection.projectedBalance = totalIncome - totalExpenses
            projection.confidenceLevel = confidence
            projection.calculatedAt = today

            projections.append(projection)
        }

        reusableProjections.values.forEach { context.delete($0) }

        try context.save()
        return projections
    }

    // MARK: - Helpers

    /// Busca salário confirmado ou estima usando média histórica.
    private func fetchOrEstimateSalary(
        for month: Date,
        avgSalary: Decimal,
        context: ModelContext,
        calendar: Calendar
    ) throws -> Decimal {
        let monthInterval = calendar.dateInterval(of: .month, for: month)
            ?? DateInterval(start: month, end: month)

        let descriptor = FetchDescriptor<SalarySnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.referenceMonth >= monthInterval.start &&
                snapshot.referenceMonth < monthInterval.end
            }
        )
        let salaries = try context.fetch(descriptor)
        return salaries.isEmpty ? avgSalary : salaries.reduce(.zero) { $0 + $1.amount }
    }

    /// Busca parcelas confirmadas a receber no mês.
    private func fetchConfirmedPayments(
        for interval: DateInterval,
        context: ModelContext
    ) throws -> Decimal {
        let paidStatusRawValue = InstallmentStatus.paid.rawValue
        let descriptor = FetchDescriptor<Installment>(
            predicate: #Predicate { installment in
                installment.dueDate >= interval.start &&
                installment.dueDate < interval.end &&
                installment.statusRaw != paidStatusRawValue
            }
        )
        var installments = try context.fetch(descriptor)
        // Forçar carregamento de paidAmount
        installments.forEach { _ = $0.paidAmount }
        return installments.reduce(.zero) { $0 + $1.remainingAmount }
    }

    /// Busca total de despesas fixas ativas.
    private func fetchFixedExpenses(context: ModelContext) throws -> Decimal {
        let descriptor = FetchDescriptor<FixedExpense>(
            predicate: #Predicate { $0.active }
        )
        let expenses = try context.fetch(descriptor)
        return expenses.reduce(.zero) { $0 + $1.amount }
    }

    /// Aplica ajuste de cenário (otimista/realista/pessimista).
    private func applyScenarioAdjustment(
        base: Decimal,
        scenario: ProjectionScenario,
        type: AdjustmentType
    ) -> Decimal {
        let multiplier: Decimal
        switch (scenario, type) {
        case (.optimistic, .income): multiplier = 1.20 // +20%
        case (.optimistic, .expense): multiplier = 0.90 // -10%
        case (.pessimistic, .income): multiplier = 0.80 // -20%
        case (.pessimistic, .expense): multiplier = 1.10 // +10%
        case (.realistic, _): multiplier = 1.0
        }
        return (base * multiplier).rounded(2)
    }

    /// Calcula nível de confiança baseado na distância temporal.
    /// Mês 1 = 90%, Mês 6 = 60%, Mês 12 = 40%
    private func calculateConfidence(monthOffset: Int) -> Double {
        let baseConfidence = 0.90
        let decayRate = 0.05
        return max(0.4, baseConfidence - (Double(monthOffset - 1) * decayRate))
    }

    private enum AdjustmentType {
        case income
        case expense
    }
}
