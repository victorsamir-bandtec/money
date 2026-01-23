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
            List {
                salarySection
                preferencesSection
                dataSection
                supportSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "settings.title"))
            .preferredColorScheme(viewModel.currentTheme.colorScheme)
        }
        .task { viewModel.load() }
        .sheet(isPresented: $showingSalaryForm) {
            SalaryForm(draft: $salaryDraft, completion: handleSalaryForm)
        }
        .appErrorAlert(errorBinding)
    }

    private var salarySection: some View {
        Section {
            SettingsSalaryRow(
                salary: viewModel.salary,
                formatter: formatter,
                onCreate: presentSalaryCreation,
                onEdit: presentSalaryEditor
            )
        } header: {
            Text("settings.salary.section")
        }
    }

    private var preferencesSection: some View {
        Section {
            // Notifications
            HStack {
                SettingsRow(
                    title: "settings.notifications",
                    icon: "bell.fill",
                    color: .red
                )
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.notificationsEnabled },
                    set: { viewModel.toggleNotifications($0) }
                ))
                .labelsHidden()
            }
            
            if !viewModel.notificationsEnabled {
                 Button("settings.notifications.request") {
                    Task { await viewModel.requestNotificationPermission() }
                }
            }

            // Theme
            Picker(selection: $viewModel.currentTheme) {
                ForEach(AppThemeOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            } label: {
                SettingsRow(
                    title: "settings.theme",
                    icon: "paintbrush.fill",
                    color: .blue
                )
            }
            .pickerStyle(.menu)
        } header: {
            Text("settings.preferences")
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                viewModel.exportCSV()
            } label: {
                SettingsRow(title: "settings.export", icon: "square.and.arrow.up.fill", color: .green)
            }

            if let url = viewModel.exportURL {
                ShareLink(item: url) {
                    Label("settings.share", systemImage: "square.and.arrow.up")
                }
            }

            Button {
                viewModel.populateSampleData()
            } label: {
                SettingsRow(title: "settings.data.populate", icon: "arrow.down.doc.fill", color: .orange)
            }

            Button(role: .destructive) {
                viewModel.showingClearConfirmation = true
            } label: {
                SettingsRow(title: "settings.data.clear", icon: "trash.fill", color: .gray)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("settings.data")
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
    
    private var supportSection: some View {
        Section {
            Button {
                viewModel.openHelp()
            } label: {
                SettingsRow(title: "settings.help", icon: "questionmark.circle.fill", color: .blue)
            }
            
            Button {
                viewModel.rateApp()
            } label: {
                SettingsRow(title: "settings.rate", icon: "star.fill", color: .yellow)
            }
            
            Button {
                viewModel.openContact()
            } label: {
                SettingsRow(title: "settings.contact", icon: "envelope.fill", color: .gray)
            }
        } header: {
            Text("settings.support")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("settings.version")
                Spacer()
                Text(Bundle.main.appVersion)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("settings.developer")
                Spacer()
                Text("Money App Team")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("settings.about")
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
            Button {
                onEdit(salary)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.green.gradient)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatter.string(from: salary.amount))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text(salary.referenceMonth, format: .dateTime.month(.wide).year())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        } else {
            Button(action: onCreate) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.gray.gradient)
                        .clipShape(Circle())
                    
                    Text("settings.salary.add")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 4)
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
                Section("salary.form.section") {
                    CurrencyField("salary.form.amount", value: $draft.amount)
                    DatePicker("salary.form.month", selection: $draft.month, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                }

                Section("salary.form.note") {
                    TextField("salary.form.note.placeholder", text: $draft.note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("salary.form.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        completion(.cancel)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
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
