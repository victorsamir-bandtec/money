import SwiftUI
import SwiftData

struct DebtorDetailScene: View {
    @StateObject private var viewModel: DebtorDetailViewModel
    private let environment: AppEnvironment
    private let context: ModelContext
    @State private var showingAgreementForm = false
    @State private var draft = AgreementDraft()
    @State private var expandedAgreements: Set<UUID> = []
    @State private var navigateToCreditProfile = false

    init(debtor: Debtor, environment: AppEnvironment, context: ModelContext) {
        self.environment = environment
        self.context = context
        let scheduler: NotificationScheduling? = environment.featureFlags.enableNotifications ? environment.notificationScheduler : nil
        let viewModel = DebtorDetailViewModel(
            debtor: debtor,
            context: context,
            calculator: environment.financeCalculator,
            debtService: environment.debtService,
            commandService: environment.commandService,
            notificationScheduler: scheduler
        )
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                metricsSection
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
            // Main Highlight Card (Saldo Devedor)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.totalRemaining > 0 ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: viewModel.totalRemaining > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(viewModel.totalRemaining > 0 ? Color.orange : Color.green)
                        }
                    
                    Text("debtor.metric.remaining")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(viewModel.totalRemaining > 0 ? Color.orange : Color.green)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(environment.currencyFormatter.string(from: viewModel.totalRemaining))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    
                    Text("debtor.metric.remaining.caption")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .moneyCard(
                tint: Color(.systemGray4),
                cornerRadius: 28,
                shadow: .standard,
                intensity: .subtle
            )

            // Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .leading, spacing: 16) {
                DebtorGridMetricCard(
                    title: "debtor.metric.total",
                    value: environment.currencyFormatter.string(from: viewModel.totalAgreementsValue),
                    caption: "debtor.metric.total.caption",
                    icon: "banknote.fill",
                    tint: .blue
                )
                
                DebtorGridMetricCard(
                    title: "debtor.metric.paid",
                    value: environment.currencyFormatter.string(from: viewModel.totalPaid),
                    caption: "debtor.metric.paid.caption",
                    icon: "checkmark.seal.fill",
                    tint: .green
                )
                
                DebtorGridMetricCard(
                    title: "debtor.metric.installments.paid",
                    value: "\(viewModel.paidInstallmentsCount)",
                    caption: "debtor.metric.installments.paid.caption",
                    icon: "checklist",
                    tint: .teal
                )
                
                DebtorGridMetricCard(
                    title: "debtor.metric.installments.total",
                    value: "\(viewModel.totalInstallmentsCount)",
                    caption: "debtor.metric.installments.total.caption",
                    icon: "list.number",
                    tint: .purple
                )
            }

            // Credit Profile Button
            Button(action: { navigateToCreditProfile = true }) {
                HStack(spacing: 14) {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.purple)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                        )
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("credit.profile.title")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("Análise de comportamento e risco")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.forward")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .moneyCard(tint: Color(.systemGray4), cornerRadius: 24, shadow: .compact, intensity: .subtle)
            }
            .buttonStyle(.plain)
            .navigationDestination(isPresented: $navigateToCreditProfile) {
                CreditProfileDetailView(debtor: viewModel.debtor, environment: environment, context: context)
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

            agreementsContent
        }
    }

    @ViewBuilder
    private var agreementsContent: some View {
        if viewModel.agreements.isEmpty {
            agreementsEmptyContent
        } else {
            agreementsListContent
        }
    }

    private var agreementsEmptyContent: some View {
        AppEmptyState(
            icon: "doc.text.fill",
            title: "debtor.agreements.empty",
            message: "debtor.agreements.empty.message"
        )
    }

    private var agreementsListContent: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.agreements, id: \.id) { agreement in
                let overview = viewModel.overview(for: agreement)
                let installments = viewModel.installments(for: agreement)
                let isExpanded = expandedAgreements.contains(agreement.id)

                AgreementCard(
                    agreement: agreement,
                    overview: overview,
                    installments: installments,
                    formatter: environment.currencyFormatter,
                    isExpanded: isExpanded,
                    onToggle: { toggleAgreementExpansion(agreement.id) },
                    detailDestination: AnyView(AgreementDetailScene(agreement: agreement, environment: environment, context: context))
                ) { installment, status in
                    viewModel.mark(installment: installment, as: status)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        viewModel.deleteAgreement(agreement)
                    } label: {
                        Label("debtor.agreement.delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func toggleAgreementExpansion(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedAgreements.contains(id) {
                expandedAgreements.remove(id)
            } else {
                expandedAgreements.insert(id)
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
    let overview: DebtorDetailViewModel.AgreementOverview
    let installments: [Installment]
    let formatter: CurrencyFormatter
    let isExpanded: Bool
    var onToggle: () -> Void
    let detailDestination: AnyView
    var action: (Installment, InstallmentStatus) -> Void

    private var cardTint: Color {
        overview.isClosed ? .green : .appThemeColor
    }

    private var cardIntensity: MoneyCardIntensity {
        overview.isClosed ? .subtle : .standard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading) {
                    Text(agreement.title ?? String(localized: "debtor.agreement.untitled"))
                        .font(.headline)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
                NavigationLink(destination: detailDestination) {
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("debtor.agreement.open.detail")
                }
                .buttonStyle(.plain)
                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(isExpanded ? "common.collapse" : "common.expand")
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                ForEach(installments, id: \.id) { installment in
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
                                    Text(installment.status.localizedDescription)
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
                        tint: installment.status.tintColor(isClosed: overview.isClosed),
                        cornerRadius: 18,
                        shadow: .compact,
                        intensity: .subtle
                    )
                }
            } else {
                collapsedOverview
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
        localizedFormat("debtor.agreement.summary", overview.totalInstallments, overview.openInstallments)
    }

    private var statusBadge: some View {
        overview.isClosed ? StatusBadge.closed() : StatusBadge.open()
    }

    private var collapsedOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedFormat("debtor.agreement.paid.progress", overview.paidInstallments, overview.totalInstallments))
                        .font(.subheadline.weight(.semibold))
                    Text(localizedFormat("debtor.agreement.remaining.amount", formatter.string(from: overview.remainingAmount)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ProgressView(
                value: Double(overview.paidInstallments),
                total: Double(max(overview.totalInstallments, 1))
            )
            .tint(overview.isClosed ? .green : .appThemeColor)
            .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
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
                    CurrencyField("agreement.form.principal", value: $draft.principal, currencyCode: draft.currencyCode)
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

private struct DebtorGridMetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let caption: LocalizedStringKey
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyCard(
            tint: Color(.systemGray4),
            cornerRadius: 22,
            shadow: .compact,
            intensity: .subtle
        )
    }
}
