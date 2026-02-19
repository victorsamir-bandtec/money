import Foundation
import SwiftData
import Combine

@MainActor
final class HistoricalAnalysisViewModel: ObservableObject {
    @Published private(set) var snapshots: [MonthlySnapshot] = []
    @Published private(set) var projections: [ProjectionScenario: [CashFlowProjection]] = [:]
    @Published private(set) var isLoading = false
    @Published var error: AppError?
    @Published var timeRange: TimeRange = .sixMonths {
        didSet { Task { await loadHistoricalData() } }
    }
    @Published var selectedScenario: ProjectionScenario = .realistic

    private let context: ModelContext
    private let projector: CashFlowProjector
    private let currencyFormatter: CurrencyFormatter
    private let readModel: FinancialSummaryQuerying

    enum TimeRange: String, CaseIterable {
        case threeMonths = "analytics.range.3months"
        case sixMonths = "analytics.range.6months"
        case twelveMonths = "analytics.range.12months"

        var monthsBack: Int {
            switch self {
            case .threeMonths: return 3
            case .sixMonths: return 6
            case .twelveMonths: return 12
            }
        }
    }

    init(
        context: ModelContext,
        currencyFormatter: CurrencyFormatter,
        readModel: FinancialSummaryQuerying? = nil
    ) {
        self.context = context
        self.projector = CashFlowProjector()
        self.currencyFormatter = currencyFormatter
        self.readModel = readModel ?? FinancialReadModelService(context: context)
    }

    func loadHistoricalData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let calendar = Calendar.current
            let today = Date.now

            // Determinar período histórico normalizado para o início do mês
            let rawStartMonth = calendar.date(byAdding: .month, value: -timeRange.monthsBack, to: today) ?? today
            let startMonthComponents = calendar.dateComponents([.year, .month], from: rawStartMonth)
            let startMonth = calendar.date(from: startMonthComponents) ?? rawStartMonth

            snapshots = try readModel.history(from: startMonth, to: today)

        } catch {
            self.error = .persistence("error.historical.load")
        }
    }

    func loadProjections(months: Int = 6) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Gerar projeções para os 3 cenários
            let scenarios: [ProjectionScenario] = [.realistic, .optimistic, .pessimistic]
            var results: [ProjectionScenario: [CashFlowProjection]] = [:]

            for scenario in scenarios {
                let scenarioProjections = try projector.projectCashFlow(
                    months: months,
                    scenario: scenario,
                    context: context
                )
                results[scenario] = scenarioProjections
            }

            projections = results

        } catch {
            self.error = .persistence("error.projections.load")
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

    var totalExpensesGrowth: Double? {
        guard snapshots.count >= 2 else { return nil }
        let first = snapshots.first!.totalExpenses
        let last = snapshots.last!.totalExpenses
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

    func formattedConfidence(_ confidence: Double) -> String {
        let percent = confidence.formatted(.percent.precision(.fractionLength(0)))
        return "\(String(localized: "projection.confidence")): \(percent)"
    }

    // MARK: - Chart Data Helpers

    func incomeChartData() -> [TrendChart.ChartDataPoint] {
        snapshots.map { snapshot in
            TrendChart.ChartDataPoint(
                date: snapshot.referenceMonth,
                value: Double(truncating: NSDecimalNumber(decimal: snapshot.totalIncome))
            )
        }
    }

    func expenseChartData() -> [TrendChart.ChartDataPoint] {
        snapshots.map { snapshot in
            TrendChart.ChartDataPoint(
                date: snapshot.referenceMonth,
                value: Double(truncating: NSDecimalNumber(decimal: snapshot.totalExpenses))
            )
        }
    }

    func balanceChartData() -> [TrendChart.ChartDataPoint] {
        snapshots.map { snapshot in
            TrendChart.ChartDataPoint(
                date: snapshot.referenceMonth,
                value: Double(truncating: NSDecimalNumber(decimal: snapshot.netBalance))
            )
        }
    }
}
