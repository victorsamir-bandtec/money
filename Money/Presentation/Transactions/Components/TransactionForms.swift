import SwiftUI
import SwiftData

// MARK: - Transaction Form

enum TransactionFormMode {
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

struct TransactionForm: View {
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
                    CurrencyField("transactions.form.amount", value: $draft.amount)
                }

                Section(String(localized: "transactions.form.details")) {
                    TextField(String(localized: "transactions.form.category"), text: $draft.category)
                    if !categories.isEmpty {
                        FilterChipRow(
                            categories: categories,
                            selectedCategory: draft.category,
                            onToggle: { category in draft.category = category }
                        )
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

struct TransactionDraft: Equatable {
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

// MARK: - Expense Form

enum ExpenseFormMode {
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

struct ExpenseForm: View {
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
                    CurrencyField("expenses.form.amount", value: $draft.amount)
                        .focused($focusedField, equals: .amount)
                    Stepper(value: $draft.dueDay, in: 1...31) {
                        Text(localizedFormat("expenses.form.dueDay", draft.dueDay))
                    }
                }

                Section(String(localized: "expenses.form.category")) {
                    TextField(String(localized: "expenses.form.category.placeholder"), text: $draft.category)
                        .focused($focusedField, equals: .category)
                    if !suggestedCategories.isEmpty {
                        FilterChipRow(
                            categories: suggestedCategories,
                            selectedCategory: draft.category,
                            onToggle: { category in draft.category = category }
                        )
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

struct ExpenseDraft: Equatable {
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
        name.isNotBlank && amount > 0 && (1...31).contains(dueDay)
    }
}

// MARK: - Supporting Types

struct ExpenseDetailContext: Identifiable {
    let expense: FixedExpense
    var id: UUID { expense.id }
}
