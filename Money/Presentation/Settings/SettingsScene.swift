import SwiftUI

struct SettingsScene: View {
    @StateObject private var viewModel: SettingsViewModel
    @State private var salaryDraft = SalaryDraft()
    @State private var showingSalaryForm = false
    private let formatter: CurrencyFormatter
    private let rowInsets = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)

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
            .listSectionSpacing(20)
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .background(AppBackground(variant: .dashboard))
            .navigationTitle(String(localized: "settings.title"))
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(viewModel.currentTheme.colorScheme)
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
        .task { viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .financialDataDidChange)) { _ in
            viewModel.load()
        }
        .sheet(isPresented: $showingSalaryForm) {
            SalaryForm(draft: $salaryDraft, completion: handleSalaryForm)
        }
        .appErrorAlert(errorBinding)
    }

    private var salarySection: some View {
        Section {
            Button(action: salaryAction) {
                SettingsSalaryRow(
                    salary: viewModel.salary,
                    formatter: formatter
                )
            }
            .buttonStyle(.plain)
            .settingsListRowModifier(insets: rowInsets)
            .accessibilityLabel(salaryActionTitle)
            .accessibilityIdentifier(salaryActionAccessibilityIdentifier)
        } header: {
            Text("settings.salary.section")
        }
    }

    private var preferencesSection: some View {
        Section {
            SettingsRow(
                title: "settings.notifications",
                icon: "bell.fill",
                color: .overdueRed
            ) {
                Toggle("", isOn: notificationsBinding)
                    .labelsHidden()
                    .accessibilityIdentifier("settings.notifications.toggle")
                    .accessibilityLabel(String(localized: "settings.notifications.toggle"))
            }
            .settingsListRowModifier(insets: rowInsets)
            .accessibilityElement(children: .combine)

            if !viewModel.notificationsEnabled {
                Button {
                    Task { await viewModel.requestNotificationPermission() }
                } label: {
                    SettingsRow(title: "settings.notifications.request", icon: "shield.checkered", color: .appThemeColor)
                }
                .buttonStyle(.plain)
                .settingsListRowModifier(insets: rowInsets)
            }

            SettingsRow(
                title: "settings.theme",
                icon: "paintbrush.fill",
                color: .appThemeColor,
                subtitle: viewModel.currentTheme.localizedLabel
            ) {
                Picker("", selection: themeBinding) {
                    ForEach(AppThemeOption.allCases) { option in
                        Text(option.localizedLabel).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .settingsListRowModifier(insets: rowInsets)
        } header: {
            Text("settings.preferences")
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                viewModel.exportCSV()
            } label: {
                SettingsRow(title: "settings.export", icon: "square.and.arrow.up.fill", color: .appThemeColor)
            }
            .buttonStyle(.plain)
            .settingsListRowModifier(insets: rowInsets)
            .accessibilityIdentifier("settings.export.csv")
            .accessibilityLabel(String(localized: "settings.export.csv"))

            if let url = viewModel.exportURL {
                ShareLink(item: url) {
                    SettingsRow(title: "settings.share", icon: "square.and.arrow.up", color: .appThemeColor)
                }
                .settingsListRowModifier(insets: rowInsets)
            }

            Button {
                viewModel.populateSampleData()
            } label: {
                SettingsRow(title: "settings.data.populate", icon: "arrow.down.doc.fill", color: .warningOrange)
            }
            .buttonStyle(.plain)
            .settingsListRowModifier(insets: rowInsets)

            Button(role: .destructive) {
                viewModel.showingClearConfirmation = true
            } label: {
                SettingsRow(title: "settings.data.clear", icon: "trash.fill", color: .overdueRed)
            }
            .buttonStyle(.plain)
            .settingsListRowModifier(insets: rowInsets)
        } header: {
            Text("settings.data")
        }
    }

    private var supportSection: some View {
        Section {
            Button {
                viewModel.openHelp()
            } label: {
                SettingsRow(title: "settings.help", icon: "questionmark.circle.fill", color: .blue)
            }
            .buttonStyle(.plain)
            .settingsListRowModifier(insets: rowInsets)

            Button {
                viewModel.rateApp()
            } label: {
                SettingsRow(title: "settings.rate", icon: "star.fill", color: .warningOrange)
            }
            .buttonStyle(.plain)
            .settingsListRowModifier(insets: rowInsets)

            Button {
                viewModel.openContact()
            } label: {
                SettingsRow(title: "settings.contact", icon: "envelope.fill", color: .appThemeColor)
            }
            .buttonStyle(.plain)
            .settingsListRowModifier(insets: rowInsets)
        } header: {
            Text("settings.support")
        }
    }

    private var aboutSection: some View {
        Section {
            SettingsRow(
                title: "settings.version",
                icon: "info.circle.fill",
                color: .secondary,
                subtitle: Bundle.main.appVersion
            )
            .settingsListRowModifier(insets: rowInsets)

            SettingsRow(
                title: "settings.developer",
                icon: "person.crop.circle.fill",
                color: .secondary,
                subtitle: "Money App Team"
            )
            .settingsListRowModifier(insets: rowInsets)
        } header: {
            Text("settings.about")
        }
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.notificationsEnabled },
            set: { viewModel.toggleNotifications($0) }
        )
    }

    private var themeBinding: Binding<AppThemeOption> {
        Binding(
            get: { viewModel.currentTheme },
            set: { viewModel.setTheme($0) }
        )
    }

    private var salaryActionTitle: String {
        if viewModel.salary == nil {
            return String(localized: "settings.salary.add")
        }
        return String(localized: "settings.salary.edit")
    }

    private var salaryActionAccessibilityIdentifier: String {
        viewModel.salary == nil ? "settings.salary.add" : "settings.salary.edit"
    }

    private var salaryAction: () -> Void {
        if viewModel.salary == nil {
            return presentSalaryCreation
        }
        return { presentSalaryEditor(viewModel.salary!) }
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
            showingSalaryForm = false
        case .cancel:
            showingSalaryForm = false
        }
    }

    private var errorBinding: Binding<AppError?> {
        Binding(
            get: { viewModel.error },
            set: { viewModel.error = $0 }
        )
    }
}

private extension View {
    func settingsListRowModifier(insets: EdgeInsets) -> some View {
        self
            .listRowInsets(insets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color(.secondarySystemGroupedBackground).opacity(0.82))
    }
}

private struct SettingsSalaryRow: View {
    let salary: SalarySnapshot?
    let formatter: CurrencyFormatter

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background((salary == nil ? Color.gray : Color.appThemeColor).gradient)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                if let salary {
                    Text("settings.salary.title")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(formatter.string(from: salary.amount))
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(.primary)

                    Text(salary.referenceMonth, format: .dateTime.month(.wide).year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("settings.salary.add")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text("settings.salary.empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: salary == nil ? "plus.circle" : "chevron.right")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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
                        .datePickerStyle(.compact)
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
