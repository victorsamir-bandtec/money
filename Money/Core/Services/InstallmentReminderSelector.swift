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
        if let selectedOverdue = earliestInstallment(in: overdue) {
            return selectedOverdue
        }

        let upcoming = openInstallments.filter { $0.dueDate >= startOfToday }
        return earliestInstallment(in: upcoming)
    }

    private static func earliestInstallment(in installments: [Installment]) -> Installment? {
        var candidate: Installment?
        for installment in installments {
            guard let current = candidate else {
                candidate = installment
                continue
            }

            if isEarlier(installment, current) {
                candidate = installment
            }
        }

        return candidate
    }

    private static func isEarlier(_ lhs: Installment, _ rhs: Installment) -> Bool {
        if lhs.dueDate != rhs.dueDate {
            return lhs.dueDate < rhs.dueDate
        }
        return lhs.number < rhs.number
    }
}
