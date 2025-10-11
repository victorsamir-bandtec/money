import SwiftUI

// MARK: - Transaction Hero Card

struct VariableHeroCard: View {
    let metrics: TransactionsViewModel.TransactionsMetrics
    let formatter: CurrencyFormatter

    private var tint: Color { metrics.netBalance >= .zero ? .appThemeColor : .red }
    private var icon: String { metrics.netBalance >= .zero ? "arrow.up.right" : "arrow.down.left" }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HeroHeader(
                tint: tint,
                icon: icon,
                title: "transactions.metric.balance",
                subtitle: "transactions.metric.balance.caption"
            )

            Text(formatter.string(from: metrics.netBalance))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Divider()
                .background(Color.primary.opacity(0.06))

            HStack(alignment: .top, spacing: 24) {
                InlineMetric(
                    title: "transactions.metric.expenses",
                    value: formatter.string(from: metrics.totalExpenses),
                    icon: "arrow.up.circle",
                    tint: .pink
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                InlineMetric(
                    title: "transactions.metric.income",
                    value: formatter.string(from: metrics.totalIncome),
                    icon: "arrow.down.circle",
                    tint: .appThemeColor
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyCard(
            tint: tint,
            cornerRadius: 28,
            shadow: .standard,
            intensity: .prominent
        )
        .compositingGroup()
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: CashTransaction
    let formatter: CurrencyFormatter

    private var amountText: String {
        formatter.string(from: transaction.amount)
    }

    private var amountColor: Color {
        transaction.type == .income ? .green : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.category ?? String(localized: transaction.type.titleKey))
                        .font(.headline)
                    if let note = transaction.note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text(amountText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(amountColor)
            }

            HStack(spacing: 12) {
                Label(transaction.type == .income ? String(localized: "transactions.type.income") : String(localized: "transactions.type.expense"), systemImage: transaction.type == .income ? "arrow.down.circle" : "arrow.up.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(amountColor.opacity(0.8))

                Label {
                    Text(transaction.date, style: .time)
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyCard(
            tint: amountColor,
            cornerRadius: 22,
            shadow: .compact,
            intensity: .subtle
        )
        .compositingGroup()
    }
}

// MARK: - Transactions Summary Card

struct TransactionsSummaryCard: View {
    @Binding var typeFilter: TransactionsViewModel.TypeFilter
    @Binding var sortOrder: TransactionsViewModel.SortOrder
    @Binding var categoryFilter: String?
    let categories: [String]
    let hasActiveFilters: Bool
    let clearFilters: () -> Void
    let toggleCategory: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("transactions.filter.type", selection: $typeFilter) {
                Text(String(localized: "transactions.filter.all")).tag(TransactionsViewModel.TypeFilter.all)
                Text(String(localized: "transactions.filter.expense")).tag(TransactionsViewModel.TypeFilter.expenses)
                Text(String(localized: "transactions.filter.income")).tag(TransactionsViewModel.TypeFilter.income)
            }
            .pickerStyle(.segmented)

            HStack {
                Menu {
                    Picker("transactions.sort.title", selection: $sortOrder) {
                        ForEach(TransactionsViewModel.SortOrder.allCases, id: \.self) { option in
                            Label(option.localizedTitle, systemImage: option.systemImage).tag(option)
                        }
                    }
                } label: {
                    Label(sortOrder.localizedTitle, systemImage: "arrow.up.arrow.down.circle")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }

                Spacer()

                if hasActiveFilters {
                    Button(String(localized: "common.clear.filters"), action: clearFilters)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if !categories.isEmpty {
                FilterChipRow(
                    categories: categories,
                    selectedCategory: categoryFilter,
                    onToggle: toggleCategory
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyCard(
            tint: .appThemeColor,
            cornerRadius: 26,
            shadow: .compact,
            intensity: .subtle
        )
        .compositingGroup()
    }
}

// MARK: - Supporting Components

struct InlineMetric: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            } icon: {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}

struct HeroHeader: View {
    let tint: Color
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
