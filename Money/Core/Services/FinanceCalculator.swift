import Foundation

struct InstallmentSpec: Sendable, Equatable {
    let number: Int
    let dueDate: Date
    let amount: Decimal
}

struct FinanceCalculator: Sendable {
    func generateSchedule(
        principal: Decimal,
        installments: Int,
        monthlyInterest: Decimal?,
        firstDueDate: Date,
        calendar: Calendar = .current
    ) throws -> [InstallmentSpec] {
        guard principal > .zero else { throw AppError.validation("error.principal.invalid") }
        guard installments >= 1 else { throw AppError.validation("error.installments.invalid") }

        let normalizedRate = monthlyInterest.map { rate -> Decimal in
            if rate > 1 { return (rate / 100).rounded(6) }
            return rate
        }

        let useInterest = (normalizedRate ?? .zero) > .zero
        if useInterest {
            return priceSchedule(
                principal: principal,
                rate: normalizedRate!,
                count: installments,
                firstDue: firstDueDate,
                calendar: calendar
            )
        } else {
            return linearSchedule(
                principal: principal,
                count: installments,
                firstDue: firstDueDate,
                calendar: calendar
            )
        }
    }

    private func linearSchedule(
        principal: Decimal,
        count: Int,
        firstDue: Date,
        calendar: Calendar
    ) -> [InstallmentSpec] {
        let base = (principal / Decimal(count)).rounded(2)
        var specs: [InstallmentSpec] = []
        for index in 0..<count {
            let due = calendar.date(byAdding: .month, value: index, to: firstDue) ?? firstDue
            let amount: Decimal
            if index == count - 1 {
                let totalAssigned = base * Decimal(count - 1)
                amount = (principal - totalAssigned).rounded(2)
            } else {
                amount = base
            }
            specs.append(.init(number: index + 1, dueDate: due, amount: amount))
        }
        return specs
    }

    private func priceSchedule(
        principal: Decimal,
        rate: Decimal,
        count: Int,
        firstDue: Date,
        calendar: Calendar
    ) -> [InstallmentSpec] {
        let rateDouble = (rate as NSDecimalNumber).doubleValue
        let principalDouble = (principal as NSDecimalNumber).doubleValue
        let pmtDouble = pricePMT(principal: principalDouble, rate: rateDouble, nper: count)
        let paymentValue = Decimal(pmtDouble).rounded(2)

        var balance = principal
        var specs: [InstallmentSpec] = []
        for index in 0..<count {
            let due = calendar.date(byAdding: .month, value: index, to: firstDue) ?? firstDue
            let interest = (balance * rate).rounded(2)
            let amortization = (paymentValue - interest).rounded(2)
            balance = (balance - amortization).clamped(to: .zero...principal)
            specs.append(.init(number: index + 1, dueDate: due, amount: paymentValue))
        }
        return specs
    }

    private func pricePMT(principal: Double, rate: Double, nper: Int) -> Double {
        guard rate != 0 else { return principal / Double(nper) }
        let numerator = principal * rate * pow(1 + rate, Double(nper))
        let denominator = pow(1 + rate, Double(nper)) - 1
        return numerator / denominator
    }
}
