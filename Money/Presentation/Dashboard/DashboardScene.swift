import SwiftUI
import SwiftData

struct DashboardScene: View {
    @StateObject private var viewModel: DashboardViewModel

    init(environment: AppEnvironment, context: ModelContext) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(context: context, currencyFormatter: environment.currencyFormatter))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summarySection
                    upcomingSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(LinearGradient(colors: [.black.opacity(0.05), .clear], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .navigationTitle(String(localized: "dashboard.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(String(localized: "dashboard.refresh"))
                }
            }
        }
        .task { try? await load() }
        .refreshable { try? await load() }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "dashboard.summary"))
                    .font(.title2)
                    .bold()
                Text(String(localized: "dashboard.summary.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            BalanceOverviewCard(
                summary: viewModel.summary,
                formatter: viewModel.formatted,
                icon: availableIcon,
                tint: availableTint
            )

            if !highlightMetrics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(highlightMetrics) { metric in
                            QuickMetricTile(metric: metric)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 2)
                    .padding(.trailing, 4)
                }
            }

            SpendingBreakdownCard(
                summary: viewModel.summary,
                formatter: viewModel.formatted
            )
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "dashboard.upcoming"))
                .font(.headline)
                .foregroundStyle(.secondary)
            if viewModel.upcoming.isEmpty {
                ContentUnavailableView(String(localized: "dashboard.upcoming.empty"), systemImage: "calendar.badge.clock")
            } else {
                ForEach(viewModel.upcoming) { installment in
                    installmentRow(installment)
                }
            }
        }
    }

    private func installmentRow(_ installment: InstallmentOverview) -> some View {
        let tint: Color
        let intensity: MoneyCardIntensity
        if installment.status == .paid {
            tint = .green
            intensity = .subtle
        } else if installment.isOverdue {
            tint = .orange
            intensity = .standard
        } else if installment.status == .partial {
            tint = .yellow
            intensity = .standard
        } else {
            tint = .cyan
            intensity = .subtle
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(installment.displayTitle)
                    .font(.headline)
                Spacer()
                Text(viewModel.formatted(installment.amount))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            HStack(spacing: 12) {
                Label {
                    Text(installment.dueDate, format: .dateTime.day().month().year())
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if installment.status == .paid {
                    statusTag("status.paid", color: .green)
                } else if installment.isOverdue {
                    statusTag("status.overdue", color: .orange)
                } else if installment.status == .partial {
                    statusTag("status.partial", color: .yellow)
                } else {
                    statusTag("status.pending", color: .cyan)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyCard(
            tint: tint,
            cornerRadius: 22,
            shadow: .compact,
            intensity: intensity
        )
        .accessibilityElement(children: .combine)
    }

    private func statusTag(_ title: LocalizedStringKey, color: Color) -> some View {
        Text(title)
            .font(.caption).bold()
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }

    private func load() async throws {
        try viewModel.load()
    }

    private func refresh() {
        Task { try await load() }
    }

    private var availableTint: Color {
        viewModel.summary.availableToSpend >= .zero ? .blue : .red
    }

    private var availableIcon: String {
        viewModel.summary.availableToSpend >= .zero ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis"
    }

    private var highlightMetrics: [HighlightMetric] {
        [
            HighlightMetric(
                id: "overdue",
                title: "dashboard.metric.overdue",
                value: viewModel.formatted(viewModel.summary.overdue),
                caption: "dashboard.metric.overdue.caption",
                icon: "exclamationmark.triangle.fill",
                tint: .orange
            ),
            HighlightMetric(
                id: "fixedExpenses",
                title: "dashboard.metric.expenses.fixed",
                value: viewModel.formatted(viewModel.summary.fixedExpenses),
                caption: nil,
                icon: "doc.text.fill",
                tint: .pink
            ),
            HighlightMetric(
                id: "variableExpenses",
                title: "dashboard.metric.expenses.variable",
                value: viewModel.formatted(viewModel.summary.variableExpenses),
                caption: nil,
                icon: "arrow.uturn.down.circle.fill",
                tint: .orange
            ),
            HighlightMetric(
                id: "variableIncome",
                title: "dashboard.metric.expenses.income",
                value: viewModel.formatted(viewModel.summary.variableIncome),
                caption: nil,
                icon: "tray.full.fill",
                tint: .green
            )
        ]
    }
}

private struct HighlightMetric: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let value: String
    let caption: LocalizedStringKey?
    let icon: String
    let tint: Color
}

private struct QuickMetricTile: View {
    let metric: HighlightMetric

    private var tileSize: CGSize {
        CGSize(width: 192, height: 164)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Circle()
                .fill(metric.tint.opacity(0.18))
                .overlay {
                    Image(systemName: metric.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(metric.tint)
                }
                .frame(width: 42, height: 42)

            Text(metric.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(metric.tint)
                .lineLimit(2)

            Text(metric.value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            if let caption = metric.caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(width: tileSize.width, height: tileSize.height, alignment: .topLeading)
        .moneyCard(
            tint: metric.tint,
            cornerRadius: 24,
            shadow: .compact,
            intensity: .standard
        )
    }
}

private struct BalanceOverviewCard: View {
    let summary: DashboardSummary
    let formatter: (Decimal) -> String
    let icon: String
    let tint: Color

    private var detailColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 120), spacing: 24),
            GridItem(.flexible(minimum: 120), spacing: 24)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Circle()
                    .fill(tint.opacity(0.2))
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    .frame(width: 48, height: 48)
                Text("dashboard.metric.available")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
            }

            Text(formatter(summary.availableToSpend))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Divider()

            LazyVGrid(columns: detailColumns, spacing: 24) {
                detail(
                    title: "dashboard.metric.received",
                    value: formatter(summary.received)
                )
                detail(
                    title: "dashboard.metric.planned",
                    value: formatter(summary.planned)
                )
                detail(
                    title: "dashboard.metric.remaining",
                    value: formatter(summary.remainingToReceive)
                )
                detail(
                    title: "dashboard.metric.salary",
                    value: formatter(summary.salary)
                )
            }
        }
        .padding(24)
        .moneyCard(
            tint: tint,
            cornerRadius: 28,
            shadow: .standard,
            intensity: .prominent
        )
    }

    @ViewBuilder
    private func detail(
        title: LocalizedStringKey,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.none)

            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SpendingBreakdownCard: View {
    let summary: DashboardSummary
    let formatter: (Decimal) -> String

    private var spentText: String {
        formatter(summary.totalExpenses)
    }

    private var fixedText: String {
        formatter(summary.fixedExpenses)
    }

    private var variableText: String {
        formatter(summary.variableExpenses)
    }

    private var extraIncomeText: String {
        formatter(summary.variableIncome)
    }

    private var inflowTotal: Decimal {
        summary.salary + summary.received + summary.variableIncome
    }

    private var inflowText: String {
        formatter(inflowTotal)
    }

    private var spendingRatio: Double {
        guard inflowTotal > .zero else { return .zero }
        let ratio = summary.totalExpenses / inflowTotal
        return Double(truncating: NSDecimalNumber(decimal: ratio))
    }

    private var progressValue: Double {
        min(max(spendingRatio, .zero), 1)
    }

    private var percentText: String {
        guard inflowTotal > .zero else {
            return (0.0).formatted(.percent.precision(.fractionLength(0)))
        }
        return spendingRatio.formatted(.percent.precision(.fractionLength(0)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.pink)
                    .padding(12)
                    .background(Color.pink.opacity(0.15), in: Circle())
                Text(String(localized: "dashboard.metric.expenses"))
                    .font(.headline)
                    .foregroundStyle(.pink)
                Spacer(minLength: 0)
            }

            Text(spentText)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            if inflowTotal > .zero {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(percentText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.pink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.pink.opacity(0.16), in: Capsule())
                        Text("dashboard.metric.spent.caption")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: progressValue)
                        .progressViewStyle(.linear)
                        .tint(.pink)
                }
            }

            HStack(alignment: .center, spacing: 16) {
                totalRow(title: "dashboard.metric.spent.total", value: spentText, tint: .pink)
                Divider()
                totalRow(title: "dashboard.metric.inflow.total", value: inflowText, tint: .green)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                breakdownRow(color: .pink, title: "dashboard.metric.expenses.fixed", value: fixedText)
                breakdownRow(color: .orange, title: "dashboard.metric.expenses.variable", value: variableText)
                Divider().padding(.vertical, 2)
                breakdownRow(color: .green, title: "dashboard.metric.expenses.income", value: extraIncomeText)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .moneyCard(
            tint: .pink,
            cornerRadius: 26,
            shadow: .compact,
            intensity: .prominent
        )
    }

    private func breakdownRow(color: Color, title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: 10, height: 10)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    private func totalRow(title: LocalizedStringKey, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
    }
}
