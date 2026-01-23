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
            .background(AppBackground(variant: .dashboard))
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

            DashboardHeroCard(
                summary: viewModel.summary,
                formatter: viewModel.formatted
            )

            MetricsGrid(
                summary: viewModel.summary,
                formatted: viewModel.formatted
            )

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
                AppEmptyState(
                    icon: "calendar.badge.clock",
                    title: "dashboard.upcoming.empty",
                    message: "dashboard.upcoming.empty.message",
                    style: .minimal
                )
            } else {
                ForEach(viewModel.upcoming) { installment in
                    installmentRow(installment)
                }
            }
        }
    }

    private func installmentRow(_ installment: InstallmentOverview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                installment.status.badge()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyCard(
            tint: installment.status.tintColor,
            cornerRadius: 22,
            shadow: .compact,
            intensity: installment.status.cardIntensity(isOverdue: installment.isOverdue)
        )
        .accessibilityElement(children: .combine)
    }

    private func load() async throws {
        try viewModel.load()
    }

    private func refresh() {
        Task { try await load() }
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
