# Plano: Dashboard Preditivo com Projeção de Fluxo de Caixa

## 📋 Contexto

O Dashboard atual do Money mostra apenas o mês corrente:
- ✅ Salário, recebimentos, despesas do mês atual
- ✅ Parcelas a vencer nos próximos 14 dias
- ✅ Saldo disponível para gastar

### Limitações Identificadas
❌ Sem visão histórica (como foi o último trimestre?)
❌ Sem projeção futura (como será o próximo semestre?)
❌ Sem comparações temporais (mês atual vs anterior, crescimento YoY)
❌ Sem identificação de tendências (receitas caindo? despesas crescendo?)
❌ Sem cenários (e se receitas caírem 20%?)
❌ Sem sazonalidade (dezembro sempre tem mais despesas?)

### Problema de Negócio
Usuário opera no modo "reativo":
- Descobre que está no vermelho só quando já aconteceu
- Não planeja grandes despesas com antecedência
- Não identifica crescimentos insustentáveis de gastos
- Não aproveita meses bons para poupar

### Solução Proposta
Dashboard preditivo com 3 pilares:
1. **Análise Histórica** - Gráficos e métricas dos últimos 6-12 meses
2. **Projeção Futura** - Previsão de receitas/despesas nos próximos 3-6-12 meses
3. **Alertas Inteligentes** - Notificações baseadas em tendências e anomalias

---

## 🎯 Objetivos

### Principais
1. **Planejamento Estratégico** - Permitir decisões de médio/longo prazo (investimentos, compras grandes)
2. **Prevenção de Crises** - Alertar ANTES que problemas se tornem graves
3. **Otimização de Receitas** - Identificar melhores momentos para negociar acordos
4. **Consciência Financeira** - Mostrar evolução (melhorando ou piorando?)

### Secundários
- Identificar sazonalidade (dezembro sempre mais caro?)
- Comparar performance ano-a-ano (2024 melhor que 2023?)
- Testar cenários (e se eu reduzir despesas em 15%?)
- Exportar relatórios históricos

---

## 🏗️ Arquitetura Técnica

### 1. Camada de Dados (Core/Models)

#### 1.1 Novo Modelo: `MonthlySnapshot`

**Arquivo:** `Money/Core/Models/AnalyticsModels.swift`

```swift
import Foundation
import SwiftData

/// Snapshot agregado de todas as métricas financeiras de um mês específico.
/// Calculado automaticamente ao final de cada mês ou sob demanda.
@Model final class MonthlySnapshot {
    @Attribute(.unique) var id: UUID
    var referenceMonth: Date                // Primeiro dia do mês (ex: 2024-01-01)

    // Receitas
    var salary: Decimal
    var paymentsReceived: Decimal           // Pagamentos de devedores
    var variableIncome: Decimal             // Receitas variáveis (CashTransaction.income)
    var totalIncome: Decimal                // Soma de todas as receitas

    // Despesas
    var fixedExpenses: Decimal              // Soma de FixedExpense ativos
    var variableExpenses: Decimal           // CashTransaction.expense
    var totalExpenses: Decimal              // Soma de todas as despesas

    // Saldo
    var netBalance: Decimal                 // totalIncome - totalExpenses
    var cumulativeBalance: Decimal          // Saldo acumulado desde o início

    // Métricas de devedores
    var overdueAmount: Decimal              // Valor em atraso no final do mês
    var activeDebtors: Int                  // Devedores com saldo devedor
    var activeAgreements: Int               // Acordos ativos

    // Crescimento (calculado vs mês anterior)
    var incomeGrowthRate: Double?           // % crescimento de receita MoM
    var expenseGrowthRate: Double?          // % crescimento de despesa MoM

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
        self.netBalance = self.totalIncome - self.totalExpenses
        self.cumulativeBalance = .zero  // Calculado posteriormente
        self.overdueAmount = overdueAmount
        self.activeDebtors = activeDebtors
        self.activeAgreements = activeAgreements
        self.createdAt = createdAt
    }
}

/// Projeção de fluxo de caixa para meses futuros.
@Model final class CashFlowProjection {
    @Attribute(.unique) var id: UUID
    var targetMonth: Date                   // Mês da projeção
    var scenario: String                    // realistic, optimistic, pessimistic

    // Projeções de receita
    var projectedSalary: Decimal
    var projectedPayments: Decimal          // Parcelas confirmadas a receber
    var projectedVariableIncome: Decimal    // Estimativa baseada em média histórica
    var totalProjectedIncome: Decimal

    // Projeções de despesa
    var projectedFixedExpenses: Decimal     // Despesas fixas confirmadas
    var projectedVariableExpenses: Decimal  // Estimativa baseada em média histórica
    var totalProjectedExpenses: Decimal

    // Saldo projetado
    var projectedBalance: Decimal           // totalProjectedIncome - totalProjectedExpenses
    var confidenceLevel: Double             // 0.0 - 1.0 (quão confiável é a projeção)

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
        self.projectedBalance = self.totalProjectedIncome - self.totalProjectedExpenses
        self.confidenceLevel = confidenceLevel
        self.calculatedAt = calculatedAt
    }
}

enum ProjectionScenario: String, Codable, CaseIterable, Sendable {
    case optimistic     // +20% receitas, -10% despesas
    case realistic      // Média histórica
    case pessimistic    // -20% receitas, +10% despesas

    var titleKey: String.LocalizationValue {
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
}
```

---

### 2. Camada de Serviço (Core/Services)

#### 2.1 Serviço: `HistoricalAggregator`

**Arquivo:** `Money/Core/Services/HistoricalAggregator.swift`

```swift
import Foundation
import SwiftData

/// Agrega dados históricos em snapshots mensais.
struct HistoricalAggregator: Sendable {

    /// Cria ou atualiza snapshot para um mês específico.
    func calculateSnapshot(
        for month: Date,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> MonthlySnapshot {
        let monthInterval = calendar.dateInterval(of: .month, for: month)
            ?? DateInterval(start: month, end: month)

        // Buscar snapshot existente
        let snapshotDescriptor = FetchDescriptor<MonthlySnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.referenceMonth >= monthInterval.start &&
                snapshot.referenceMonth < monthInterval.end
            }
        )
        let existingSnapshot = try context.fetch(snapshotDescriptor).first
        let snapshot = existingSnapshot ?? MonthlySnapshot(referenceMonth: monthInterval.start)

        // 1. Calcular salário
        let salaryDescriptor = FetchDescriptor<SalarySnapshot>(
            predicate: #Predicate { sal in
                sal.referenceMonth >= monthInterval.start &&
                sal.referenceMonth < monthInterval.end
            }
        )
        let salaries = try context.fetch(salaryDescriptor)
        snapshot.salary = salaries.reduce(.zero) { $0 + $1.amount }

        // 2. Calcular pagamentos recebidos
        let paymentsDescriptor = FetchDescriptor<Payment>(
            predicate: #Predicate { payment in
                payment.date >= monthInterval.start &&
                payment.date < monthInterval.end
            }
        )
        let payments = try context.fetch(paymentsDescriptor)
        snapshot.paymentsReceived = payments.reduce(.zero) { $0 + $1.amount }

        // 3. Calcular transações variáveis (income e expenses)
        let transactionsDescriptor = FetchDescriptor<CashTransaction>(
            predicate: #Predicate { tx in
                tx.date >= monthInterval.start &&
                tx.date < monthInterval.end
            }
        )
        let transactions = try context.fetch(transactionsDescriptor)
        snapshot.variableIncome = transactions
            .filter { $0.type == .income }
            .reduce(.zero) { $0 + $1.amount }
        snapshot.variableExpenses = transactions
            .filter { $0.type == .expense }
            .reduce(.zero) { $0 + $1.amount }

        // 4. Calcular despesas fixas
        let expensesDescriptor = FetchDescriptor<FixedExpense>(
            predicate: #Predicate { $0.active }
        )
        let expenses = try context.fetch(expensesDescriptor)
        snapshot.fixedExpenses = expenses.reduce(.zero) { $0 + $1.amount }

        // 5. Calcular métricas de devedores (no final do mês)
        let monthEnd = monthInterval.end
        let overdueDescriptor = FetchDescriptor<Installment>(
            predicate: #Predicate { installment in
                installment.dueDate < monthEnd &&
                installment.statusRaw != InstallmentStatus.paid.rawValue
            }
        )
        let overdueInstallments = try context.fetch(overdueDescriptor)
        snapshot.overdueAmount = overdueInstallments.reduce(.zero) { $0 + $1.remainingAmount }

        let debtorsDescriptor = FetchDescriptor<Debtor>(
            predicate: #Predicate { !$0.archived }
        )
        let debtors = try context.fetch(debtorsDescriptor)
        snapshot.activeDebtors = debtors.filter { debtor in
            // Tem saldo devedor?
            debtor.agreements.contains { !$0.closed }
        }.count

        let agreementsDescriptor = FetchDescriptor<DebtAgreement>(
            predicate: #Predicate { !$0.closed }
        )
        snapshot.activeAgreements = try context.fetch(agreementsDescriptor).count

        // 6. Recalcular totais
        snapshot.totalIncome = snapshot.salary + snapshot.paymentsReceived + snapshot.variableIncome
        snapshot.totalExpenses = snapshot.fixedExpenses + snapshot.variableExpenses
        snapshot.netBalance = snapshot.totalIncome - snapshot.totalExpenses

        // 7. Calcular crescimento vs mês anterior
        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: monthInterval.start) {
            if let prevSnapshot = try fetchSnapshot(for: previousMonth, context: context) {
                snapshot.incomeGrowthRate = calculateGrowthRate(
                    current: snapshot.totalIncome,
                    previous: prevSnapshot.totalIncome
                )
                snapshot.expenseGrowthRate = calculateGrowthRate(
                    current: snapshot.totalExpenses,
                    previous: prevSnapshot.totalExpenses
                )
            }
        }

        // 8. Persistir
        if existingSnapshot == nil { context.insert(snapshot) }
        try context.save()

        return snapshot
    }

    /// Busca snapshot de um mês específico.
    func fetchSnapshot(for month: Date, context: ModelContext, calendar: Calendar = .current) throws -> MonthlySnapshot? {
        let monthInterval = calendar.dateInterval(of: .month, for: month)
            ?? DateInterval(start: month, end: month)

        let descriptor = FetchDescriptor<MonthlySnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.referenceMonth >= monthInterval.start &&
                snapshot.referenceMonth < monthInterval.end
            }
        )
        return try context.fetch(descriptor).first
    }

    /// Busca snapshots de um período (ex: últimos 6 meses).
    func fetchSnapshots(
        from startMonth: Date,
        to endMonth: Date,
        context: ModelContext
    ) throws -> [MonthlySnapshot] {
        let descriptor = FetchDescriptor<MonthlySnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.referenceMonth >= startMonth &&
                snapshot.referenceMonth <= endMonth
            },
            sortBy: [SortDescriptor(\.referenceMonth, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    private func calculateGrowthRate(current: Decimal, previous: Decimal) -> Double? {
        guard previous > 0 else { return nil }
        let growth = (current - previous) / previous
        return Double(truncating: NSDecimalNumber(decimal: growth))
    }
}
```

#### 2.2 Serviço: `CashFlowProjector`

**Arquivo:** `Money/Core/Services/CashFlowProjector.swift`

```swift
import Foundation
import SwiftData

/// Calcula projeções de fluxo de caixa para meses futuros.
struct CashFlowProjector: Sendable {

    private let aggregator = HistoricalAggregator()

    /// Projeta fluxo de caixa para os próximos N meses.
    func projectCashFlow(
        months: Int,
        scenario: ProjectionScenario = .realistic,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> [CashFlowProjection] {
        // 1. Buscar histórico (últimos 6 meses para média)
        let today = Date.now
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: today) ?? today
        let historicalSnapshots = try aggregator.fetchSnapshots(
            from: sixMonthsAgo,
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

        // 3. Buscar salário futuro confirmado (ou usar média)
        var projections: [CashFlowProjection] = []

        for monthOffset in 1...months {
            guard let targetMonth = calendar.date(byAdding: .month, value: monthOffset, to: today) else { continue }
            let monthInterval = calendar.dateInterval(of: .month, for: targetMonth)
                ?? DateInterval(start: targetMonth, end: targetMonth)

            // Projetar salário
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

            let projection = CashFlowProjection(
                targetMonth: monthInterval.start,
                scenario: scenario,
                projectedSalary: projectedSalary,
                projectedPayments: confirmedPayments,
                projectedVariableIncome: adjustedIncome,
                projectedFixedExpenses: projectedFixedExpenses,
                projectedVariableExpenses: adjustedExpenses,
                confidenceLevel: confidence
            )

            context.insert(projection)
            projections.append(projection)
        }

        try context.save()
        return projections
    }

    // MARK: - Helpers

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

    private func fetchConfirmedPayments(
        for interval: DateInterval,
        context: ModelContext
    ) throws -> Decimal {
        let descriptor = FetchDescriptor<Installment>(
            predicate: #Predicate { installment in
                installment.dueDate >= interval.start &&
                installment.dueDate < interval.end &&
                installment.statusRaw != InstallmentStatus.paid.rawValue
            }
        )
        let installments = try context.fetch(descriptor)
        return installments.reduce(.zero) { $0 + $1.remainingAmount }
    }

    private func fetchFixedExpenses(context: ModelContext) throws -> Decimal {
        let descriptor = FetchDescriptor<FixedExpense>(
            predicate: #Predicate { $0.active }
        )
        let expenses = try context.fetch(descriptor)
        return expenses.reduce(.zero) { $0 + $1.amount }
    }

    private func applyScenarioAdjustment(
        base: Decimal,
        scenario: ProjectionScenario,
        type: AdjustmentType
    ) -> Decimal {
        let multiplier: Decimal
        switch (scenario, type) {
        case (.optimistic, .income): multiplier = 1.20      // +20%
        case (.optimistic, .expense): multiplier = 0.90     // -10%
        case (.pessimistic, .income): multiplier = 0.80     // -20%
        case (.pessimistic, .expense): multiplier = 1.10    // +10%
        case (.realistic, _): multiplier = 1.0
        }
        return (base * multiplier).rounded(2)
    }

    private func calculateConfidence(monthOffset: Int) -> Double {
        // Confiança diminui com distância temporal
        // Mês 1 = 90%, Mês 6 = 60%, Mês 12 = 40%
        let baseConfidence = 0.90
        let decayRate = 0.05
        return max(0.4, baseConfidence - (Double(monthOffset - 1) * decayRate))
    }

    private enum AdjustmentType {
        case income
        case expense
    }
}
```

---

### 3. Camada de Apresentação (Presentation)

#### 3.1 ViewModel: `HistoricalAnalysisViewModel`

**Arquivo:** `Money/Presentation/Analytics/HistoricalAnalysisViewModel.swift`

```swift
import Foundation
import SwiftData
import Combine

@MainActor
final class HistoricalAnalysisViewModel: ObservableObject {
    @Published private(set) var snapshots: [MonthlySnapshot] = []
    @Published private(set) var isLoading = false
    @Published var error: AppError?
    @Published var timeRange: TimeRange = .sixMonths {
        didSet { Task { await loadHistoricalData() } }
    }

    private let context: ModelContext
    private let aggregator: HistoricalAggregator
    private let currencyFormatter: CurrencyFormatter

    enum TimeRange: String, CaseIterable {
        case threeMonths = "3 meses"
        case sixMonths = "6 meses"
        case twelveMonths = "12 meses"
        case allTime = "Todo período"

        var monthsBack: Int? {
            switch self {
            case .threeMonths: return 3
            case .sixMonths: return 6
            case .twelveMonths: return 12
            case .allTime: return nil
            }
        }
    }

    init(context: ModelContext, currencyFormatter: CurrencyFormatter) {
        self.context = context
        self.aggregator = HistoricalAggregator()
        self.currencyFormatter = currencyFormatter
    }

    func loadHistoricalData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let calendar = Calendar.current
            let today = Date.now

            // Determinar período
            let startMonth: Date
            if let monthsBack = timeRange.monthsBack {
                startMonth = calendar.date(byAdding: .month, value: -monthsBack, to: today) ?? today
            } else {
                // "Todo período" - buscar primeiro snapshot
                let firstDescriptor = FetchDescriptor<MonthlySnapshot>(
                    sortBy: [SortDescriptor(\.referenceMonth, order: .forward)]
                )
                if let first = try context.fetch(firstDescriptor).first {
                    startMonth = first.referenceMonth
                } else {
                    startMonth = calendar.date(byAdding: .year, value: -1, to: today) ?? today
                }
            }

            // Garantir que snapshots existam para o período
            var currentMonth = startMonth
            while currentMonth <= today {
                _ = try aggregator.calculateSnapshot(for: currentMonth, context: context, calendar: calendar)
                guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { break }
                currentMonth = nextMonth
            }

            // Buscar snapshots
            snapshots = try aggregator.fetchSnapshots(from: startMonth, to: today, context: context)

            // Calcular saldo acumulado
            calculateCumulativeBalance()

        } catch {
            self.error = .persistence("error.historical.load")
        }
    }

    private func calculateCumulativeBalance() {
        var cumulative = Decimal.zero
        for snapshot in snapshots {
            cumulative += snapshot.netBalance
            snapshot.cumulativeBalance = cumulative
        }
    }

    // MARK: - Computed Properties

    var averageIncome: Decimal {
        guard !snapshots.isEmpty else { return .zero }
        return snapshots.reduce(.zero) { $0 + $1.totalIncome } / Decimal(snapshots.count)
    }

    var averageExpenses: Decimal {
        guard !snapshots.isEmpty else { return .zero }
        return snapshots.reduce(.zero) { $0 + $1.totalExpenses } / Decimal(snapshots.count)
    }

    var averageBalance: Decimal {
        guard !snapshots.isEmpty else { return .zero }
        return snapshots.reduce(.zero) { $0 + $1.netBalance } / Decimal(snapshots.count)
    }

    var totalIncomeGrowth: Double? {
        guard snapshots.count >= 2 else { return nil }
        let first = snapshots.first!.totalIncome
        let last = snapshots.last!.totalIncome
        guard first > 0 else { return nil }
        let growth = (last - first) / first
        return Double(truncating: NSDecimalNumber(decimal: growth))
    }

    // MARK: - Formatters

    func formatted(_ value: Decimal) -> String {
        currencyFormatter.string(from: value)
    }

    func formattedGrowth(_ rate: Double?) -> String {
        guard let rate else { return "--" }
        return rate.formatted(.percent.precision(.fractionLength(1)))
    }
}
```

#### 3.2 Componente: `TrendChart` (usando Swift Charts)

**Arquivo:** `Money/Presentation/Analytics/Components/TrendChart.swift`

```swift
import SwiftUI
import Charts

/// Gráfico de linha mostrando tendências temporais.
/// Usa Swift Charts (iOS 16+) para renderizar gráficos nativos.
struct TrendChart: View {
    let data: [ChartDataPoint]
    let title: String
    var color: Color = .blue

    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let label: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            Chart(data) { point in
                LineMark(
                    x: .value("Mês", point.date, unit: .month),
                    y: .value("Valor", point.value)
                )
                .foregroundStyle(color.gradient)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                AreaMark(
                    x: .value("Mês", point.date, unit: .month),
                    y: .value("Valor", point.value)
                )
                .foregroundStyle(color.opacity(0.1).gradient)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.month(.abbreviated))
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
            .frame(height: 200)
        }
        .padding(20)
        .moneyCard(
            tint: color,
            cornerRadius: 24,
            shadow: .standard,
            intensity: .standard
        )
    }
}

#Preview {
    TrendChart(
        data: [
            TrendChart.ChartDataPoint(date: Date().addingTimeInterval(-86400 * 150), value: 5000, label: "Jan"),
            TrendChart.ChartDataPoint(date: Date().addingTimeInterval(-86400 * 120), value: 5500, label: "Fev"),
            TrendChart.ChartDataPoint(date: Date().addingTimeInterval(-86400 * 90), value: 5200, label: "Mar"),
            TrendChart.ChartDataPoint(date: Date().addingTimeInterval(-86400 * 60), value: 6000, label: "Abr"),
            TrendChart.ChartDataPoint(date: Date().addingTimeInterval(-86400 * 30), value: 6200, label: "Mai"),
            TrendChart.ChartDataPoint(date: Date(), value: 6500, label: "Jun")
        ],
        title: "Evolução de Receitas",
        color: .green
    )
    .padding()
}
```

#### 3.3 Scene Completa: `HistoricalAnalysisScene`

**Arquivo:** `Money/Presentation/Analytics/HistoricalAnalysisScene.swift`

```swift
import SwiftUI
import SwiftData

/// Tela de análise histórica com gráficos e comparações.
struct HistoricalAnalysisScene: View {
    @StateObject private var viewModel: HistoricalAnalysisViewModel

    init(environment: AppEnvironment, context: ModelContext) {
        _viewModel = StateObject(
            wrappedValue: HistoricalAnalysisViewModel(
                context: context,
                currencyFormatter: environment.currencyFormatter
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Filtro de período
                    periodPicker

                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if !viewModel.snapshots.isEmpty {
                        // Resumo executivo
                        summaryCards

                        // Gráfico de receitas
                        incomeChart

                        // Gráfico de despesas
                        expenseChart

                        // Gráfico de saldo
                        balanceChart

                        // Comparações MoM e YoY
                        comparisonsSection
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(AppBackground(variant: .dashboard))
            .navigationTitle("Análise Histórica")
            .refreshable {
                await viewModel.loadHistoricalData()
            }
        }
        .task {
            await viewModel.loadHistoricalData()
        }
    }

    // MARK: - Components

    private var periodPicker: some View {
        Picker("Período", selection: $viewModel.timeRange) {
            ForEach(HistoricalAnalysisViewModel.TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricCard(
                title: "Receita Média",
                value: viewModel.formatted(viewModel.averageIncome),
                icon: "arrow.down.circle.fill",
                tint: .green
            )

            MetricCard(
                title: "Despesa Média",
                value: viewModel.formatted(viewModel.averageExpenses),
                icon: "arrow.up.circle.fill",
                tint: .red
            )

            MetricCard(
                title: "Saldo Médio",
                value: viewModel.formatted(viewModel.averageBalance),
                caption: viewModel.totalIncomeGrowth != nil ? "Crescimento: \(viewModel.formattedGrowth(viewModel.totalIncomeGrowth))" : nil,
                icon: "chart.line.uptrend.xyaxis",
                tint: .blue
            )
        }
    }

    private var incomeChart: some View {
        TrendChart(
            data: viewModel.snapshots.map { snapshot in
                TrendChart.ChartDataPoint(
                    date: snapshot.referenceMonth,
                    value: Double(truncating: NSDecimalNumber(decimal: snapshot.totalIncome)),
                    label: snapshot.referenceMonth.formatted(.dateTime.month(.abbreviated))
                )
            },
            title: "Evolução de Receitas",
            color: .green
        )
    }

    private var expenseChart: some View {
        TrendChart(
            data: viewModel.snapshots.map { snapshot in
                TrendChart.ChartDataPoint(
                    date: snapshot.referenceMonth,
                    value: Double(truncating: NSDecimalNumber(decimal: snapshot.totalExpenses)),
                    label: snapshot.referenceMonth.formatted(.dateTime.month(.abbreviated))
                )
            },
            title: "Evolução de Despesas",
            color: .red
        )
    }

    private var balanceChart: some View {
        TrendChart(
            data: viewModel.snapshots.map { snapshot in
                TrendChart.ChartDataPoint(
                    date: snapshot.referenceMonth,
                    value: Double(truncating: NSDecimalNumber(decimal: snapshot.netBalance)),
                    label: snapshot.referenceMonth.formatted(.dateTime.month(.abbreviated))
                )
            },
            title: "Saldo Mensal",
            color: .blue
        )
    }

    private var comparisonsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Comparações")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(viewModel.snapshots.suffix(3)) { snapshot in
                if let growth = snapshot.incomeGrowthRate {
                    comparisonRow(
                        month: snapshot.referenceMonth,
                        label: "Receita vs Mês Anterior",
                        growth: growth
                    )
                }
            }
        }
    }

    private func comparisonRow(month: Date, label: String, growth: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(month, format: .dateTime.month().year())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: growth >= 0 ? "arrow.up" : "arrow.down")
                    .font(.caption)
                Text(abs(growth).formatted(.percent.precision(.fractionLength(1))))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(growth >= 0 ? .green : .red)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (growth >= 0 ? Color.green : Color.red).opacity(0.15),
                in: Capsule()
            )
        }
        .padding(16)
        .moneyCard(
            tint: growth >= 0 ? .green : .red,
            cornerRadius: 18,
            shadow: .compact,
            intensity: .subtle
        )
    }

    private var emptyState: some View {
        AppEmptyState(
            icon: "chart.xyaxis.line",
            title: "Sem Histórico",
            message: "Não há dados históricos para o período selecionado.",
            style: .minimal
        )
    }
}
```

---

## 📝 Ordem de Implementação

### Fase 1: Fundação de Dados (Semana 1)
1. ✅ Criar `AnalyticsModels.swift` com `MonthlySnapshot` e `CashFlowProjection`
2. ✅ Criar `HistoricalAggregator.swift` com lógica de agregação
3. ✅ Criar job para calcular snapshots automaticamente (fim do mês)
4. ✅ Migrar dados existentes para criar snapshots retroativos
5. ✅ Testes unitários para agregação

### Fase 2: Visualização Histórica (Semana 2)
6. ✅ Criar `TrendChart.swift` com Swift Charts
7. ✅ Criar `HistoricalAnalysisViewModel.swift`
8. ✅ Criar `HistoricalAnalysisScene.swift`
9. ✅ Adicionar nova tab "Histórico" ao TabView principal
10. ✅ Testes de UI para navegação

### Fase 3: Projeções (Semana 3)
11. ✅ Criar `CashFlowProjector.swift` com algoritmos de projeção
12. ✅ Criar `ProjectionViewModel.swift`
13. ✅ Criar `ProjectionScene.swift` com cenários
14. ✅ Adicionar botão "Ver Projeções" no Dashboard
15. ✅ Testes para cálculos de projeção

### Fase 4: Alertas e Refinamentos (Semana 4)
16. ✅ Implementar sistema de alertas inteligentes
17. ✅ Adicionar comparações YoY e MoM
18. ✅ Exportar histórico/projeções em CSV
19. ✅ Otimizar performance (indexação, cache)
20. ✅ Documentação e ajustes finais

---

## 🧪 Testes

### Testes Unitários

**Arquivo:** `MoneyTests/HistoricalAggregatorTests.swift`

```swift
import Testing
import SwiftData
@testable import Money

@Suite("HistoricalAggregator Tests")
struct HistoricalAggregatorTests {

    @Test("Snapshot calcula receitas corretamente")
    func testIncomeCalculation() async throws {
        // ... criar contexto mockado com salário + pagamentos + transações
        // ... validar que snapshot.totalIncome está correto
    }

    @Test("Crescimento MoM é calculado corretamente")
    func testMonthOverMonthGrowth() async throws {
        // ... criar 2 snapshots consecutivos
        // ... validar cálculo de incomeGrowthRate
    }
}

@Suite("CashFlowProjector Tests")
struct CashFlowProjectorTests {

    @Test("Projeção realista usa médias históricas")
    func testRealisticProjection() async throws {
        // ... criar histórico de 6 meses
        // ... validar que projeção usa médias
    }

    @Test("Cenário otimista aumenta receitas em 20%")
    func testOptimisticScenario() async throws {
        // ... validar ajuste de +20% em receitas
    }
}
```

---

## ⚠️ Riscos e Mitigações

| Risco | Impacto | Probabilidade | Mitigação |
|-------|---------|---------------|-----------|
| Performance ao calcular snapshots de anos de dados | Alto | Média | Background jobs, processamento incremental |
| Swift Charts requer iOS 16+ | Médio | Baixa | Fallback para gráficos simples ou biblioteca externa |
| Projeções imprecisas enganam usuário | Alto | Média | Mostrar nível de confiança, disclaimers claros |
| Muitos dados na tela (scrolling infinito) | Baixo | Média | Paginação, filtros de período |

---

## ✅ Validação Final

### Checklist de Conclusão
- [ ] Snapshots calculados retroativamente para dados existentes
- [ ] Job automático de snapshot ao final do mês
- [ ] Gráficos renderizam corretamente em light/dark mode
- [ ] Projeções com 3 cenários funcionando
- [ ] Comparações MoM e YoY exibidas
- [ ] Exportação CSV inclui histórico
- [ ] Performance validada com 24+ meses de dados
- [ ] Testes unitários > 80% cobertura
- [ ] Acessibilidade testada (VoiceOver para gráficos)
- [ ] Localização completa

---

## 📊 Métricas de Sucesso

- **Adoção:** 70%+ dos usuários acessam análise histórica mensalmente
- **Engajamento:** Tempo médio na tela > 3 minutos
- **Utilidade:** 80%+ reportam que tomam decisões baseadas nas projeções
- **Precisão:** Projeções com erro < 20% vs realizado (após 3 meses)
