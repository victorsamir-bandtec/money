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
            compactMetricCard(
                value: viewModel.formatted(viewModel.averageIncome),
                growth: viewModel.totalIncomeGrowth,
                icon: "arrow.up.circle.fill",
                tint: .green
            )

            compactMetricCard(
                value: viewModel.formatted(viewModel.averageExpenses),
                growth: viewModel.totalExpensesGrowth,
                icon: "arrow.down.circle.fill",
                tint: .red
            )
        }
    }

    private func compactMetricCard(value: String, growth: Double?, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(tint.opacity(0.2))
                    .overlay {
                        Circle()
                            .strokeBorder(tint.opacity(0.3), lineWidth: 1)
                    }
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    .frame(width: 32, height: 32)
                
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer(minLength: 0)
            }

            Text(growthCaption(for: growth))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyCard(tint: tint, cornerRadius: 20)
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
        VStack(alignment: .leading, spacing: 20) {
            Text("analytics.projections.title")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("analytics.projections.subtitle")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !viewModel.projections.isEmpty {
                VStack(spacing: 16) {
                    ForEach(ProjectionScenario.allCases, id: \.self) { scenario in
                        if let scenarioProjections = viewModel.projections[scenario],
                           let nextMonthProjection = scenarioProjections.first {
                            ProjectionCardView(
                                scenario: scenario,
                                projectedBalance: viewModel.formatted(nextMonthProjection.projectedBalance),
                                confidence: viewModel.formattedConfidence(nextMonthProjection.confidenceLevel),
                                isSelected: viewModel.selectedScenario == scenario
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.selectedScenario = scenario
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
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

    private func growthCaption(for growth: Double?) -> LocalizedStringKey {
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
