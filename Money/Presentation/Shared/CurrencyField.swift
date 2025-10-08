import SwiftUI
import UIKit
import Foundation

/// Specialized currency field that appends digits from the least significant side, mimicking native money keyboards.
struct CurrencyField: View {
    private let title: LocalizedStringResource
    @Binding private var value: Decimal
    private let locale: Locale
    private let currencyCode: String
    private let maximumFractionDigits: Int

    init(
        _ title: LocalizedStringResource,
        value: Binding<Decimal>,
        locale: Locale = .current,
        currencyCode: String? = nil,
        maximumFractionDigits: Int? = nil
    ) {
        self.title = title
        self._value = value
        self.locale = locale
        let resolvedCurrency = currencyCode ?? locale.currency?.identifier ?? "BRL"
        self.currencyCode = resolvedCurrency
        if let maximumFractionDigits {
            self.maximumFractionDigits = maximumFractionDigits
        } else {
            self.maximumFractionDigits = CurrencyField.defaultFractionDigits(for: locale, currencyCode: resolvedCurrency)
        }
    }

    var body: some View {
        LabeledContent {
            CurrencyTextField(
                value: $value,
                placeholder: String(localized: title),
                locale: locale,
                currencyCode: currencyCode,
                maximumFractionDigits: maximumFractionDigits
            )
        } label: {
            Text(title)
        }
    }

    private static func defaultFractionDigits(for locale: Locale, currencyCode: String) -> Int {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return max(0, formatter.maximumFractionDigits)
    }
}

private struct CurrencyTextField: UIViewRepresentable {
    @Binding var value: Decimal
    let placeholder: String
    let locale: Locale
    let currencyCode: String
    let maximumFractionDigits: Int

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = .decimalPad
        textField.textAlignment = .right
        textField.adjustsFontForContentSizeCategory = true
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.placeholder = placeholder
        textField.accessibilityLabel = placeholder
        textField.delegate = context.coordinator
        textField.inputAccessoryView = makeAccessoryToolbar(for: textField)
        textField.text = formattedText(forCents: context.coordinator.cents)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self
        let currentCents = cents(from: value)
        if context.coordinator.cents != currentCents {
            context.coordinator.cents = currentCents
            if !textField.isFirstResponder {
                textField.text = formattedText(forCents: currentCents)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, cents: cents(from: value))
    }

    private func makeAccessoryToolbar(for textField: UITextField) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: textField, action: #selector(UIResponder.resignFirstResponder))
        toolbar.items = [flexible, done]
        return toolbar
    }

    private var fractionDivisor: Decimal {
        (0..<maximumFractionDigits).reduce(Decimal(1)) { partial, _ in partial * 10 }
    }

    private var fractionDivisorNumber: NSDecimalNumber {
        NSDecimalNumber(decimal: fractionDivisor)
    }

    private func cents(from decimal: Decimal) -> Int {
        let scaled = NSDecimalNumber(decimal: decimal).multiplying(by: fractionDivisorNumber)
        let rounded = scaled.rounding(accordingToBehavior: roundingBehavior)
        return rounded.intValue
    }

    private func decimal(from cents: Int) -> Decimal {
        let number = NSDecimalNumber(value: cents)
        return number.dividing(by: fractionDivisorNumber).decimalValue
    }

    private func formattedText(forCents cents: Int) -> String {
        currencyFormatter.string(from: NSDecimalNumber(value: cents).dividing(by: fractionDivisorNumber)) ?? ""
    }

    private var roundingBehavior: NSDecimalNumberHandler {
        NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
    }

    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = maximumFractionDigits
        return formatter
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CurrencyTextField
        var cents: Int

        private var maximumCents: Int {
            Int.max / 10
        }

        init(parent: CurrencyTextField, cents: Int) {
            self.parent = parent
            self.cents = max(0, cents)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            updateTextField(textField)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            updateTextField(textField)
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if range.length == textField.text?.count ?? 0 && string.isEmpty {
                cents = 0
            } else if string.isEmpty {
                cents = cents / 10
            } else {
                let digits = string.compactMap(\.wholeNumberValue)
                if digits.isEmpty { return false }
                if range.length == textField.text?.count ?? 0 {
                    cents = 0
                }
                let limitThreshold = maximumCents / 10
                let limitRemainder = maximumCents % 10
                for digit in digits {
                    if cents > limitThreshold { break }
                    if cents == limitThreshold && digit > limitRemainder { break }
                    cents = cents * 10 + digit
                }
            }

            parent.value = parent.decimal(from: cents)
            updateTextField(textField)
            return false
        }

        private func updateTextField(_ textField: UITextField) {
            textField.text = parent.formattedText(forCents: cents)
            moveCaretToEnd(textField)
        }

        private func moveCaretToEnd(_ textField: UITextField) {
            let end = textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: end, to: end)
        }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
