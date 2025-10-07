import Foundation
import SwiftData
import Combine

@MainActor
final class TransactionsViewModel: ObservableObject {
    @Published private(set) var sections: [DaySection] = []
    @Published private(set) var metrics: TransactionsMetrics = .empty
    @Published private(set) var availableCategories: [String] = []
    @Published var searchText: String = "" {
        didSet { applyFilters() }
    }
    @Published var typeFilter: TypeFilter = .all {
        didSet { applyFilters() }
    }
    @Published var categoryFilter: String? = nil {
        didSet { applyFilters() }
    }
    @Published var sortOrder: SortOrder = .dateDescending {
        didSet { applyFilters() }
    }
    @Published var error: AppError?

    private let context: ModelContext
    private let calendar: Calendar
    private var monthInterval: DateInterval?
    private var allTransactions: [CashTransaction] = []
    private var notificationObservers: [Any] = []

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
        setupObservers()
    }

    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func load(for month: Date = .now) throws {
        monthInterval = calendar.dateInterval(of: .month, for: month)
        try fetchTransactions()
        recalculateDerivedState()
    }

    func addTransaction(date: Date, amount: Decimal, type: CashTransactionType, category: String?, note: String?) {
        guard validate(amount: amount) else { return }
        let transaction = CashTransaction(
            date: date,
            amount: amount,
            type: type,
            category: normalized(category),
            note: normalized(note)
        )
        context.insert(transaction)
        persistChanges()
    }

    func updateTransaction(_ transaction: CashTransaction, date: Date, amount: Decimal, type: CashTransactionType, category: String?, note: String?) {
        guard validate(amount: amount) else { return }
        transaction.date = date
        transaction.amount = amount
        transaction.type = type
        transaction.category = normalized(category)
        transaction.note = normalized(note)
        persistChanges()
    }

    func removeTransaction(_ transaction: CashTransaction) {
        context.delete(transaction)
        persistChanges()
    }

    private func fetchTransactions() throws {
        guard let monthInterval else {
            allTransactions = []
            sections = []
            metrics = .empty
            return
        }

        let descriptor = FetchDescriptor<CashTransaction>(
            predicate: #Predicate { transaction in
                transaction.date >= monthInterval.start && transaction.date < monthInterval.end
            },
            sortBy: [
                SortDescriptor(\.date, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )
        let fetched = try context.fetch(descriptor)
        fetched.forEach { _ = $0.category }
        allTransactions = fetched
        availableCategories = Array(
            Set(allTransactions.compactMap { $0.normalizedCategory })
        ).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func recalculateDerivedState() {
        metrics = makeMetrics(for: allTransactions)
        applyFilters()
    }

    private func applyFilters() {
        var results = allTransactions

        switch typeFilter {
        case .all:
            break
        case .expenses:
            results = results.filter { $0.type == .expense }
        case .income:
            results = results.filter { $0.type == .income }
        }

        if let category = categoryFilter?.lowercased(), !category.isEmpty {
            results = results.filter { ($0.category ?? "").lowercased() == category }
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmedQuery.isEmpty {
            results = results.filter { transaction in
                let category = transaction.category?.lowercased() ?? ""
                let note = transaction.note?.lowercased() ?? ""
                return category.contains(trimmedQuery) || note.contains(trimmedQuery)
            }
        }

        switch sortOrder {
        case .dateDescending:
            results.sort { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.date > rhs.date
            }
        case .amountDescending:
            results.sort { lhs, rhs in
                if lhs.amount == rhs.amount {
                    return lhs.date > rhs.date
                }
                return lhs.amount > rhs.amount
            }
        }

        sections = makeSections(from: results)
    }

    private func makeSections(from transactions: [CashTransaction]) -> [DaySection] {
        guard !transactions.isEmpty else { return [] }
        var grouped: [Date: [CashTransaction]] = [:]
        var orderedDates: [Date] = []

        for transaction in transactions {
            let day = calendar.startOfDay(for: transaction.date)
            if grouped[day] == nil {
                grouped[day] = []
                orderedDates.append(day)
            }
            grouped[day, default: []].append(transaction)
        }

        let dateOrder: [Date]
        switch sortOrder {
        case .dateDescending:
            dateOrder = orderedDates.sorted(by: >)
        case .amountDescending:
            dateOrder = orderedDates
        }

        return dateOrder.map { key in
            let transactions = grouped[key] ?? []
            let sortedTransactions: [CashTransaction]
            switch sortOrder {
            case .dateDescending:
                sortedTransactions = transactions.sorted { lhs, rhs in
                    if lhs.date == rhs.date {
                        return lhs.createdAt > rhs.createdAt
                    }
                    return lhs.date > rhs.date
                }
            case .amountDescending:
                sortedTransactions = transactions.sorted { lhs, rhs in
                    if lhs.amount == rhs.amount {
                        if lhs.date == rhs.date {
                            return lhs.createdAt > rhs.createdAt
                        }
                        return lhs.date > rhs.date
                    }
                    return lhs.amount > rhs.amount
                }
            }
            return DaySection(date: key, transactions: sortedTransactions)
        }
    }

    private func makeMetrics(for transactions: [CashTransaction]) -> TransactionsMetrics {
        let expenses = transactions
            .filter { $0.type == .expense }
            .reduce(into: Decimal.zero) { $0 += $1.amount }
        let income = transactions
            .filter { $0.type == .income }
            .reduce(into: Decimal.zero) { $0 += $1.amount }
        return TransactionsMetrics(
            totalExpenses: expenses,
            totalIncome: income,
            netBalance: income - expenses
        )
    }

    private func persistChanges() {
        do {
            try context.save()
            if let reference = monthInterval?.start {
                try load(for: reference)
            } else {
                try load()
            }
            NotificationCenter.default.postTransactionDataUpdates()
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
        }
    }

    private func validate(amount: Decimal) -> Bool {
        guard amount > 0 else {
            error = .validation("error.transaction.amount")
            return false
        }
        return true
    }

    private func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func setupObservers() {
        let observer = NotificationCenter.default.addObserver(
            forName: .cashTransactionDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                try? self.load(for: self.monthInterval?.start ?? .now)
            }
        }
        notificationObservers.append(observer)
    }
}

extension TransactionsViewModel {
    enum TypeFilter: Hashable {
        case all
        case expenses
        case income

        var localizedTitle: String {
            switch self {
            case .all:
                return String(localized: "transactions.filter.all", bundle: .appModule)
            case .expenses:
                return String(localized: "transactions.filter.expense", bundle: .appModule)
            case .income:
                return String(localized: "transactions.filter.income", bundle: .appModule)
            }
        }
    }

    enum SortOrder: Hashable, CaseIterable {
        case dateDescending
        case amountDescending

        var localizedTitle: String {
            switch self {
            case .dateDescending:
                return String(localized: "transactions.sort.date", bundle: .appModule)
            case .amountDescending:
                return String(localized: "transactions.sort.amount", bundle: .appModule)
            }
        }

        var systemImage: String {
            switch self {
            case .dateDescending:
                return "calendar"
            case .amountDescending:
                return "arrow.down.circle"
            }
        }
    }

    struct DaySection: Identifiable {
        var id: Date { date }
        let date: Date
        let transactions: [CashTransaction]
    }

    struct TransactionsMetrics: Equatable {
        let totalExpenses: Decimal
        let totalIncome: Decimal
        let netBalance: Decimal

        static let empty = TransactionsMetrics(totalExpenses: .zero, totalIncome: .zero, netBalance: .zero)
    }
}
