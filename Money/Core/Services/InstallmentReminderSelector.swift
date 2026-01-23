import Foundation

enum InstallmentReminderSelector {
    static func selectTarget(
        from installments: [Installment],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> Installment? {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let openInstallments = installments.filter { $0.remainingAmount > .zero }

        let overdue = openInstallments.filter { $0.dueDate < startOfToday }
        if let selectedOverdue = overdue.min(by: isEarlier) {
            return selectedOverdue
        }

        let upcoming = openInstallments.filter { $0.dueDate >= startOfToday }
        return upcoming.min(by: isEarlier)
    }

    private static func isEarlier(_ lhs: Installment, _ rhs: Installment) -> Bool {
        if lhs.dueDate != rhs.dueDate {
            return lhs.dueDate < rhs.dueDate
        }
        return lhs.number < rhs.number
    }
}
