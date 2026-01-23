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
        let pmt = pricePMT(principal: principal, rate: rate, nper: count)
        // Arredonda a parcela para 2 casas, padrão em contratos.
        // Diferenças residuais de centavos ao longo de anos seriam ajustadas na última
        // em sistemas bancários reais, mas aqui mantemos PMT constante.
        let paymentValue = pmt.rounded(2)

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

    private func pricePMT(principal: Decimal, rate: Decimal, nper: Int) -> Decimal {
        guard rate != .zero else { return principal / Decimal(nper) }
        
        let rateNS = rate as NSDecimalNumber
        let onePlusRate = rateNS.adding(.one)
        let power = onePlusRate.raising(toPower: nper)
        
        // PMT = P * i * (1+i)^n / ((1+i)^n - 1)
        let numerator = (principal as NSDecimalNumber)
            .multiplying(by: rateNS)
            .multiplying(by: power)
            
        let denominator = power.subtracting(.one)
        
        guard denominator != .zero else { return principal / Decimal(nper) }
        
        return numerator.dividing(by: denominator).decimalValue
    }
}
