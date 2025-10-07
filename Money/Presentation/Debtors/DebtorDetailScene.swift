import SwiftUI
import SwiftData

struct DebtorDetailScene: View {
    @StateObject private var viewModel: DebtorDetailViewModel
    private let environment: AppEnvironment
    private let context: ModelContext
    @State private var showingAgreementForm = false
    @State private var draft = AgreementDraft()

    init(debtor: Debtor, environment: AppEnvironment, context: ModelContext) {
        self.environment = environment
        self.context = context
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
        ScrollView {
            VStack(spacing: 28) {
                metricsSection
                debtorInfoSection
                agreementsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(DebtorDetailBackground())
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
        .appErrorAlert(errorBinding)
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            MetricCard(
                title: "debtor.metric.remaining",
                value: environment.currencyFormatter.string(from: viewModel.totalRemaining),
                caption: "debtor.metric.remaining.caption",
                icon: "exclamationmark.triangle.fill",
                tint: viewModel.totalRemaining > 0 ? .orange : .green,
                style: .prominent
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .leading, spacing: 16) {
                MetricCard(
                    title: "debtor.metric.total",
                    value: environment.currencyFormatter.string(from: viewModel.totalAgreementsValue),
                    caption: "debtor.metric.total.caption",
                    icon: "banknote.fill",
                    tint: .blue
                )
                MetricCard(
                    title: "debtor.metric.paid",
                    value: environment.currencyFormatter.string(from: viewModel.totalPaid),
                    caption: "debtor.metric.paid.caption",
                    icon: "checkmark.seal.fill",
                    tint: .green
                )
                MetricCard(
                    title: "debtor.metric.installments.paid",
                    value: "\(viewModel.paidInstallmentsCount)",
                    caption: "debtor.metric.installments.paid.caption",
                    icon: "checklist",
                    tint: .teal
                )
                MetricCard(
                    title: "debtor.metric.installments.total",
                    value: "\(viewModel.totalInstallmentsCount)",
                    caption: "debtor.metric.installments.total.caption",
                    icon: "list.number",
                    tint: .purple
                )
            }
        }
    }

    private var debtorInfoSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "debtor.info.title"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    DebtorAvatar(initials: viewModel.debtor.initials)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.debtor.name)
                            .font(.title3.weight(.semibold))

                        if let phone = viewModel.debtor.phone {
                            phoneLink(phone)
                        }
                    }

                    Spacer(minLength: 0)
                }

                if let note = viewModel.debtor.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .moneyCard(
                tint: .appThemeColor,
                cornerRadius: 24,
                shadow: .compact,
                intensity: .subtle
            )
        }
    }

    private func phoneLink(_ phone: String) -> some View {
        Group {
            if let url = URL(string: "tel://\(phone)") {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.caption)
                        Text(phone)
                            .font(.subheadline)
                    }
                    .foregroundStyle(Color.accentColor)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                        .font(.caption)
                    Text(phone)
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private var agreementsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "debtor.agreements"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(String(localized: "debtor.agreements.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if viewModel.agreements.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.accentColor)

                    Text(String(localized: "debtor.agreements.empty"))
                        .font(.headline)

                    Text(String(localized: "debtor.agreements.empty.message"))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(
                    GlassBackgroundStyle.current.material,
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08))
                )
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.agreements, id: \.id) { agreement in
                        NavigationLink(destination: AgreementDetailScene(agreement: agreement, environment: environment, context: context)) {
                            AgreementCard(agreement: agreement, formatter: environment.currencyFormatter) { installment, status in
                                viewModel.mark(installment: installment, as: status)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var errorBinding: Binding<AppError?> {
        Binding(
            get: { viewModel.error },
            set: { viewModel.error = $0 }
        )
    }
}

private struct AgreementCard: View {
    let agreement: DebtAgreement
    let formatter: CurrencyFormatter
    var action: (Installment, InstallmentStatus) -> Void

    private var cardTint: Color {
        agreement.closed ? .green : .appThemeColor
    }

    private var cardIntensity: MoneyCardIntensity {
        agreement.closed ? .subtle : .standard
    }

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
                .frame(maxWidth: .infinity, alignment: .leading)
                .moneyCard(
                    tint: tint(for: installment.status),
                    cornerRadius: 18,
                    shadow: .compact,
                    intensity: .subtle
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyCard(
            tint: cardTint,
            cornerRadius: 24,
            shadow: .standard,
            intensity: cardIntensity
        )
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

    private func tint(for status: InstallmentStatus) -> Color {
        switch status {
        case .paid: return .green
        case .partial: return .yellow
        case .overdue: return .orange
        case .pending:
            return agreement.closed ? .green : .appThemeColor
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

private struct DebtorDetailBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(colorScheme == .dark ? 1 : 0.6)
            RadialGradient(
                colors: [Color.accentColor.opacity(colorScheme == .dark ? 0.20 : 0.10), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.05, green: 0.08, blue: 0.13),
                Color(red: 0.01, green: 0.02, blue: 0.05)
            ]
        }
        return [
            Color(.systemGroupedBackground),
            Color(.secondarySystemGroupedBackground)
        ]
    }
}
