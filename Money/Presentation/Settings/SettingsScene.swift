import SwiftUI

struct SettingsScene: View {
    @StateObject private var viewModel: SettingsViewModel
    @State private var salaryDraft = SalaryDraft()
    @State private var showingSalaryForm = false
    private let formatter: CurrencyFormatter

    init(environment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(environment: environment))
        self.formatter = environment.currencyFormatter
    }

    var body: some View {
        NavigationStack {
            Form {
                salarySection
                notificationsSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground(variant: .settings))
            .navigationTitle(String(localized: "settings.title"))
        }
        .task { viewModel.load() }
        .sheet(isPresented: $showingSalaryForm) {
            SalaryForm(draft: $salaryDraft, completion: handleSalaryForm)
        }
        .appErrorAlert(errorBinding)
    }

    private var salarySection: some View {
        Section(String(localized: "settings.salary.section")) {
            SettingsSalaryRow(
                salary: viewModel.salary,
                formatter: formatter,
                onCreate: presentSalaryCreation,
                onEdit: presentSalaryEditor
            )
        }
    }

    private var notificationsSection: some View {
        Section(String(localized: "settings.notifications.section")) {
            Toggle(isOn: Binding(
                get: { viewModel.notificationsEnabled },
                set: { viewModel.toggleNotifications($0) }
            )) {
                Label(String(localized: "settings.notifications"), systemImage: "bell")
            }

            Button(String(localized: "settings.notifications.request")) {
                Task { await viewModel.requestNotificationPermission() }
            }
            .disabled(!viewModel.notificationsEnabled)
        }
    }

    private var dataSection: some View {
        Section(String(localized: "settings.data")) {
            Button(String(localized: "settings.export")) {
                viewModel.exportCSV()
            }

            if let url = viewModel.exportURL {
                ShareLink(item: url) {
                    Label(String(localized: "settings.share"), systemImage: "square.and.arrow.up")
                }
            }

            Button(String(localized: "settings.data.populate")) {
                viewModel.populateSampleData()
            }

            Button(String(localized: "settings.data.clear"), role: .destructive) {
                viewModel.showingClearConfirmation = true
            }
        }
        .confirmationDialog(
            String(localized: "settings.data.clear.confirmation.title"),
            isPresented: $viewModel.showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.data.clear.confirmation.confirm"), role: .destructive) {
                viewModel.clearAllData()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.data.clear.confirmation.message"))
        }
    }

    private var aboutSection: some View {
        Section(String(localized: "settings.about")) {
            LabeledContent(String(localized: "settings.version"), value: Bundle.main.appVersion)
            LabeledContent(String(localized: "settings.developer"), value: "Money App Team")
        }
    }

    private func presentSalaryCreation() {
        salaryDraft = SalaryDraft()
        showingSalaryForm = true
    }

    private func presentSalaryEditor(_ salary: SalarySnapshot) {
        salaryDraft = SalaryDraft(snapshot: salary)
        showingSalaryForm = true
    }

    private func handleSalaryForm(_ result: SalaryForm.ResultAction) {
        switch result {
        case .save(let draft):
            viewModel.updateSalary(amount: draft.amount, month: draft.month, note: draft.note)
        case .cancel:
            break
        }
    }

    private var errorBinding: Binding<AppError?> {
        Binding(
            get: { viewModel.error },
            set: { viewModel.error = $0 }
        )
    }
}

private struct SettingsSalaryRow: View {
    let salary: SalarySnapshot?
    let formatter: CurrencyFormatter
    var onCreate: () -> Void
    var onEdit: (SalarySnapshot) -> Void

    var body: some View {
        if let salary {
            HStack(alignment: .top) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "settings.salary.row.title"))
                            .font(.body)
                        Text(formatter.string(from: salary.amount))
                            .font(.headline)
                        Text(salary.referenceMonth, format: .dateTime.month(.wide).year())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "dollarsign.circle")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.green)
                }

                Spacer()

                Button(String(localized: "settings.salary.edit")) {
                    onEdit(salary)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        } else {
            HStack {
                Label(String(localized: "settings.salary.row.title"), systemImage: "dollarsign.circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.green)

                Spacer()

                Button(String(localized: "settings.salary.add"), action: onCreate)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

private struct SalaryDraft: Equatable {
    var amount: Decimal = .zero
    var month: Date = .now
    var note: String = ""

    init() {}

    init(snapshot: SalarySnapshot) {
        amount = snapshot.amount
        month = snapshot.referenceMonth
        note = snapshot.note ?? ""
    }

    var isValid: Bool { amount > 0 }
}

private struct SalaryForm: View {
    @Binding var draft: SalaryDraft
    var completion: (ResultAction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "salary.form.section")) {
                    TextField(String(localized: "salary.form.amount"), value: $draft.amount, format: .currency(code: Locale.current.currency?.identifier ?? "BRL"))
                        .keyboardType(.decimalPad)
                    DatePicker(String(localized: "salary.form.month"), selection: $draft.month, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                }

                Section(String(localized: "salary.form.note")) {
                    TextField(String(localized: "salary.form.note.placeholder"), text: $draft.note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(String(localized: "salary.form.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        completion(.cancel)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        completion(.save(draft))
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
    }

    enum ResultAction {
        case save(SalaryDraft)
        case cancel
    }
}

private extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
