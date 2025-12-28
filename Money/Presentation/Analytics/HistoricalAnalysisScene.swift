import SwiftUI
import SwiftData

/// Tela de análise histórica com gráficos e projeções futuras.
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
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if !viewModel.snapshots.isEmpty {
                        // Filtro de período
                        periodPicker

                        // Resumo executivo
                        summaryCards

                        // Gráficos de tendência
                        chartsSection

                        // Projeções futuras
                        projectionsSection
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(AppBackground(variant: .dashboard))
            .navigationTitle(String(localized: "analytics.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(String(localized: "analytics.refresh"))
                }
            }
        }
        .task {
            await viewModel.loadHistoricalData()
            await viewModel.loadProjections()
        }
        .refreshable {
            await viewModel.loadHistoricalData()
            await viewModel.loadProjections()
        }
    }

    // MARK: - Components

    private var periodPicker: some View {
        Picker("analytics.period", selection: $viewModel.timeRange) {
            ForEach(HistoricalAnalysisViewModel.TimeRange.allCases, id: \.self) { range in
                Text(LocalizedStringKey(range.rawValue))
                    .tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricCard(
                title: "analytics.metric.avg.income",
                value: viewModel.formatted(viewModel.averageIncome),
                caption: growthCaption(for: viewModel.totalIncomeGrowth),
                icon: "arrow.down.circle.fill",
                tint: .green
            )

            MetricCard(
                title: "analytics.metric.avg.expenses",
                value: viewModel.formatted(viewModel.averageExpenses),
                caption: growthCaption(for: viewModel.totalExpensesGrowth),
                icon: "arrow.up.circle.fill",
                tint: .red
            )
        }
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("analytics.charts.title")
                .font(.headline)
                .foregroundStyle(.secondary)

            TrendChart(
                data: viewModel.incomeChartData(),
                title: "analytics.income.trend",
                color: .green
            )

            TrendChart(
                data: viewModel.expenseChartData(),
                title: "analytics.expense.trend",
                color: .red
            )

            TrendChart(
                data: viewModel.balanceChartData(),
                title: "analytics.balance.trend",
                color: .blue
            )
        }
    }

    private var projectionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("analytics.projections.title")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("analytics.projections.subtitle")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !viewModel.projections.isEmpty {
                ForEach(ProjectionScenario.allCases, id: \.self) { scenario in
                    if let scenarioProjections = viewModel.projections[scenario],
                       let nextMonthProjection = scenarioProjections.first {
                        ScenarioCard(
                            scenario: scenario,
                            projectedBalance: viewModel.formatted(nextMonthProjection.projectedBalance),
                            confidence: viewModel.formattedConfidence(nextMonthProjection.confidenceLevel),
                            isSelected: viewModel.selectedScenario == scenario
                        )
                        .onTapGesture {
                            viewModel.selectedScenario = scenario
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        AppEmptyState(
            icon: "chart.xyaxis.line",
            title: "analytics.empty.title",
            message: "analytics.empty.message",
            style: .minimal
        )
    }

    private func growthCaption(for growth: Double?) -> LocalizedStringKey? {
        guard let growth else { return nil }
        let label = String(localized: "analytics.metric.growth.label")
        let value = viewModel.formattedGrowth(growth)
        return LocalizedStringKey("\(label) \(value)")
    }

    private func refresh() {
        Task {
            await viewModel.loadHistoricalData()
            await viewModel.loadProjections()
        }
    }
}
