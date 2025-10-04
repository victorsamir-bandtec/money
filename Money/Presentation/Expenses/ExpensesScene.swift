import SwiftUI
import SwiftData

struct ExpensesScene: View {
    @StateObject private var viewModel: ExpensesViewModel
    private let formatter: CurrencyFormatter

    @State private var showingExpenseForm = false
    @State private var showingSalarySheet = false
    @State private var draft = ExpenseDraft()
    @State private var salaryDraft = SalaryDraft()

    init(environment: AppEnvironment, context: ModelContext) {
        _viewModel = StateObject(wrappedValue: ExpensesViewModel(context: context))
        self.formatter = environment.currencyFormatter
    }

    var body: some View {
        NavigationStack {
            List {
                salarySection
                expensesSection
            }
            .navigationTitle(String(localized: "expenses.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingExpenseForm = true }) {
                        Label(String(localized: "expenses.add"), systemImage: "plus")
                    }
                }
            }
            .task { try? viewModel.load() }
            .sheet(isPresented: $showingExpenseForm) {
                ExpenseForm(draft: $draft) { action in
                    switch action {
                    case .save(let savedDraft):
                        viewModel.addExpense(name: savedDraft.name, amount: savedDraft.amount, category: savedDraft.category, dueDay: savedDraft.dueDay)
                        draft = ExpenseDraft()
                        showingExpenseForm = false
                    case .cancel:
                        showingExpenseForm = false
                    }
                }
            }
            .sheet(isPresented: $showingSalarySheet) {
                SalaryForm(draft: $salaryDraft) { action in
                    switch action {
                    case .save(let savedDraft):
                        viewModel.updateSalary(amount: savedDraft.amount, month: savedDraft.month)
                        showingSalarySheet = false
                    case .cancel:
                        showingSalarySheet = false
                    }
                }
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
    }

    private var salarySection: some View {
        Section(String(localized: "expenses.section.salary")) {
            if let salary = viewModel.salary {
                HStack {
                    Text(formatter.string(from: salary.amount))
                        .font(.title3).bold()
                    Spacer()
                    Button(String(localized: "expenses.salary.edit")) {
                        salaryDraft = SalaryDraft(amount: salary.amount, month: salary.referenceMonth)
                        showingSalarySheet = true
                    }
                }
            } else {
                Button(String(localized: "expenses.salary.add")) {
                    salaryDraft = SalaryDraft()
                    showingSalarySheet = true
                }
            }
        }
    }

    private var expensesSection: some View {
        Section(String(localized: "expenses.section.list")) {
            if viewModel.expenses.isEmpty {
                ContentUnavailableView(String(localized: "expenses.empty"), systemImage: "creditcard")
            } else {
                ForEach(viewModel.expenses, id: \.id) { expense in
                    ExpenseRow(expense: expense, formatter: formatter)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.removeExpense(expense)
                            } label: {
                                Label(String(localized: "common.remove"), systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
            }
        }
    }
}

private struct ExpenseRow: View {
    let expense: FixedExpense
    let formatter: CurrencyFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(expense.name)
                    .font(.headline)
                Spacer()
                Text(formatter.string(from: expense.amount))
            }
            HStack(spacing: 12) {
                Label(localizedFormat("expenses.due", expense.dueDay), systemImage: "calendar")
                if let category = expense.category {
                    Label(category, systemImage: "tag")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct ExpenseDraft {
    var name: String = ""
    var amount: Decimal = .zero
    var category: String = ""
    var dueDay: Int = 5
}

private struct SalaryDraft {
    var amount: Decimal = .zero
    var month: Date = .now
}

private struct ExpenseForm: View {
    @Binding var draft: ExpenseDraft
    var completion: (ResultAction) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "expenses.form.details")) {
                    TextField(String(localized: "expenses.form.name"), text: $draft.name)
                    TextField(String(localized: "expenses.form.amount"), value: $draft.amount, format: .number)
                        .keyboardType(.decimalPad)
                    TextField(String(localized: "expenses.form.category"), text: $draft.category)
                    Stepper(value: $draft.dueDay, in: 1...31) {
                        Text(localizedFormat("expenses.form.dueDay", draft.dueDay))
                    }
                }
            }
            .navigationTitle(String(localized: "expenses.form.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { completion(.cancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) { completion(.save(draft)) }
                        .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.amount <= 0)
                }
            }
        }
    }

    enum ResultAction {
        case save(ExpenseDraft)
        case cancel
    }
}

private struct SalaryForm: View {
    @Binding var draft: SalaryDraft
    var completion: (ResultAction) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "salary.form.section")) {
                    TextField(String(localized: "salary.form.amount"), value: $draft.amount, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker(String(localized: "salary.form.month"), selection: $draft.month, displayedComponents: [.date])
                }
            }
            .navigationTitle(String(localized: "salary.form.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { completion(.cancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) { completion(.save(draft)) }
                        .disabled(draft.amount <= 0)
                }
            }
        }
    }

    enum ResultAction {
        case save(SalaryDraft)
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
