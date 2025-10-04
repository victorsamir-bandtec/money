import Foundation

struct CurrencyFormatter: Sendable {
    private let formatter: NumberFormatter

    init(locale: Locale = Locale(identifier: "pt_BR"), currencyCode: String = "BRL") {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        self.formatter = formatter
    }

    func string(from decimal: Decimal) -> String {
        let number = decimal as NSDecimalNumber
        return formatter.string(from: number) ?? number.stringValue
    }
}
