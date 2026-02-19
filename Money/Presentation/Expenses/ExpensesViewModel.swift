import Foundation
import Combine
import SwiftData

@MainActor
final class ExpensesViewModel: ObservableObject {
    @Published private(set) var expenses: [FixedExpense] = []
    @Published private(set) var filteredExpenses: [FixedExpense] = []
    @Published private(set) var metrics: ExpensesMetrics = .empty
    @Published private(set) var availableCategories: [String] = []
    @Published var searchText: String = "" {
        didSet { applyFilters() }
    }
    @Published var statusFilter: StatusFilter = .active {
        didSet { applyFilters() }
    }
    @Published var selectedCategory: String? = nil {
        didSet { applyFilters() }
    }
    @Published var sortOption: SortOption = .dueDate {
        didSet { applyFilters() }
    }
    @Published var error: AppError?

    private let context: ModelContext
    private let calendar: Calendar
    private let commandService: CommandService?
    private let eventBus: DomainEventSubscribing?
    private var eventTask: Task<Void, Never>?
    private var referenceDate: Date
    private var salarySnapshot: SalarySnapshot?

    init(
        context: ModelContext,
        calendar: Calendar = .current,
        referenceDate: Date = .now,
        commandService: CommandService? = nil,
        eventBus: DomainEventSubscribing? = nil
    ) {
        self.context = context
        self.calendar = calendar
        self.referenceDate = referenceDate
        self.commandService = commandService
        self.eventBus = eventBus
        subscribeToEvents()
    }

    func load(currentMonth: Date = .now) throws {
        referenceDate = currentMonth
        try fetchExpenses()
        try fetchSalary(for: currentMonth)
        recalculateDerivedState()
    }

    func addExpense(name: String, amount: Decimal, category: String?, dueDay: Int, note: String?) {
        guard validate(name: name, amount: amount, dueDay: dueDay) else { return }
        do {
            if let commandService {
                _ = try commandService.upsertExpense(
                    existing: nil,
                    name: name,
                    amount: amount,
                    category: category,
                    dueDay: dueDay,
                    active: true,
                    note: note,
                    context: context
                )
            } else {
                guard let expense = FixedExpense(
                    name: name.normalized,
                    amount: amount,
                    category: category.normalizedOrNil,
                    dueDay: dueDay,
                    note: note.normalizedOrNil
                ) else {
                    error = .validation("error.expense.invalid")
                    return
                }
                context.insert(expense)
                persistChanges()
            }
        } catch let appError as AppError {
            self.error = appError
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    func updateExpense(_ expense: FixedExpense, name: String, amount: Decimal, category: String?, dueDay: Int, note: String?) {
        guard validate(name: name, amount: amount, dueDay: dueDay) else { return }
        do {
            if let commandService {
                _ = try commandService.upsertExpense(
                    existing: expense,
                    name: name,
                    amount: amount,
                    category: category,
                    dueDay: dueDay,
                    active: expense.active,
                    note: note,
                    context: context
                )
            } else {
                expense.name = name.normalized
                expense.amount = amount
                expense.category = category.normalizedOrNil
                expense.dueDay = dueDay
                expense.note = note.normalizedOrNil
                persistChanges()
            }
        } catch let appError as AppError {
            self.error = appError
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    func duplicate(_ expense: FixedExpense) {
        do {
            if let commandService {
                _ = try commandService.upsertExpense(
                    existing: nil,
                    name: expense.name,
                    amount: expense.amount,
                    category: expense.category,
                    dueDay: expense.dueDay,
                    active: expense.active,
                    note: expense.note,
                    context: context
                )
            } else {
                guard let duplicate = FixedExpense(
                    name: expense.name,
                    amount: expense.amount,
                    category: expense.category,
                    dueDay: expense.dueDay,
                    active: expense.active,
                    note: expense.note
                ) else {
                    error = .validation("error.expense.invalid")
                    return
                }
                context.insert(duplicate)
                persistChanges()
            }
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    func toggleArchive(_ expense: FixedExpense) {
        do {
            if let commandService {
                _ = try commandService.upsertExpense(
                    existing: expense,
                    name: expense.name,
                    amount: expense.amount,
                    category: expense.category,
                    dueDay: expense.dueDay,
                    active: !expense.active,
                    note: expense.note,
                    context: context
                )
            } else {
                expense.active.toggle()
                persistChanges()
            }
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    func removeExpense(_ expense: FixedExpense) {
        do {
            if let commandService {
                try commandService.deleteExpense(expense, context: context)
            } else {
                context.delete(expense)
                persistChanges()
            }
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    func formattedCoveragePercentage() -> String? {
        guard let value = metrics.coverage else { return nil }
        let percentage = NumberFormatter.percent.string(from: NSNumber(value: value))
        return percentage
    }

    func dueDate(for expense: FixedExpense) -> Date? {
        expense.nextDueDate(reference: referenceDate, calendar: calendar)
    }

    func isOverdue(_ expense: FixedExpense) -> Bool {
        guard let dueDate = dueDate(for: expense) else { return false }
        return calendar.isDate(dueDate, inSameDayAs: referenceDate) ? false : dueDate < referenceDate
    }

    private func persistChanges() {
        context.saveAndReload {
            try fetchExpenses()
            recalculateDerivedState()
        }
        .handlePersistenceError { self.error = $0 }
    }

    private func fetchExpenses() throws {
        let descriptor = FetchDescriptor<FixedExpense>()
        expenses = try context.fetch(descriptor)
        availableCategories = expenses.uniqueCategories
    }

    private func fetchSalary(for month: Date) throws {
        let interval = calendar.dateInterval(of: .month, for: month) ?? DateInterval(start: month, end: month)
        let descriptor = FetchDescriptor<SalarySnapshot>(predicate: #Predicate { snapshot in
            snapshot.referenceMonth >= interval.start && snapshot.referenceMonth < interval.end
        })
        salarySnapshot = try context.fetch(descriptor).first
    }

    private func applyFilters() {
        var results = expenses

        // Status filter
        switch statusFilter {
        case .active: results = results.filter { $0.active }
        case .archived: results = results.filter { !$0.active }
        case .all: break
        }

        // Category filter
        results = CategoryFilter.apply(to: results, selectedCategory: selectedCategory)

        // Search filter
        results = SearchFilter.apply(to: results, searchText: searchText) { query in
            { expense in
                expense.name.containsIgnoringCase(query) ||
                (expense.category?.containsIgnoringCase(query) ?? false) ||
                (expense.note?.containsIgnoringCase(query) ?? false)
            }
        }

        results.sort(by: makeSortClosure())
        filteredExpenses = results
    }

    private func makeSortClosure() -> (FixedExpense, FixedExpense) -> Bool {
        switch sortOption {
        case .dueDate:
            return { lhs, rhs in
                let lhsDate = lhs.nextDueDate(reference: self.referenceDate, calendar: self.calendar)
                let rhsDate = rhs.nextDueDate(reference: self.referenceDate, calendar: self.calendar)

                if let lhsDate, let rhsDate, lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
                if lhsDate != nil && rhsDate == nil { return true }
                if lhsDate == nil && rhsDate != nil { return false }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .amountDescending:
            return { lhs, rhs in
                if lhs.amount == rhs.amount {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.amount > rhs.amount
            }
        case .name:
            return { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private func recalculateDerivedState() {
        if let selectedCategory {
            let matches = availableCategories.contains { $0.localizedCaseInsensitiveCompare(selectedCategory) == .orderedSame }
            if !matches {
                self.selectedCategory = nil
            }
        }
        applyFilters()
        let activeExpenses = expenses.filter { $0.active }
        let total = activeExpenses.reduce(Decimal.zero) { $0 + $1.amount }
        let salaryAmount = salarySnapshot?.amount
        let remaining = salaryAmount.map { $0 - total }
        metrics = ExpensesMetrics(
            totalExpenses: total,
            salaryAmount: salaryAmount,
            remaining: remaining,
            coverage: calculateCoverage(total: total, salary: salaryAmount)
        )
    }

    private func calculateCoverage(total: Decimal, salary: Decimal?) -> Double? {
        guard let salary, salary > 0 else { return nil }
        let totalNumber = NSDecimalNumber(decimal: total)
        let salaryNumber = NSDecimalNumber(decimal: salary)
        guard salaryNumber != .zero else { return nil }
        return totalNumber.dividing(by: salaryNumber).doubleValue
    }

    private func validate(name: String, amount: Decimal, dueDay: Int) -> Bool {
        guard name.isNotBlank else {
            error = .validation("error.expense.name")
            return false
        }
        guard amount > 0 else {
            error = .validation("error.expense.amount")
            return false
        }
        guard (1...31).contains(dueDay) else {
            error = .validation("error.expense.dueDay")
            return false
        }
        return true
    }

    private func subscribeToEvents() {
        guard let eventBus else { return }

        eventTask = Task { [weak self] in
            let stream = await eventBus.stream()
            for await event in stream {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                switch event {
                case .salaryChanged, .transactionChanged, .paymentChanged, .agreementChanged:
                    try? self.load(currentMonth: self.referenceDate)
                case .debtorChanged:
                    break
                }
            }
        }
    }
}

extension ExpensesViewModel {
    enum StatusFilter: Hashable {
        case active
        case archived
        case all
    }

    enum SortOption: Hashable, CaseIterable {
        case dueDate
        case amountDescending
        case name
    }

    struct ExpensesMetrics {
        let totalExpenses: Decimal
        let salaryAmount: Decimal?
        let remaining: Decimal?
        let coverage: Double?

        static let empty = ExpensesMetrics(totalExpenses: .zero, salaryAmount: nil, remaining: nil, coverage: nil)

        var formattedCoverage: Double? { coverage }
    }
}

private extension NumberFormatter {
    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}
