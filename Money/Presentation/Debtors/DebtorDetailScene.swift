import SwiftUI
import SwiftData

struct DebtorDetailScene: View {
    @StateObject private var viewModel: DebtorDetailViewModel
    private let environment: AppEnvironment
    @State private var showingAgreementForm = false
    @State private var draft = AgreementDraft()

    init(debtor: Debtor, environment: AppEnvironment, context: ModelContext) {
        self.environment = environment
        let scheduler: NotificationScheduling? = environment.featureFlags.enableNotifications ? environment.notificationScheduler : nil
        let viewModel = DebtorDetailViewModel(
            debtor: debtor,
            context: context,
            calculator: environment.financeCalculator,
            notificationScheduler: scheduler
        )
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            infoSection
            agreementsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.debtor.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(String(localized: "debtor.addAgreement")) {
                    showingAgreementForm = true
                }
            }
        }
        .sheet(isPresented: $showingAgreementForm) {
            AgreementForm(draft: $draft) { action in
                switch action {
                case .save(let draft):
                    viewModel.createAgreement(from: draft)
                    showingAgreementForm = false
                case .cancel:
                    showingAgreementForm = false
                }
            }
            .presentationDetents([.medium, .large])
        }
        .task { try? viewModel.load() }
        .alert(item: errorBinding) { wrapper in
            Alert(
                title: Text(String(localized: "error.title")),
                message: Text(wrapper.localizedDescription),
                dismissButton: .default(Text(String(localized: "common.ok")))
            )
        }
    }

    private var infoSection: some View {
        Section(String(localized: "debtor.info")) {
            LabeledContent(String(localized: "debtor.name"), value: viewModel.debtor.name)
            if let phone = viewModel.debtor.phone {
                phoneRow(phone)
            }
            if let note = viewModel.debtor.note, !note.isEmpty {
                Text(note)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var agreementsSection: some View {
        Section(String(localized: "debtor.agreements")) {
            if viewModel.agreements.isEmpty {
                ContentUnavailableView(String(localized: "debtor.agreements.empty"), systemImage: "doc.text")
            } else {
                ForEach(viewModel.agreements, id: \.id) { agreement in
                    AgreementCard(agreement: agreement, formatter: environment.currencyFormatter) { installment, status in
                        viewModel.mark(installment: installment, as: status)
                    }
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func phoneRow(_ phone: String) -> some View {
        Group {
            if let url = URL(string: "tel://\(phone)") {
                LabeledContent(String(localized: "debtor.phone")) {
                    Link(phone, destination: url)
                        .tint(.accentColor)
                }
            } else {
                LabeledContent(String(localized: "debtor.phone"), value: phone)
            }
        }
    }

    private var errorBinding: Binding<LocalizedErrorWrapper?> {
        Binding(
            get: { viewModel.error.map { LocalizedErrorWrapper(error: $0) } },
            set: { _ in viewModel.error = nil }
        )
    }
}

private struct LocalizedErrorWrapper: Identifiable {
    let id = UUID()
    let error: AppError

    var localizedDescription: String {
        error.errorDescription ?? ""
    }
}

private struct AgreementCard: View {
    let agreement: DebtAgreement
    let formatter: CurrencyFormatter
    var action: (Installment, InstallmentStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(agreement.title ?? String(localized: "debtor.agreement.untitled"))
                        .font(.headline)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }
            ForEach(agreement.installments.sorted(by: { $0.number < $1.number }), id: \.id) { installment in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(localizedFormat("debtor.installment.number", installment.number))
                        Spacer()
                        Text(formatter.string(from: installment.amount))
                    }
                    HStack {
                        Label {
                            Text(installment.dueDate, format: .dateTime.day().month().year())
                        } icon: {
                            Image(systemName: "calendar")
                        }
                        Spacer()
                        Menu {
                            Button(String(localized: "status.pending")) { action(installment, .pending) }
                            Button(String(localized: "status.partial")) { action(installment, .partial) }
                            Button(String(localized: "status.paid")) { action(installment, .paid) }
                            Button(String(localized: "status.overdue")) { action(installment, .overdue) }
                        } label: {
                            Label {
                                Text(statusLabel(for: installment.status))
                            } icon: {
                                Image(systemName: "ellipsis")
                            }
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(12)
                .glassBackground()
            }
        }
        .padding(16)
        .glassBackground()
    }

    private var summary: String {
        let open = agreement.installments.filter { $0.status != .paid }.count
        return localizedFormat("debtor.agreement.summary", agreement.installmentCount, open)
    }

    private var statusBadge: some View {
        let closed = agreement.closed
        return Text(String(localized: closed ? "debtor.agreement.closed" : "debtor.agreement.open"))
            .font(.caption).bold()
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background((closed ? Color.green : Color.blue).opacity(0.15), in: Capsule())
            .foregroundStyle(closed ? Color.green : Color.blue)
    }

    private func statusLabel(for status: InstallmentStatus) -> LocalizedStringKey {
        switch status {
        case .pending: return "status.pending"
        case .partial: return "status.partial"
        case .paid: return "status.paid"
        case .overdue: return "status.overdue"
        }
    }
}

private struct AgreementForm: View {
    @Binding var draft: AgreementDraft
    var completion: (ResultAction) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "agreement.form.details")) {
                    TextField(String(localized: "agreement.form.title"), text: $draft.title)
                    TextField(String(localized: "agreement.form.principal"), value: $draft.principal, format: .number)
                        .keyboardType(.decimalPad)
                    Stepper(value: $draft.installmentCount, in: 1...96) {
                        Text(localizedFormat("agreement.form.installments", draft.installmentCount))
                    }
                    DatePicker(String(localized: "agreement.form.firstDue"), selection: $draft.startDate, displayedComponents: .date)
                    TextField(String(localized: "agreement.form.interest"), value: Binding(
                        get: { draft.interestRate ?? .zero },
                        set: { draft.interestRate = $0 == .zero ? nil : $0 }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(String(localized: "agreement.form.title.header"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { completion(.cancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) { completion(.save(draft)) }
                        .disabled(draft.principal <= 0)
                }
            }
        }
    }

    enum ResultAction {
        case save(AgreementDraft)
        case cancel
    }
}
