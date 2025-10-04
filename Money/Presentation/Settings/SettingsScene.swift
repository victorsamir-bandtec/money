import SwiftUI

struct SettingsScene: View {
    @StateObject private var viewModel: SettingsViewModel

    init(environment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "settings.features")) {
                    Toggle(isOn: Binding(
                        get: { viewModel.featureFlags.useLiquidGlass },
                        set: { viewModel.toggleLiquidGlass($0) }
                    )) {
                        Label(String(localized: "settings.liquid"), systemImage: "drop")
                    }
                    Toggle(isOn: Binding(
                        get: { viewModel.featureFlags.useCloudSync },
                        set: { viewModel.toggleCloudSync($0) }
                    )) {
                        Label(String(localized: "settings.cloud"), systemImage: "icloud")
                    }
                    Toggle(isOn: Binding(
                        get: { viewModel.featureFlags.enableNotifications },
                        set: { viewModel.toggleNotifications($0) }
                    )) {
                        Label(String(localized: "settings.notifications"), systemImage: "bell")
                    }
                    Button(String(localized: "settings.notifications.request")) {
                        Task { await viewModel.requestNotificationPermission() }
                    }
                    .disabled(!viewModel.featureFlags.enableNotifications)
                }

                Section(String(localized: "settings.data")) {
                    Button(String(localized: "settings.sample")) {
                        Task { await viewModel.populateSample() }
                    }
                    .disabled(viewModel.isLoadingSampleData)

                    Button(String(localized: "settings.export")) {
                        viewModel.exportCSV()
                    }
                    if let url = viewModel.exportURL {
                        ShareLink(item: url) {
                            Label(String(localized: "settings.share"), systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Section(String(localized: "settings.about")) {
                    LabeledContent(String(localized: "settings.version"), value: Bundle.main.appVersion)
                    LabeledContent(String(localized: "settings.developer"), value: "Money App Team")
                }
            }
            .navigationTitle(String(localized: "settings.title"))
        }
        .alert(item: Binding(get: {
            viewModel.error.map { LocalizedErrorWrapper(error: $0) }
        }, set: { _ in viewModel.error = nil })) { wrapper in
            Alert(
                title: Text(String(localized: "error.title")),
                message: Text(wrapper.localizedDescription),
                dismissButton: .default(Text(String(localized: "common.ok")))
            )
        }
    }
}

private struct LocalizedErrorWrapper: Identifiable {
    let id = UUID()
    let error: AppError

    var localizedDescription: String {
        error.errorDescription ?? ""
    }
}

private extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
