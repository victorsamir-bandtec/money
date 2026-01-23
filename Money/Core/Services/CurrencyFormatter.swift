import Foundation

struct CurrencyFormatter: Sendable {
    private let formatter: NumberFormatter

    // Shared formatter for BRL (most common case) to avoid expensive recreation
    private static let brlFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    init(locale: Locale = Locale(identifier: "pt_BR"), currencyCode: String = "BRL") {
        if locale.identifier == "pt_BR" && currencyCode == "BRL" {
            self.formatter = Self.brlFormatter
        } else {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            formatter.maximumFractionDigits = 2
            self.formatter = formatter
        }
    }

    func string(from decimal: Decimal) -> String {
        let number = decimal as NSDecimalNumber
        return formatter.string(from: number) ?? number.stringValue
    }
}
