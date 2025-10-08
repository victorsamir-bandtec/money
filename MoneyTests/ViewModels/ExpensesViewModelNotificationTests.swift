import Foundation
import Testing
import SwiftData
@testable import Money

struct ExpensesViewModelNotificationTests {
    @Test("Emite notificacao financeira ao adicionar despesa") @MainActor
    func postsFinancialChangeNotificationOnAddExpense() throws {
        let schema = Schema([
            FixedExpense.self,
            SalarySnapshot.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let viewModel = ExpensesViewModel(context: context)
        try viewModel.load()

        let center = NotificationCenter.default
        var notificationReceived = false
        let observer = center.addObserver(forName: .financialDataDidChange, object: nil, queue: nil) { _ in
            notificationReceived = true
        }
        defer { center.removeObserver(observer) }

        viewModel.addExpense(name: "Internet", amount: 120, category: "Casa", dueDay: 10, note: nil)

        #expect(notificationReceived)
    }
}
