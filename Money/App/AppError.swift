import Foundation

/// Erro de domínio central do app com mensagens localizadas.
enum AppError: LocalizedError, Sendable {
    case validation(String.LocalizationValue)
    case persistence(String.LocalizationValue)
    case scheduling(String.LocalizationValue)
    case iCloudUnavailable
    case notFound

    var errorDescription: String? {
        switch self {
        case .validation(let key):
            return String(localized: key, bundle: .appModule)
        case .persistence(let key):
            return String(localized: key, bundle: .appModule)
        case .scheduling(let key):
            return String(localized: key, bundle: .appModule)
        case .iCloudUnavailable:
            return String(localized: "error.icloudunavailable", bundle: .appModule)
        case .notFound:
            return String(localized: "error.notfound", bundle: .appModule)
        }
    }
}
