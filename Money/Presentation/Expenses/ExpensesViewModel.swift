import Foundation
import SwiftData
import Combine

@MainActor
final class ExpensesViewModel: ObservableObject {
    @Published var expenses: [FixedExpense] = []
    @Published var salary: SalarySnapshot?
    @Published var error: AppError?

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func load(currentMonth: Date = .now) throws {
        try fetchExpenses()
        try fetchSalary(for: currentMonth)
    }

    func addExpense(name: String, amount: Decimal, category: String?, dueDay: Int) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = .validation("error.expense.name")
            return
        }
        let expense = FixedExpense(name: name, amount: amount, category: category, dueDay: dueDay)
        context.insert(expense)
        do {
            try context.save()
            try fetchExpenses()
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
        }
    }

    func removeExpense(_ expense: FixedExpense) {
        context.delete(expense)
        do {
            try context.save()
            try fetchExpenses()
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
        }
    }

    func updateSalary(amount: Decimal, month: Date) {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: month) ?? DateInterval(start: month, end: month)
        let descriptor = FetchDescriptor<SalarySnapshot>(predicate: #Predicate { snapshot in
            snapshot.referenceMonth >= interval.start && snapshot.referenceMonth < interval.end
        })
        do {
            let snapshots = try context.fetch(descriptor)
            if let existing = snapshots.first {
                existing.amount = amount
                existing.referenceMonth = month
                salary = existing
            } else {
                let snapshot = SalarySnapshot(referenceMonth: month, amount: amount)
                context.insert(snapshot)
                salary = snapshot
            }
            try context.save()
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
        }
    }

    private func fetchExpenses() throws {
        let descriptor = FetchDescriptor<FixedExpense>(predicate: #Predicate { expense in
            expense.active
        }, sortBy: [SortDescriptor(\.dueDay)])
        expenses = try context.fetch(descriptor)
    }

    private func fetchSalary(for month: Date) throws {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: month) ?? DateInterval(start: month, end: month)
        let descriptor = FetchDescriptor<SalarySnapshot>(predicate: #Predicate { snapshot in
            snapshot.referenceMonth >= interval.start && snapshot.referenceMonth < interval.end
        })
        salary = try context.fetch(descriptor).first
    }
}
