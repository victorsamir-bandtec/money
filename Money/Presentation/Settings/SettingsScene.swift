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
            .navigationTitle(String(localized: "settings.title"))
        }
        .task { viewModel.load() }
        .sheet(isPresented: $showingSalaryForm) {
            SalaryForm(draft: $salaryDraft, completion: handleSalaryForm)
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

    private var salarySection: some View {
        Section(String(localized: "settings.salary.section")) {
            SettingsSalaryRow(
                salary: viewModel.salary,
                history: viewModel.salaryHistory,
                formatter: formatter,
                onCreate: presentSalaryCreation,
                onEdit: presentSalaryEditor
            )
        }
        .textCase(nil)
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
}

private struct SettingsSalaryRow: View {
    let salary: SalarySnapshot?
    let history: [SalarySnapshot]
    let formatter: CurrencyFormatter
    var onCreate: () -> Void
    var onEdit: (SalarySnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            salaryContent
            if history.count > 1 {
                Divider()
                historyList
            }
        }
        .padding(.vertical, 12)
    }

    private var header: some View {
        HStack {
            Label {
                Text(String(localized: "settings.salary.row.title"))
                    .font(.headline)
            } icon: {
                Image(systemName: "dollarsign.circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
            }
            .labelStyle(.titleAndIcon)

            Spacer(minLength: 12)

            if let salary {
                Button(String(localized: "settings.salary.edit")) {
                    onEdit(salary)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button(String(localized: "settings.salary.add"), action: onCreate)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private var salaryContent: some View {
        Group {
            if let salary {
                VStack(alignment: .leading, spacing: 6) {
                    Text(formatter.string(from: salary.amount))
                        .font(.headline.weight(.semibold))
                    Text(salary.referenceMonth, format: .dateTime.month(.wide).year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let note = salary.note, !note.isEmpty {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(String(localized: "settings.salary.empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "settings.salary.history"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(history.dropFirst(), id: \.id) { snapshot in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.referenceMonth, format: .dateTime.month(.abbreviated).year())
                                .font(.caption.weight(.semibold))
                            Text(formatter.string(from: snapshot.amount))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                }
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
