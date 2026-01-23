import Foundation
import Testing
@testable import Money

struct FinanceCalculatorTests {
    let calculator = FinanceCalculator()

    @Test("Gera cronograma linear sem juros")
    func generateLinearSchedule() throws {
        let schedule = try calculator.generateSchedule(
            principal: 1200,
            installments: 12,
            monthlyInterest: nil,
            firstDueDate: Date(timeIntervalSince1970: 0)
        )
        #expect(schedule.count == 12)
        #expect(schedule.first?.amount == 100)
        #expect(schedule.last?.amount == 100)
    }

    @Test("Dispara erro ao receber valor inválido")
    func invalidPrincipal() {
        #expect(throws: AppError.self) {
            _ = try calculator.generateSchedule(principal: 0, installments: 1, monthlyInterest: nil, firstDueDate: .now)
        }
    }

    @Test("Normaliza valores percentuais antes da amortização")
    func normalizesPercentageInterest() throws {
        let schedule = try calculator.generateSchedule(
            principal: 1000,
            installments: 12,
            monthlyInterest: 2, // 2%
            firstDueDate: Date(timeIntervalSince1970: 0)
        )
        let firstAmount = try #require(schedule.first?.amount)
        #expect(firstAmount == Decimal(string: "94.56"))
    }

    @Test("Calcula juros compostos corretamente")
    func calculateCompoundInterest() throws {
        let schedule = try calculator.generateSchedule(
            principal: 1000,
            installments: 3,
            monthlyInterest: 5, // 5%
            firstDueDate: Date(timeIntervalSince1970: 0)
        )

        #expect(schedule.count == 3)
        // Todas as parcelas devem ter o mesmo valor no sistema Price
        let firstAmount = schedule.first?.amount ?? 0
        #expect(schedule.allSatisfy { $0.amount == firstAmount })
    }

    @Test("Ajusta última parcela no cronograma linear")
    func adjustsLastInstallmentLinear() throws {
        let schedule = try calculator.generateSchedule(
            principal: 1000,
            installments: 3,
            monthlyInterest: nil,
            firstDueDate: Date(timeIntervalSince1970: 0)
        )

        // 1000 / 3 = 333.33 + 333.33 + 333.34
        #expect(schedule[0].amount == Decimal(string: "333.33"))
        #expect(schedule[1].amount == Decimal(string: "333.33"))
        #expect(schedule[2].amount == Decimal(string: "333.34"))
    }

    @Test("Gera datas corretas com intervalo mensal")
    func generatesCorrectMonthlyDates() throws {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15))!

        let schedule = try calculator.generateSchedule(
            principal: 300,
            installments: 3,
            monthlyInterest: nil,
            firstDueDate: startDate,
            calendar: calendar
        )

        let expectedDates = [
            calendar.date(from: DateComponents(year: 2024, month: 1, day: 15))!,
            calendar.date(from: DateComponents(year: 2024, month: 2, day: 15))!,
            calendar.date(from: DateComponents(year: 2024, month: 3, day: 15))!
        ]

        for (index, spec) in schedule.enumerated() {
            #expect(spec.dueDate == expectedDates[index])
        }
    }

    @Test("Mantém precisão em financiamentos longos (360 meses)")
    func maintainsPrecisionInLongTermLoans() throws {
        // Simulação de financiamento imobiliário: 200k, 1% a.m., 360 meses (Price)
        let schedule = try calculator.generateSchedule(
            principal: 200_000,
            installments: 360,
            monthlyInterest: 1, // 1%
            firstDueDate: Date(timeIntervalSince1970: 0)
        )
        
        let pmt = try #require(schedule.first?.amount)
        let totalPaid = schedule.reduce(Decimal.zero) { $0 + $1.amount }
        
        // Verifica se todas as parcelas são iguais (Price)
        #expect(schedule.allSatisfy { $0.amount == pmt })
        
        // Verifica consistência: Total = PMT * Prazo
        #expect(totalPaid == pmt * 360)
    }
}
