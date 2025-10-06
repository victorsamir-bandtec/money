import SwiftUI
import SwiftData
import Combine

struct ExpensesScene: View {
    @StateObject private var viewModel: ExpensesViewModel
    private let formatter: CurrencyFormatter

    @State private var expenseDraft = ExpenseDraft()
    @State private var formMode: ExpenseFormMode = .create
    @State private var showingExpenseForm = false
    @State private var detailContext: ExpenseDetailContext?

    init(environment: AppEnvironment, context: ModelContext) {
        _viewModel = StateObject(wrappedValue: ExpensesViewModel(context: context))
        self.formatter = environment.currencyFormatter
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                expensesSection
            }
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .background(ExpensesBackground())
            .navigationTitle(String(localized: "expenses.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: presentCreateForm) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "expenses.add"))
                }
            }
        }
        .task { try? viewModel.load() }
        .refreshable { try? viewModel.load() }
        .sheet(isPresented: $showingExpenseForm) {
            ExpenseForm(
                draft: $expenseDraft,
                mode: formMode,
                suggestedCategories: viewModel.availableCategories,
                completion: handleExpenseForm
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .financialDataDidChange)) { _ in
            try? viewModel.load()
        }
        .sheet(item: $detailContext) { context in
            ExpenseDetailView(
                expense: context.expense,
                formatter: formatter,
                dueDate: viewModel.dueDate(for: context.expense),
                isOverdue: viewModel.isOverdue(context.expense),
                onEdit: {
                    presentEditForm(for: context.expense)
                },
                onDuplicate: {
                    viewModel.duplicate(context.expense)
                },
                onArchiveToggle: {
                    viewModel.toggleArchive(context.expense)
                },
                onDelete: {
                    viewModel.removeExpense(context.expense)
                }
            )
            .presentationDetents([.medium, .large])
        }
        .alert(item: Binding(get: {
            viewModel.error.map { LocalizedErrorWrapper(error: $0) }
        }, set: { _ in viewModel.error = nil })) { wrapper in
            Alert(
                title: Text(String(localized: "error.title")),
                message: Text(wrapper.localizedDescription),
                dismissButton: .default(Text(String(localized: "common.ok")))
            )
        }
    }

    private var summarySection: some View {
        Section {
            ExpensesSummaryCard(
                metrics: viewModel.metrics,
                formatter: formatter,
                coverageText: viewModel.formattedCoveragePercentage(),
                searchText: Binding(get: { viewModel.searchText }, set: { viewModel.searchText = $0 }),
                statusFilter: Binding(get: { viewModel.statusFilter }, set: { viewModel.statusFilter = $0 }),
                selectedCategory: Binding(get: { viewModel.selectedCategory }, set: { viewModel.selectedCategory = $0 }),
                sortOption: Binding(get: { viewModel.sortOption }, set: { viewModel.sortOption = $0 }),
                categories: viewModel.availableCategories,
                onToggleCategory: toggleCategory,
                onClearFilters: clearFilters
            )
            .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 32, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private var expensesSection: some View {
        Section {
            if viewModel.filteredExpenses.isEmpty {
                ExpensesEmptyState(
                    hasActiveFilters: hasActiveFilters,
                    onAdd: presentCreateForm
                )
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 40, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.filteredExpenses, id: \.id) { expense in
                    let dueDate = viewModel.dueDate(for: expense)
                    let isOverdue = viewModel.isOverdue(expense)
                    ExpenseCard(
                        expense: expense,
                        formatter: formatter,
                        dueDate: dueDate,
                        isOverdue: isOverdue
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        presentDetail(for: expense)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.removeExpense(expense)
                        } label: {
                            Label(String(localized: "common.remove"), systemImage: "trash")
                        }

                        Button {
                            viewModel.duplicate(expense)
                        } label: {
                            Label(String(localized: "expenses.duplicate"), systemImage: "doc.on.doc")
                        }
                        .tint(.blue)

                        Button {
                            presentEditForm(for: expense)
                        } label: {
                            Label(String(localized: "common.edit"), systemImage: "pencil")
                        }
                        .tint(.indigo)

                        Button {
                            viewModel.toggleArchive(expense)
                        } label: {
                            Label(
                                expense.active ? String(localized: "expenses.archive") : String(localized: "expenses.unarchive"),
                                systemImage: expense.active ? "archivebox" : "tray.and.arrow.up"
                            )
                        }
                        .tint(.orange)
                    }
                }
            }
        } header: {
            Text(String(localized: "expenses.section.list"))
                .font(.headline)
        }
        .headerProminence(.increased)
        .textCase(nil)
    }

    private func presentCreateForm() {
        formMode = .create
        expenseDraft = ExpenseDraft()
        showingExpenseForm = true
    }

    private func presentEditForm(for expense: FixedExpense) {
        formMode = .edit(expense)
        expenseDraft = ExpenseDraft(expense: expense)
        showingExpenseForm = true
    }

    private func presentDetail(for expense: FixedExpense) {
        detailContext = ExpenseDetailContext(expense: expense)
    }

    private func handleExpenseForm(_ result: ExpenseForm.ResultAction) {
        switch result {
        case .save(let draft):
            switch formMode {
            case .create:
                viewModel.addExpense(
                    name: draft.name,
                    amount: draft.amount,
                    category: draft.category,
                    dueDay: draft.dueDay,
                    note: draft.note
                )
            case .edit(let expense):
                viewModel.updateExpense(
                    expense,
                    name: draft.name,
                    amount: draft.amount,
                    category: draft.category,
                    dueDay: draft.dueDay,
                    note: draft.note
                )
            }
            showingExpenseForm = false
        case .cancel:
            showingExpenseForm = false
        }
    }

    private func toggleCategory(_ category: String) {
        if viewModel.selectedCategory?.localizedCaseInsensitiveCompare(category) == .orderedSame {
            viewModel.selectedCategory = nil
        } else {
            viewModel.selectedCategory = category
        }
    }

    private func clearFilters() {
        viewModel.searchText = ""
        viewModel.selectedCategory = nil
        viewModel.sortOption = .dueDate
        viewModel.statusFilter = .active
    }

    private var hasActiveFilters: Bool {
        !viewModel.searchText.isEmpty || viewModel.selectedCategory != nil || viewModel.statusFilter != .active || viewModel.sortOption != .dueDate
    }
}

private enum ExpenseFormMode {
    case create
    case edit(FixedExpense)

    var navigationTitle: LocalizedStringKey {
        switch self {
        case .create:
            return "expenses.form.title"
        case .edit:
            return "expenses.form.edit.title"
        }
    }
}

private struct ExpenseDetailContext: Identifiable {
    let expense: FixedExpense
    var id: UUID { expense.id }
}

private struct ExpensesSummaryCard: View {
    let metrics: ExpensesViewModel.ExpensesMetrics
    let formatter: CurrencyFormatter
    let coverageText: String?
    @Binding var searchText: String
    @Binding var statusFilter: ExpensesViewModel.StatusFilter
    @Binding var selectedCategory: String?
    @Binding var sortOption: ExpensesViewModel.SortOption
    let categories: [String]
    var onToggleCategory: (String) -> Void
    var onClearFilters: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            metricsGrid
            SearchField(text: $searchText)
            filterControls
        }
        .padding(.horizontal, 4)
    }

    private var metricsGrid: some View {
        VStack(spacing: 16) {
            MetricCard(
                title: "expenses.metric.total",
                value: formatter.string(from: metrics.totalExpenses),
                caption: "expenses.metric.total.caption",
                icon: "creditcard.fill",
                tint: .pink,
                style: .prominent
            )

            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                MetricCard(
                    title: "expenses.metric.salary",
                    value: metrics.salaryAmount.map { formatter.string(from: $0) } ?? String(localized: "expenses.metric.salary.empty"),
                    caption: "expenses.metric.salary.caption",
                    icon: "dollarsign.arrow.circlepath",
                    tint: .purple
                )

                MetricCard(
                    title: "expenses.metric.remaining",
                    value: metrics.remaining.map { formatter.string(from: $0) } ?? "--",
                    caption: "expenses.metric.remaining.caption",
                    icon: "chart.line.uptrend.xyaxis",
                    tint: .green
                )
            }

            if let coverageText {
                MetricCard(
                    title: "expenses.metric.coverage",
                    value: coverageText,
                    caption: "expenses.metric.coverage.caption",
                    icon: "percent",
                    tint: .blue
                )
            }
        }
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

            if categories.isEmpty {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categories, id: \.self) { category in
                            CategoryChip(
                                text: category,
                                isSelected: selectedCategory?.localizedCaseInsensitiveCompare(category) == .orderedSame,
                                action: { onToggleCategory(category) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var hasActiveFilters: Bool {
        !searchText.isEmpty || selectedCategory != nil || statusFilter != .active || sortOption != .dueDate
    }
}

private struct ExpenseCard: View {
    let expense: FixedExpense
    let formatter: CurrencyFormatter
    let dueDate: Date?
    let isOverdue: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var categoryText: String? {
        expense.category?.trimmingCharacters(in: .whitespacesAndNewlines)
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
                    StatusChip(
                        text: categoryText,
                        systemImage: "tag",
                        tint: .cyan
                    )
                }

                if !expense.active {
                    StatusChip(text: String(localized: "expenses.status.archived"), systemImage: "archivebox", tint: .orange)
                } else if isOverdue {
                    StatusChip(text: String(localized: "expenses.status.overdue"), systemImage: "exclamationmark.triangle.fill", tint: .red)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.12))
        )
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.05)
            : Color.black.opacity(0.04)
    }
}

private struct StatusChip: View {
    let text: String
    let systemImage: String
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(colorScheme == .dark ? 0.18 : 0.12))
            )
            .foregroundStyle(foregroundColor)
    }

    private var foregroundColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.9)
            : tint
    }
}

private struct CategoryChip: View {
    let text: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.08))
                )
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct ExpensesEmptyState: View {
    var hasActiveFilters: Bool
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle" : "creditcard" )
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text(hasActiveFilters ? String(localized: "expenses.empty.filtered") : String(localized: "expenses.empty"))
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(String(localized: "expenses.empty.message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onAdd) {
                Text(String(localized: "expenses.add"))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            GlassBackgroundStyle.current.material,
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }
}

private struct ExpenseDetailView: View {
    let expense: FixedExpense
    let formatter: CurrencyFormatter
    let dueDate: Date?
    let isOverdue: Bool
    var onEdit: () -> Void
    var onDuplicate: () -> Void
    var onArchiveToggle: () -> Void
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "expenses.detail.summary")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(expense.name)
                            .font(.headline)
                        Text(formatter.string(from: expense.amount))
                            .font(.title3.bold())
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
                    .padding(.vertical, 8)
                }

                Section(String(localized: "expenses.detail.actions")) {
                    Button(String(localized: "common.edit"), action: { dismiss(); onEdit() })
                    Button(String(localized: "expenses.duplicate"), action: onDuplicate)
                    Button(expense.active ? String(localized: "expenses.archive") : String(localized: "expenses.unarchive"), action: onArchiveToggle)
                        .foregroundStyle(.orange)
                    Button(role: .destructive, action: { dismiss(); onDelete() }) {
                        Text(String(localized: "common.remove"))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "expenses.detail.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) { dismiss() }
                }
            }
        }
    }
}

private struct DetailRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(title)
                .foregroundStyle(.primary)
        }
    }
}

private struct SearchField: View {
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(String(localized: "expenses.search"), text: $text)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "expenses.search.clear"))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(strokeColor)
        )
    }

    private var fillColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.05)
    }

    private var strokeColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }
}

private struct ExpensesBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(colorScheme == .dark ? 1 : 0.6)
            RadialGradient(
                colors: [Color.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.12), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.07, green: 0.09, blue: 0.16),
                Color(red: 0.02, green: 0.03, blue: 0.07)
            ]
        }
        return [
            Color(.systemGroupedBackground),
            Color(.secondarySystemGroupedBackground)
        ]
    }
}

private struct ExpenseDraft: Equatable {
    var name: String = ""
    var amount: Decimal = .zero
    var category: String = ""
    var dueDay: Int = 5
    var note: String = ""

    init() {}

    init(expense: FixedExpense) {
        name = expense.name
        amount = expense.amount
        category = expense.category ?? ""
        dueDay = expense.dueDay
        note = expense.note ?? ""
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0 && (1...31).contains(dueDay)
    }
}

private struct ExpenseForm: View {
    @Binding var draft: ExpenseDraft
    let mode: ExpenseFormMode
    let suggestedCategories: [String]
    var completion: (ResultAction) -> Void
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case amount
        case category
        case note
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "expenses.form.details")) {
                    TextField(String(localized: "expenses.form.name"), text: $draft.name)
                        .focused($focusedField, equals: .name)
                    TextField(String(localized: "expenses.form.amount"), value: $draft.amount, format: .currency(code: Locale.current.currency?.identifier ?? "BRL"))
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                    Stepper(value: $draft.dueDay, in: 1...31) {
                        Text(localizedFormat("expenses.form.dueDay", draft.dueDay))
                    }
                }

                Section(String(localized: "expenses.form.category")) {
                    TextField(String(localized: "expenses.form.category.placeholder"), text: $draft.category)
                        .focused($focusedField, equals: .category)
                    if !suggestedCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(suggestedCategories, id: \.self) { category in
                                    CategoryChip(
                                        text: category,
                                        isSelected: draft.category.localizedCaseInsensitiveCompare(category) == .orderedSame
                                    ) {
                                        draft.category = category
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section(String(localized: "expenses.form.note")) {
                    TextField(String(localized: "expenses.form.note.placeholder"), text: $draft.note, axis: .vertical)
                        .focused($focusedField, equals: .note)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(mode.navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { completion(.cancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) { completion(.save(draft)) }
                        .disabled(!draft.isValid)
                }
            }
        }
    }

    enum ResultAction {
        case save(ExpenseDraft)
        case cancel
    }
}

private struct LocalizedErrorWrapper: Identifiable {
    let id = UUID()
    let error: AppError

    var localizedDescription: String {
        error.errorDescription ?? ""
    }
}

private extension ExpensesViewModel.SortOption {
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .dueDate:
            return "expenses.sort.dueDate"
        case .amountDescending:
            return "expenses.sort.amount"
        case .name:
            return "expenses.sort.name"
        }
    }

    var systemImage: String {
        switch self {
        case .dueDate:
            return "calendar"
        case .amountDescending:
            return "dollarsign"
        case .name:
            return "textformat"
        }
    }
}
