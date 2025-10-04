import Foundation

func localizedFormat(_ key: String, _ args: CVarArg...) -> String {
    let format = String(localized: String.LocalizationValue(key), bundle: .appModule)
    return String(format: format, locale: Locale.current, arguments: args)
}
