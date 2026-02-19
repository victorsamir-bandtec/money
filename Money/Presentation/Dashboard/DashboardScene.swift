import SwiftUI
import SwiftData

struct DashboardScene: View {
    @StateObject private var viewModel: DashboardViewModel
    
    init(environment: AppEnvironment, context: ModelContext) {
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                context: context,
                currencyFormatter: environment.currencyFormatter,
                readModel: environment.financialReadModelService,
                eventBus: environment.domainEventBus
            )
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    DashboardHeroCard(
                        summary: viewModel.summary,
                        formatter: viewModel.formatted
                    )

                    VStack(alignment: .leading, spacing: 16) {
                        Text("dashboard.summary")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            MetricCard(
                                title: "dashboard.metric.expenses.fixed",
                                value: viewModel.formatted(viewModel.summary.fixedExpenses),
                                caption: "dashboard.metric.expenses.caption",
                                icon: "house.fill",
                                tint: .expenseRed,
                                layoutMode: .uniform
                            )

                            MetricCard(
                                title: "dashboard.metric.expenses.variable",
                                value: viewModel.formatted(viewModel.summary.variableExpenses),
                                caption: "dashboard.metric.expenses.caption",
                                icon: "cart.fill",
                                tint: .warningOrange,
                                layoutMode: .uniform
                            )

                            MetricCard(
                                title: "dashboard.metric.expenses.income",
                                value: viewModel.formatted(viewModel.summary.variableIncome),
                                icon: "banknote.fill",
                                tint: .seaGreen,
                                layoutMode: .uniform
                            )

                            MetricCard(
                                title: "dashboard.metric.received",
                                value: viewModel.formatted(viewModel.summary.received),
                                caption: "dashboard.metric.received.caption",
                                icon: "arrow.down.circle.fill",
                                tint: .blue,
                                layoutMode: .uniform
                            )
                        }
                    }

                    BudgetProgressView(
                        title: "dashboard.metric.spent.total",
                        caption: "dashboard.metric.spent.caption",
                        current: viewModel.summary.totalExpenses,
                        total: viewModel.summary.totalIncome,
                        color: viewModel.summary.totalExpenses > viewModel.summary.totalIncome ? .overdueRed : .appThemeColor,
                        formatter: viewModel.formatted
                    )

                    UpcomingPaymentsView(
                        title: "dashboard.upcoming",
                        items: viewModel.upcoming.map { item in
                            UpcomingPaymentItem(
                                id: item.id,
                                title: item.displayTitle,
                                subtitle: item.agreementTitle ?? String(localized: "debtor.agreement.untitled"),
                                amount: item.amount,
                                date: item.dueDate,
                                type: .receivable
                            )
                        },
                        formatter: viewModel.formatted
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .animation(.snappy, value: viewModel.summary)
                .animation(.snappy, value: viewModel.upcoming)
            }
            .background(AppBackground(variant: .dashboard))
            .navigationTitle(String(localized: "dashboard.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { try? viewModel.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(String(localized: "dashboard.refresh"))
                }
            }
        }
        .task {
            try? viewModel.load()
        }
        .refreshable {
            try? viewModel.load()
        }
    }
}

// MARK: - Components

fileprivate struct BudgetProgressView: View {
    let title: LocalizedStringKey
    let caption: LocalizedStringKey
    let current: Decimal
    let total: Decimal
    let color: Color
    let formatter: (Decimal) -> String
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        let value = Double(truncating: current as NSNumber) / Double(truncating: total as NSNumber)
        return min(max(value, 0), 1)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(color.opacity(0.2))
                    .overlay {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(color)
                    }
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 12)

                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * CGFloat(progress), height: 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
                }
            }
            .frame(height: 12)

            HStack {
                Text(formatter(current))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatter(total))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .moneyCard(tint: color, cornerRadius: 24, shadow: .compact, intensity: .standard)
    }
}

fileprivate struct UpcomingPaymentItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let amount: Decimal
    let date: Date
    let type: PaymentType
    
    enum PaymentType {
        case receivable
        case payable
    }
}

fileprivate struct UpcomingPaymentsView: View {
    let title: LocalizedStringKey
    let items: [UpcomingPaymentItem]
    let formatter: (Decimal) -> String
    
    var body: some View {
        MoneyCard(tint: .appThemeColor, cornerRadius: 28, shadow: .standard, intensity: .standard) {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if items.isEmpty {
                    AppEmptyState(
                        icon: "checkmark.circle.fill",
                        title: "dashboard.upcoming",
                        message: "dashboard.upcoming.empty",
                        style: .minimal
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 12) {
                        ForEach(items.indices, id: \.self) { index in
                            UpcomingPaymentRow(
                                item: items[index],
                                showDivider: index < items.count - 1,
                                formatter: formatter
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

fileprivate struct UpcomingPaymentRow: View {
    let item: UpcomingPaymentItem
    let showDivider: Bool
    let formatter: (Decimal) -> String

    private var amountColor: Color {
        item.type == .receivable ? .seaGreen : .primary
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(amountColor.opacity(0.2))
                    .overlay {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(amountColor)
                    }
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatter(item.amount))
                        .fontWeight(.semibold)
                        .foregroundStyle(amountColor)

                    Text(item.date, format: .dateTime.day().month())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if showDivider {
                Divider()
                    .opacity(0.2)
            }
        }
        .padding(16)
        .moneyCard(tint: amountColor, cornerRadius: 20, shadow: .compact, intensity: .subtle)
    }
}

#Preview {
    let environment = AppEnvironment(isStoredInMemoryOnly: true)
    let context = environment.modelContext
    try? environment.sampleDataService.populateData()

    return DashboardScene(environment: environment, context: context)
}
