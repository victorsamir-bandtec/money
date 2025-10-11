import SwiftUI
import SwiftData

struct TransactionsScene: View {
    enum Mode: Hashable, CaseIterable {
        case variableFlow
        case fixedExpenses

        var pickerTitleKey: String {
            switch self {
            case .variableFlow: return "transactions.mode.variable"
            case .fixedExpenses: return "transactions.mode.fixed"
            }
        }

        var searchPromptKey: String {
            switch self {
            case .variableFlow: return "transactions.search"
            case .fixedExpenses: return "expenses.search"
            }
        }

        var addAccessibilityKey: String {
            switch self {
            case .variableFlow: return "transactions.add"
            case .fixedExpenses: return "expenses.add"
            }
        }

        var pickerTitle: LocalizedStringKey { LocalizedStringKey(pickerTitleKey) }
        var searchPrompt: LocalizedStringKey { LocalizedStringKey(searchPromptKey) }
    }

    @StateObject private var transactionsViewModel: TransactionsViewModel
    @StateObject private var expensesViewModel: ExpensesViewModel
    private let formatter: CurrencyFormatter

    @State private var mode: Mode = .variableFlow

    @State private var transactionDraft = TransactionDraft()
    @State private var transactionFormMode: TransactionFormMode = .create
    @State private var showingTransactionForm = false

    @State private var expenseDraft = ExpenseDraft()
    @State private var expenseFormMode: ExpenseFormMode = .create
    @State private var showingExpenseForm = false
    @State private var expenseDetailContext: ExpenseDetailContext?

    init(environment: AppEnvironment, context: ModelContext) {
        _transactionsViewModel = StateObject(wrappedValue: TransactionsViewModel(context: context))
        _expensesViewModel = StateObject(wrappedValue: ExpensesViewModel(context: context))
        self.formatter = environment.currencyFormatter
    }

    var body: some View {
        NavigationStack {
            List {
                modeSection
                if mode == .variableFlow {
                    transactionsSummarySection
                    transactionsListSection
                } else {
                    expensesSummarySection
                    expensesListSection
                }
            }
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .background(AppBackground(variant: .transactions))
            .navigationTitle(String(localized: "transactions.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addAction) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(NSLocalizedString(mode.addAccessibilityKey, comment: ""))
                }
            }
        }
        .searchable(text: searchBinding, prompt: Text(mode.searchPrompt))
        .task { loadData() }
        .refreshable { loadData() }
        .sheet(isPresented: $showingTransactionForm) {
            TransactionForm(
                draft: $transactionDraft,
                mode: transactionFormMode,
                categories: transactionsViewModel.availableCategories,
                completion: handleTransactionFormResult
            )
        }
        .sheet(isPresented: $showingExpenseForm) {
            ExpenseForm(
                draft: $expenseDraft,
                mode: expenseFormMode,
                suggestedCategories: expensesViewModel.availableCategories,
                completion: handleExpenseFormResult
            )
        }
        .sheet(item: $expenseDetailContext) { context in
            ExpenseDetailView(
                expense: context.expense,
                formatter: formatter,
                dueDate: expensesViewModel.dueDate(for: context.expense),
                isOverdue: expensesViewModel.isOverdue(context.expense),
                onEdit: { presentEditExpenseForm(for: context.expense) },
                onDuplicate: { expensesViewModel.duplicate(context.expense) },
                onArchiveToggle: { expensesViewModel.toggleArchive(context.expense) },
                onDelete: { expensesViewModel.removeExpense(context.expense) }
            )
            .presentationDetents([.medium, .large])
        }
        .onReceive(NotificationCenter.default.publisher(for: .financialDataDidChange)) { _ in
            try? expensesViewModel.load()
        }
        .appErrorAlert(errorBinding)
    }

    // MARK: - View Sections

    private var modeSection: some View {
        Section {
            TransactionsHeader(
                mode: $mode,
                formatter: formatter,
                cashMetrics: transactionsViewModel.metrics,
                fixedMetrics: expensesViewModel.metrics,
                coverageText: expensesViewModel.formattedCoveragePercentage(),
                coverageValue: expensesViewModel.metrics.coverage
            )
            .listRowBackground(Color.clear)
        }
        .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 20, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var transactionsSummarySection: some View {
        Section {
            TransactionsSummaryCard(
                typeFilter: Binding(get: { transactionsViewModel.typeFilter }, set: { transactionsViewModel.typeFilter = $0 }),
                sortOrder: Binding(get: { transactionsViewModel.sortOrder }, set: { transactionsViewModel.sortOrder = $0 }),
                categoryFilter: Binding(get: { transactionsViewModel.categoryFilter }, set: { transactionsViewModel.categoryFilter = $0 }),
                categories: transactionsViewModel.availableCategories,
                hasActiveFilters: transactionsHasActiveFilters,
                clearFilters: clearTransactionFilters,
                toggleCategory: toggleTransactionCategory
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 24, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private var transactionsListSection: some View {
        Group {
            if transactionsViewModel.sections.isEmpty {
                AppEmptyState(
                    icon: "tray",
                    title: "transactions.empty.title",
                    message: "transactions.empty.description",
                    style: .minimal
                )
                .listRowInsets(EdgeInsets(top: 40, leading: 16, bottom: 80, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(transactionsViewModel.sections) { section in
                    Section {
                        ForEach(section.transactions, id: \.id) { transaction in
                            TransactionRow(
                                transaction: transaction,
                                formatter: formatter
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                presentEditTransactionForm(for: transaction)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    transactionsViewModel.removeTransaction(transaction)
                                } label: {
                                    Label(String(localized: "common.remove"), systemImage: "trash")
                                }

                                Button {
                                    presentEditTransactionForm(for: transaction)
                                } label: {
                                    Label(String(localized: "common.edit"), systemImage: "pencil")
                                }
                                .tint(.indigo)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
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

    private var expensesSummarySection: some View {
        Section {
            ExpensesSummaryCard(
                searchText: Binding(get: { expensesViewModel.searchText }, set: { expensesViewModel.searchText = $0 }),
                statusFilter: Binding(get: { expensesViewModel.statusFilter }, set: { expensesViewModel.statusFilter = $0 }),
                selectedCategory: Binding(get: { expensesViewModel.selectedCategory }, set: { expensesViewModel.selectedCategory = $0 }),
                sortOption: Binding(get: { expensesViewModel.sortOption }, set: { expensesViewModel.sortOption = $0 }),
                categories: expensesViewModel.availableCategories,
                onToggleCategory: toggleExpenseCategory,
                onClearFilters: clearExpenseFilters
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 24, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private var expensesListSection: some View {
        Section {
            if expensesViewModel.filteredExpenses.isEmpty {
                AppEmptyState(
                    icon: expensesHasActiveFilters ? "line.3.horizontal.decrease.circle" : "creditcard",
                    title: expensesHasActiveFilters ? "expenses.empty.filtered" : "expenses.empty",
                    message: "expenses.empty.message",
                    actionTitle: "expenses.add",
                    action: presentCreateExpenseForm
                )
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 40, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(expensesViewModel.filteredExpenses, id: \.id) { expense in
                    let dueDate = expensesViewModel.dueDate(for: expense)
                    let isOverdue = expensesViewModel.isOverdue(expense)
                    ExpenseCard(
                        expense: expense,
                        formatter: formatter,
                        dueDate: dueDate,
                        isOverdue: isOverdue
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        presentExpenseDetail(for: expense)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            expensesViewModel.removeExpense(expense)
                        } label: {
                            Label(String(localized: "common.remove"), systemImage: "trash")
                        }

                        Button {
                            expensesViewModel.duplicate(expense)
                        } label: {
                            Label(String(localized: "expenses.duplicate"), systemImage: "doc.on.doc")
                        }
                        .tint(.blue)

                        Button {
                            presentEditExpenseForm(for: expense)
                        } label: {
                            Label(String(localized: "common.edit"), systemImage: "pencil")
                        }
                        .tint(.indigo)

                        Button {
                            expensesViewModel.toggleArchive(expense)
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

    // MARK: - Helper Properties

    private var transactionsHasActiveFilters: Bool {
        transactionsViewModel.categoryFilter != nil ||
        transactionsViewModel.searchText.isNotBlank ||
        transactionsViewModel.typeFilter != .all ||
        transactionsViewModel.sortOrder != .dateDescending
    }

    private var expensesHasActiveFilters: Bool {
        !expensesViewModel.searchText.isEmpty ||
        expensesViewModel.selectedCategory != nil ||
        expensesViewModel.statusFilter != .active ||
        expensesViewModel.sortOption != .dueDate
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: {
                switch mode {
                case .variableFlow: return transactionsViewModel.searchText
                case .fixedExpenses: return expensesViewModel.searchText
                }
            },
            set: { newValue in
                switch mode {
                case .variableFlow: transactionsViewModel.searchText = newValue
                case .fixedExpenses: expensesViewModel.searchText = newValue
                }
            }
        )
    }

    private var errorBinding: Binding<AppError?> {
        Binding(
            get: { expensesViewModel.error ?? transactionsViewModel.error },
            set: { newValue in
                expensesViewModel.error = newValue
                transactionsViewModel.error = newValue
            }
        )
    }

    // MARK: - Actions

    private func toggleTransactionCategory(_ category: String) {
        if transactionsViewModel.categoryFilter?.localizedCaseInsensitiveCompare(category) == .orderedSame {
            transactionsViewModel.categoryFilter = nil
        } else {
            transactionsViewModel.categoryFilter = category
        }
    }

    private func clearTransactionFilters() {
        transactionsViewModel.categoryFilter = nil
        transactionsViewModel.searchText = ""
        transactionsViewModel.typeFilter = .all
        transactionsViewModel.sortOrder = .dateDescending
    }

    private func toggleExpenseCategory(_ category: String) {
        if expensesViewModel.selectedCategory?.localizedCaseInsensitiveCompare(category) == .orderedSame {
            expensesViewModel.selectedCategory = nil
        } else {
            expensesViewModel.selectedCategory = category
        }
    }

    private func clearExpenseFilters() {
        expensesViewModel.searchText = ""
        expensesViewModel.selectedCategory = nil
        expensesViewModel.sortOption = .dueDate
        expensesViewModel.statusFilter = .active
    }

    private func addAction() {
        switch mode {
        case .variableFlow: presentCreateTransactionForm()
        case .fixedExpenses: presentCreateExpenseForm()
        }
    }

    private func presentCreateTransactionForm() {
        transactionFormMode = .create
        transactionDraft = TransactionDraft()
        showingTransactionForm = true
    }

    private func presentEditTransactionForm(for transaction: CashTransaction) {
        transactionFormMode = .edit(transaction)
        transactionDraft = TransactionDraft(transaction: transaction)
        showingTransactionForm = true
    }

    private func handleTransactionFormResult(_ result: TransactionForm.ResultAction) {
        switch result {
        case .save(let draft):
            switch transactionFormMode {
            case .create:
                transactionsViewModel.addTransaction(
                    date: draft.date,
                    amount: draft.amount,
                    type: draft.type,
                    category: draft.category,
                    note: draft.note
                )
            case .edit(let transaction):
                transactionsViewModel.updateTransaction(
                    transaction,
                    date: draft.date,
                    amount: draft.amount,
                    type: draft.type,
                    category: draft.category,
                    note: draft.note
                )
            }
            showingTransactionForm = false
        case .cancel:
            showingTransactionForm = false
        }
    }

    private func presentCreateExpenseForm() {
        expenseFormMode = .create
        expenseDraft = ExpenseDraft()
        showingExpenseForm = true
    }

    private func presentEditExpenseForm(for expense: FixedExpense) {
        expenseFormMode = .edit(expense)
        expenseDraft = ExpenseDraft(expense: expense)
        showingExpenseForm = true
    }

    private func presentExpenseDetail(for expense: FixedExpense) {
        expenseDetailContext = ExpenseDetailContext(expense: expense)
    }

    private func handleExpenseFormResult(_ result: ExpenseForm.ResultAction) {
        switch result {
        case .save(let draft):
            switch expenseFormMode {
            case .create:
                expensesViewModel.addExpense(
                    name: draft.name,
                    amount: draft.amount,
                    category: draft.category,
                    dueDay: draft.dueDay,
                    note: draft.note
                )
            case .edit(let expense):
                expensesViewModel.updateExpense(
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

    private func loadData() {
        let referenceDate = Date()
        try? transactionsViewModel.load(for: referenceDate)
        try? expensesViewModel.load(currentMonth: referenceDate)
    }
}

// MARK: - Header Component

private struct TransactionsHeader: View {
    @Binding var mode: TransactionsScene.Mode
    let formatter: CurrencyFormatter
    let cashMetrics: TransactionsViewModel.TransactionsMetrics
    let fixedMetrics: ExpensesViewModel.ExpensesMetrics
    let coverageText: String?
    let coverageValue: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Picker(String(localized: "transactions.mode.switcher.title"), selection: $mode) {
                ForEach(TransactionsScene.Mode.allCases, id: \.self) { option in
                    Text(option.pickerTitle)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)

            switch mode {
            case .variableFlow:
                VariableHeroCard(metrics: cashMetrics, formatter: formatter)
            case .fixedExpenses:
                FixedExpensesHeroCard(
                    metrics: fixedMetrics,
                    formatter: formatter,
                    coverageText: coverageText,
                    coverageValue: coverageValue
                )
            }
        }
        .padding(.horizontal, 4)
    }
}
