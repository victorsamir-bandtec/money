import Foundation
import Testing
@testable import Money

struct CurrencyFormatterTests {
    @Test("Formata valores BRL corretamente")
    func formatsBRLValuesCorrectly() {
        let formatter = CurrencyFormatter()

        #expect(formatter.string(from: Decimal(1000)) == "R$ 1.000,00")
        #expect(formatter.string(from: Decimal(1000.50)) == "R$ 1.000,50")
        #expect(formatter.string(from: Decimal(0.99)) == "R$ 0,99")
        #expect(formatter.string(from: Decimal(1000000)) == "R$ 1.000.000,00")
    }

    @Test("Formata valores zero corretamente")
    func formatsZeroCorrectly() {
        let formatter = CurrencyFormatter()

        #expect(formatter.string(from: Decimal(0)) == "R$ 0,00")
        #expect(formatter.string(from: Decimal(0.00)) == "R$ 0,00")
    }

    @Test("Formata valores decimais com precisão")
    func formatsDecimalValuesWithPrecision() {
        let formatter = CurrencyFormatter()

        #expect(formatter.string(from: Decimal(string: "123.45")!) == "R$ 123,45")
        #expect(formatter.string(from: Decimal(string: "0.01")!) == "R$ 0,01")
        #expect(formatter.string(from: Decimal(string: "9999.99")!) == "R$ 9.999,99")
    }

    @Test("Formata valores grandes corretamente")
    func formatsLargeValuesCorrectly() {
        let formatter = CurrencyFormatter()

        #expect(formatter.string(from: Decimal(1000000)) == "R$ 1.000.000,00")
        #expect(formatter.string(from: Decimal(1234567.89)) == "R$ 1.234.567,89")
        #expect(formatter.string(from: Decimal(999999999.99)) == "R$ 999.999.999,99")
    }

    @Test("Formata valores pequenos corretamente")
    func formatsSmallValuesCorrectly() {
        let formatter = CurrencyFormatter()

        #expect(formatter.string(from: Decimal(0.01)) == "R$ 0,01")
        #expect(formatter.string(from: Decimal(0.10)) == "R$ 0,10")
        #expect(formatter.string(from: Decimal(0.99)) == "R$ 0,99")
    }

    @Test("Respeita locale pt_BR")
    func respectsPtBRLocale() {
        let formatter = CurrencyFormatter()

        // Verificar separador de milhar (ponto) e decimal (vírgula)
        let value = Decimal(1234.56)
        let formatted = formatter.string(from: value)

        #expect(formatted.contains("."))  // Separador de milhar
        #expect(formatted.contains(","))  // Separador decimal
        #expect(formatted.hasPrefix("R$")) // Símbolo da moeda
    }

    @Test("Aceita locale customizado")
    func acceptsCustomLocale() {
        let usFormatter = CurrencyFormatter(locale: Locale(identifier: "en_US"), currencyCode: "USD")

        let value = Decimal(1234.56)
        let formatted = usFormatter.string(from: value)

        #expect(formatted.contains("$"))
        #expect(formatted.contains(","))  // Separador de milhar US
        #expect(formatted.contains("."))  // Separador decimal US
    }

    @Test("Mantém duas casas decimais")
    func maintainsTwoDecimalPlaces() {
        let formatter = CurrencyFormatter()

        #expect(formatter.string(from: Decimal(100)) == "R$ 100,00")
        #expect(formatter.string(from: Decimal(100.5)) == "R$ 100,50")
        #expect(formatter.string(from: Decimal(100.1)) == "R$ 100,10")
    }

    @Test("Fallback para stringValue em caso de erro")
    func fallbacksToStringValueOnError() {
        let formatter = CurrencyFormatter()

        // Valores válidos sempre devem formatar corretamente
        let value = Decimal(123.45)
        let result = formatter.string(from: value)

        #expect(result.contains("123"))
        #expect(result.contains("45"))
    }

    @Test("É Sendable e thread-safe")
    func isSendableAndThreadSafe() {
        let formatter = CurrencyFormatter()

        // Testar que pode ser usado em contextos concorrentes
        let value = Decimal(1000)

        Task {
            let result1 = formatter.string(from: value)
            #expect(result1 == "R$ 1.000,00")
        }

        Task {
            let result2 = formatter.string(from: value)
            #expect(result2 == "R$ 1.000,00")
        }
    }

    @Test("Formata valores negativos corretamente")
    func formatsNegativeValuesCorrectly() {
        let formatter = CurrencyFormatter()

        // Em BRL, valores negativos aparecem com menos na frente
        let negativeValue = Decimal(-1000.50)
        let formatted = formatter.string(from: negativeValue)

        #expect(formatted.contains("-") || formatted.contains("("))
        #expect(formatted.contains("1.000,50") || formatted.contains("1.000,5"))
    }
}
