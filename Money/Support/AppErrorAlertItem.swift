import SwiftUI

/// Shared item for presenting `AppError` inside SwiftUI alerts.
struct AppErrorAlertItem: Identifiable {
    let id = UUID()
    let error: AppError
    let message: String

    init(error: AppError) {
        self.error = error
        self.message = error.errorDescription ?? ""
    }
}

extension View {
    /// Presents a localized alert bound to an optional `AppError`.
    func appErrorAlert(_ error: Binding<AppError?>) -> some View {
        alert(item: Binding<AppErrorAlertItem?>(
            get: { error.wrappedValue.map(AppErrorAlertItem.init) },
            set: { newValue in error.wrappedValue = newValue?.error }
        )) { item in
            Alert(
                title: Text(String(localized: "error.title", bundle: .appModule)),
                message: Text(item.message),
                dismissButton: .default(Text(String(localized: "common.ok", bundle: .appModule))) {
                    error.wrappedValue = nil
                }
            )
        }
    }
}
