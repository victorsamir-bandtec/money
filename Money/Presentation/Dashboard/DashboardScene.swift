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

    private var summaryColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
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

            MetricCard(
                title: "dashboard.metric.balance",
                value: viewModel.formatted(viewModel.summary.netBalance),
                caption: "dashboard.metric.balance.caption",
                icon: "chart.line.uptrend.xyaxis",
                tint: .blue,
                style: .prominent
            )

            LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 16) {
                MetricCard(
                    title: "dashboard.metric.income",
                    value: viewModel.formatted(viewModel.summary.monthIncome),
                    caption: "dashboard.metric.income.caption",
                    icon: "tray.and.arrow.down.fill",
                    tint: .green
                )
                MetricCard(
                    title: "dashboard.metric.received",
                    value: viewModel.formatted(viewModel.summary.received),
                    caption: "dashboard.metric.received.caption",
                    icon: "checkmark.seal.fill",
                    tint: .teal
                )
                MetricCard(
                    title: "dashboard.metric.overdue",
                    value: viewModel.formatted(viewModel.summary.overdue),
                    caption: "dashboard.metric.overdue.caption",
                    icon: "exclamationmark.triangle.fill",
                    tint: .orange
                )
                MetricCard(
                    title: "dashboard.metric.expenses",
                    value: viewModel.formatted(viewModel.summary.fixedExpenses),
                    caption: "dashboard.metric.expenses.caption",
                    icon: "creditcard.fill",
                    tint: .pink
                )
            }
            MetricCard(
                title: "dashboard.metric.salary",
                value: viewModel.formatted(viewModel.summary.salary),
                caption: "dashboard.metric.salary.caption",
                icon: "dollarsign.arrow.circlepath",
                tint: .purple
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
                ForEach(viewModel.upcoming, id: \.id) { installment in
                    installmentRow(installment)
                }
            }
        }
    }

    private func installmentRow(_ installment: Installment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(installment.agreement.title ?? installment.agreement.debtor.name)
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
        .glassBackground()
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
}
