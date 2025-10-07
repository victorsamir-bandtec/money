import SwiftUI
import SwiftData

struct TransactionsScene: View {
    @StateObject private var viewModel: TransactionsViewModel
    private let formatter: CurrencyFormatter

    @State private var draft = TransactionDraft()
    @State private var formMode: TransactionFormMode = .create
    @State private var showingForm = false

    init(environment: AppEnvironment, context: ModelContext) {
        _viewModel = StateObject(wrappedValue: TransactionsViewModel(context: context))
        self.formatter = environment.currencyFormatter
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                transactionsSection
            }
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "transactions.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: presentCreateForm) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "transactions.add"))
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: String(localized: "transactions.search"))
        .task { try? viewModel.load() }
        .refreshable { try? viewModel.load() }
        .sheet(isPresented: $showingForm) {
            TransactionForm(
                draft: $draft,
                mode: formMode,
                categories: viewModel.availableCategories,
                completion: handleFormResult
            )
        }
        .appErrorAlert(errorBinding)
    }

    private var summarySection: some View {
        Section {
            TransactionsSummaryCard(
                metrics: viewModel.metrics,
                formatter: formatter,
                typeFilter: Binding(get: { viewModel.typeFilter }, set: { viewModel.typeFilter = $0 }),
                sortOrder: Binding(get: { viewModel.sortOrder }, set: { viewModel.sortOrder = $0 }),
                categoryFilter: Binding(get: { viewModel.categoryFilter }, set: { viewModel.categoryFilter = $0 }),
                categories: viewModel.availableCategories,
                hasActiveFilters: hasActiveFilters,
                clearFilters: clearFilters,
                toggleCategory: toggleCategory
            )
            .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 32, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private var transactionsSection: some View {
        Group {
            if viewModel.sections.isEmpty {
                ContentUnavailableView(
                    String(localized: "transactions.empty.title"),
                    systemImage: "tray",
                    description: Text(String(localized: "transactions.empty.description"))
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowInsets(EdgeInsets(top: 40, leading: 16, bottom: 80, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.transactions, id: \.id) { transaction in
                            TransactionRow(
                                transaction: transaction,
                                formatter: formatter
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                presentEditForm(for: transaction)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.removeTransaction(transaction)
                                } label: {
                                    Label(String(localized: "common.remove"), systemImage: "trash")
                                }

                                Button {
                                    presentEditForm(for: transaction)
                                } label: {
                                    Label(String(localized: "common.edit"), systemImage: "pencil")
                                }
                                .tint(.indigo)
                            }
                        }
                    } header: {
                        Text(section.date, format: .dateTime.day().month().year())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var errorBinding: Binding<AppError?> {
        Binding(
            get: { viewModel.error },
            set: { viewModel.error = $0 }
        )
    }

    private func presentCreateForm() {
        formMode = .create
        draft = TransactionDraft()
        showingForm = true
    }

    private func presentEditForm(for transaction: CashTransaction) {
        formMode = .edit(transaction)
        draft = TransactionDraft(transaction: transaction)
        showingForm = true
    }

    private func handleFormResult(_ result: TransactionForm.ResultAction) {
        switch result {
        case .save(let draft):
            switch formMode {
            case .create:
                viewModel.addTransaction(
                    date: draft.date,
                    amount: draft.amount,
                    type: draft.type,
                    category: draft.category,
                    note: draft.note
                )
            case .edit(let transaction):
                viewModel.updateTransaction(
                    transaction,
                    date: draft.date,
                    amount: draft.amount,
                    type: draft.type,
                    category: draft.category,
                    note: draft.note
                )
            }
            showingForm = false
        case .cancel:
            showingForm = false
        }
    }

    private func toggleCategory(_ category: String) {
        if viewModel.categoryFilter?.localizedCaseInsensitiveCompare(category) == .orderedSame {
            viewModel.categoryFilter = nil
        } else {
            viewModel.categoryFilter = category
        }
    }

    private func clearFilters() {
        viewModel.categoryFilter = nil
        viewModel.searchText = ""
        viewModel.typeFilter = .all
        viewModel.sortOrder = .dateDescending
    }

    private var hasActiveFilters: Bool {
        viewModel.categoryFilter != nil ||
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        viewModel.typeFilter != .all ||
        viewModel.sortOrder != .dateDescending
    }
}

private enum TransactionFormMode {
    case create
    case edit(CashTransaction)

    var titleKey: LocalizedStringKey {
        switch self {
        case .create:
            return "transactions.form.title"
        case .edit:
            return "transactions.form.edit"
        }
    }
}

private struct TransactionRow: View {
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
        .glassBackground()
    }
}

private struct TransactionsSummaryCard: View {
    let metrics: TransactionsViewModel.TransactionsMetrics
    let formatter: CurrencyFormatter
    @Binding var typeFilter: TransactionsViewModel.TypeFilter
    @Binding var sortOrder: TransactionsViewModel.SortOrder
    @Binding var categoryFilter: String?
    let categories: [String]
    let hasActiveFilters: Bool
    let clearFilters: () -> Void
    let toggleCategory: (String) -> Void

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            MetricCard(
                title: "transactions.metric.balance",
                value: formatter.string(from: metrics.netBalance),
                caption: "transactions.metric.balance.caption",
                icon: metrics.netBalance >= .zero ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                tint: metrics.netBalance >= .zero ? .blue : .red,
                style: .prominent
            )

            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                MetricCard(
                    title: "transactions.metric.expenses",
                    value: formatter.string(from: metrics.totalExpenses),
                    caption: "transactions.metric.expenses.caption",
                    icon: "arrow.up.circle.fill",
                    tint: .pink
                )

                MetricCard(
                    title: "transactions.metric.income",
                    value: formatter.string(from: metrics.totalIncome),
                    caption: "transactions.metric.income.caption",
                    icon: "arrow.down.circle.fill",
                    tint: .green
                )
            }

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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categories, id: \.self) { category in
                            FilterChip(
                                title: category,
                                isSelected: categoryFilter?.localizedCaseInsensitiveCompare(category) == .orderedSame,
                                action: { toggleCategory(category) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground), in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.accentColor.opacity(isSelected ? 0.6 : 0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
    }
}

private struct TransactionForm: View {
    @Binding var draft: TransactionDraft
    let mode: TransactionFormMode
    let categories: [String]
    let completion: (ResultAction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "transactions.form.section.basic")) {
                    DatePicker(String(localized: "transactions.form.date"), selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                    Picker(String(localized: "transactions.form.type"), selection: $draft.type) {
                        ForEach(CashTransactionType.allCases, id: \.self) { type in
                            Text(String(localized: type.titleKey)).tag(type)
                        }
                    }
                    TextField(String(localized: "transactions.form.amount"), value: $draft.amount, format: .currency(code: Locale.current.currency?.identifier ?? "BRL"))
                        .keyboardType(.decimalPad)
                }

                Section(String(localized: "transactions.form.details")) {
                    TextField(String(localized: "transactions.form.category"), text: $draft.category)
                    if !categories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(categories, id: \.self) { category in
                                    FilterChip(
                                        title: category,
                                        isSelected: draft.category.localizedCaseInsensitiveCompare(category) == .orderedSame,
                                        action: { draft.category = category }
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets())
                    }
                    TextField(String(localized: "transactions.form.note"), text: $draft.note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(mode.titleKey)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        completion(.cancel)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        completion(.save(draft))
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
    }

    enum ResultAction {
        case save(TransactionDraft)
        case cancel
    }
}

private struct TransactionDraft: Equatable {
    var date: Date = .now
    var amount: Decimal = .zero
    var type: CashTransactionType = .expense
    var category: String = ""
    var note: String = ""

    init() {}

    init(transaction: CashTransaction) {
        date = transaction.date
        amount = transaction.amount
        type = transaction.type
        category = transaction.category ?? ""
        note = transaction.note ?? ""
    }

    var isValid: Bool { amount > 0 }
}
