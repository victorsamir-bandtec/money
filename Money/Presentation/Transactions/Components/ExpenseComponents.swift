import SwiftUI

// MARK: - Fixed Expenses Hero Card

struct FixedExpensesHeroCard: View {
    let metrics: ExpensesViewModel.ExpensesMetrics
    let formatter: CurrencyFormatter
    let coverageText: String?
    let coverageValue: Double?

    private var progressValue: Double? {
        guard let value = coverageValue else { return nil }
        return min(max(value, 0), 1)
    }

    private var remainingTint: Color {
        guard let remaining = metrics.remaining else { return .gray }
        if remaining > 0 { return .appThemeColor }
        if remaining < 0 { return .red }
        return .gray
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HeroHeader(
                tint: .pink,
                icon: "creditcard",
                title: "expenses.metric.total",
                subtitle: "expenses.metric.total.caption"
            )

            Text(formatter.string(from: metrics.totalExpenses))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            if let progressValue, let coverageText {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("expenses.metric.coverage")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(coverageText)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    ProgressView(value: progressValue)
                        .tint(Color.pink)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }

            if let remaining = metrics.remaining {
                HStack(alignment: .top, spacing: 24) {
                    InlineMetric(
                        title: "transactions.fixed.balance",
                        value: formatter.string(from: remaining),
                        icon: remaining >= 0 ? "arrowtriangle.up.circle" : "arrowtriangle.down.circle",
                        tint: remainingTint
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyCard(
            tint: .pink,
            cornerRadius: 28,
            shadow: .standard,
            intensity: .prominent
        )
        .compositingGroup()
    }
}

// MARK: - Expenses Summary Card

struct ExpensesSummaryCard: View {
    @Binding var searchText: String
    @Binding var statusFilter: ExpensesViewModel.StatusFilter
    @Binding var selectedCategory: String?
    @Binding var sortOption: ExpensesViewModel.SortOption
    let categories: [String]
    var onToggleCategory: (String) -> Void
    var onClearFilters: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSearchField.forCategories(text: $searchText, prompt: "expenses.search")
            filterControls
        }
        .padding(.vertical, 8)
    }

    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("expenses.filter.status", selection: $statusFilter) {
                Text(String(localized: "expenses.filter.active")).tag(ExpensesViewModel.StatusFilter.active)
                Text(String(localized: "expenses.filter.all")).tag(ExpensesViewModel.StatusFilter.all)
                Text(String(localized: "expenses.filter.archived")).tag(ExpensesViewModel.StatusFilter.archived)
            }
            .pickerStyle(.segmented)

            HStack {
                Menu {
                    Picker("expenses.filter.sort", selection: $sortOption) {
                        ForEach(ExpensesViewModel.SortOption.allCases, id: \.self) { option in
                            Label(option.localizedTitle, systemImage: option.systemImage)
                                .tag(option)
                        }
                    }
                } label: {
                    Label(sortOption.localizedTitle, systemImage: "arrow.up.arrow.down")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }

                Spacer()

                if hasActiveFilters {
                    Button(String(localized: "common.clear.filters"), action: onClearFilters)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(String(localized: "common.clear.filters"))
                }
            }

            if !categories.isEmpty {
                FilterChipRow(
                    categories: categories,
                    selectedCategory: selectedCategory,
                    onToggle: onToggleCategory
                )
            }
        }
    }

    private var hasActiveFilters: Bool {
        !searchText.isEmpty || selectedCategory != nil || statusFilter != .active || sortOption != .dueDate
    }
}

// MARK: - Expense Card

struct ExpenseCard: View {
    let expense: FixedExpense
    let formatter: CurrencyFormatter
    let dueDate: Date?
    let isOverdue: Bool

    private var categoryText: String? {
        expense.category?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cardTint: Color {
        if !expense.active { return .gray }
        if isOverdue { return .orange }
        return .appThemeColor
    }

    private var cardIntensity: MoneyCardIntensity {
        isOverdue ? .standard : .subtle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(expense.name)
                        .font(.headline.weight(.semibold))
                    if let note = expense.note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text(formatter.string(from: expense.amount))
                    .font(.title3.bold())
            }

            HStack(spacing: 12) {
                if let dueDate {
                    Label {
                        Text(dueDate, format: .dateTime.day(.twoDigits).month(.abbreviated))
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Label(localizedFormat("expenses.due", expense.dueDay), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let categoryText {
                    StatusBadge(categoryText, tint: .cyan, size: .small)
                }

                if !expense.active {
                    StatusBadge("expenses.status.archived", tint: .orange, size: .small)
                } else if isOverdue {
                    StatusBadge("expenses.status.overdue", tint: .red, size: .small)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyCard(
            tint: cardTint,
            cornerRadius: 26,
            shadow: .compact,
            intensity: cardIntensity
        )
    }
}

// MARK: - Expense Detail View

struct ExpenseDetailView: View {
    let expense: FixedExpense
    let formatter: CurrencyFormatter
    let dueDate: Date?
    let isOverdue: Bool
    var onEdit: () -> Void
    var onDuplicate: () -> Void
    var onArchiveToggle: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 42, height: 5)
                .padding(.top, 8)

            VStack(spacing: 12) {
                Text(expense.name)
                    .font(.title3.bold())
                Text(formatter.string(from: expense.amount))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 12) {
                if let dueDate {
                    DetailRow(icon: "calendar", title: dueDate.formatted(date: .abbreviated, time: .omitted))
                } else {
                    DetailRow(icon: "calendar", title: localizedFormat("expenses.due", expense.dueDay))
                }

                if let category = expense.category, !category.isEmpty {
                    DetailRow(icon: "tag", title: category)
                }

                if let note = expense.note, !note.isEmpty {
                    DetailRow(icon: "note.text", title: note)
                }

                if !expense.active {
                    DetailRow(icon: "archivebox", title: String(localized: "expenses.status.archived"))
                } else if isOverdue {
                    DetailRow(icon: "exclamationmark.triangle", title: String(localized: "expenses.status.overdue"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                Button(action: onEdit) {
                    Label(String(localized: "common.edit"), systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onDuplicate) {
                    Label(String(localized: "expenses.duplicate"), systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: onArchiveToggle) {
                    Label(expense.active ? String(localized: "expenses.archive") : String(localized: "expenses.unarchive"), systemImage: expense.active ? "archivebox" : "tray.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)

                Button(role: .destructive, action: onDelete) {
                    Label(String(localized: "common.remove"), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Supporting Components

struct DetailRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Extensions

extension ExpensesViewModel.SortOption {
    var localizedTitle: String {
        switch self {
        case .dueDate:
            return String(localized: "expenses.sort.dueDate")
        case .amountDescending:
            return String(localized: "expenses.sort.amount")
        case .name:
            return String(localized: "expenses.sort.name")
        }
    }

    var systemImage: String {
        switch self {
        case .dueDate:
            return "calendar"
        case .amountDescending:
            return "arrow.down.circle"
        case .name:
            return "textformat"
        }
    }
}
