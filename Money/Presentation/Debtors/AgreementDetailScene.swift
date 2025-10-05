import SwiftUI
import SwiftData

struct AgreementDetailScene: View {
    @StateObject private var viewModel: AgreementDetailViewModel
    private let environment: AppEnvironment
    @State private var selectedInstallment: Installment?
    @State private var showingPaymentForm = false
    @State private var paymentDraft = PaymentDraft()

    init(agreement: DebtAgreement, environment: AppEnvironment, context: ModelContext) {
        self.environment = environment
        let viewModel = AgreementDetailViewModel(agreement: agreement, context: context)
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                metricsSection
                agreementInfoSection
                installmentsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(AgreementDetailBackground())
        .navigationTitle(viewModel.agreement.title ?? String(localized: "debtor.agreement.untitled"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPaymentForm) {
            if let installment = selectedInstallment {
                PaymentForm(
                    installment: installment,
                    draft: $paymentDraft,
                    formatter: environment.currencyFormatter
                ) { action in
                    switch action {
                    case .save(let draft):
                        viewModel.registerPayment(
                            for: installment,
                            amount: draft.amount,
                            date: draft.date,
                            method: draft.method,
                            note: draft.note.isEmpty ? nil : draft.note
                        )
                        showingPaymentForm = false
                        paymentDraft = PaymentDraft()
                    case .cancel:
                        showingPaymentForm = false
                        paymentDraft = PaymentDraft()
                    }
                }
            }
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

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            MetricCard(
                title: "agreement.metric.remaining",
                value: environment.currencyFormatter.string(from: viewModel.remainingAmount),
                caption: "agreement.metric.remaining.caption",
                icon: "exclamationmark.triangle.fill",
                tint: viewModel.remainingAmount > 0 ? .orange : .green,
                style: .prominent
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .leading, spacing: 16) {
                MetricCard(
                    title: "agreement.metric.total",
                    value: environment.currencyFormatter.string(from: viewModel.totalAmount),
                    caption: "agreement.metric.total.caption",
                    icon: "banknote.fill",
                    tint: .blue
                )
                MetricCard(
                    title: "agreement.metric.paid",
                    value: environment.currencyFormatter.string(from: viewModel.totalPaid),
                    caption: "agreement.metric.paid.caption",
                    icon: "checkmark.seal.fill",
                    tint: .green
                )
                MetricCard(
                    title: "agreement.metric.installments.paid",
                    value: "\(viewModel.paidInstallmentsCount)/\(viewModel.agreement.installmentCount)",
                    caption: "agreement.metric.installments.paid.caption",
                    icon: "checklist",
                    tint: .teal
                )
                MetricCard(
                    title: "agreement.metric.installments.overdue",
                    value: "\(viewModel.overdueInstallmentsCount)",
                    caption: "agreement.metric.installments.overdue.caption",
                    icon: "clock.badge.exclamationmark.fill",
                    tint: .red
                )
            }

            // Progress Card
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.title3)
                        .foregroundStyle(.purple)
                    Text(String(localized: "agreement.progress"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(Int(viewModel.progressPercentage))%")
                        .font(.title3.bold())
                        .foregroundStyle(.purple)
                }

                ProgressView(value: viewModel.progressPercentage, total: 100)
                    .tint(.purple)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.purple.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.purple.opacity(0.15), radius: 12, x: 0, y: 8)
        }
    }

    private var agreementInfoSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "agreement.info.title"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                // Debtor
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "agreement.info.debtor"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.agreement.debtor.name)
                            .font(.subheadline.weight(.semibold))
                    }
                }

                Divider()

                // Principal amount
                InfoRow(
                    icon: "dollarsign.circle.fill",
                    label: "agreement.info.principal",
                    value: environment.currencyFormatter.string(from: viewModel.agreement.principal),
                    tint: .blue
                )

                // Interest rate
                if let interestRate = viewModel.agreement.interestRateMonthly, interestRate > 0 {
                    InfoRow(
                        icon: "percent.circle.fill",
                        label: "agreement.info.interest",
                        value: String(format: "%.2f%% ao mês", Double(truncating: (interestRate * 100) as NSNumber)),
                        tint: .orange
                    )
                }

                // Start date
                InfoRow(
                    icon: "calendar.circle.fill",
                    label: "agreement.info.startdate",
                    value: viewModel.agreement.startDate.formatted(date: .abbreviated, time: .omitted),
                    tint: .purple
                )

                // Status
                HStack(spacing: 12) {
                    Image(systemName: viewModel.agreement.closed ? "checkmark.seal.fill" : "clock.fill")
                        .font(.title3)
                        .foregroundStyle(viewModel.agreement.closed ? .green : .blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "agreement.info.status"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(localized: viewModel.agreement.closed ? "debtor.agreement.closed" : "debtor.agreement.open"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(viewModel.agreement.closed ? .green : .blue)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
        }
    }

    private var installmentsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "agreement.installments.title"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(String(localized: "agreement.installments.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(viewModel.sortedInstallments, id: \.id) { installment in
                    InstallmentCard(
                        installment: installment,
                        formatter: environment.currencyFormatter,
                        onPayment: {
                            selectedInstallment = installment
                            paymentDraft = PaymentDraft(amount: installment.remainingAmount)
                            showingPaymentForm = true
                        }
                    )
                }
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

// MARK: - Supporting Views

private struct InfoRow: View {
    let icon: String
    let label: LocalizedStringKey
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

private struct InstallmentCard: View {
    let installment: Installment
    let formatter: CurrencyFormatter
    var onPayment: () -> Void
    @State private var showPayments = false

    private var statusColor: Color {
        switch installment.status {
        case .paid: return .green
        case .partial: return .yellow
        case .overdue: return .red
        case .pending: return installment.isOverdue ? .orange : .cyan
        }
    }

    private var statusIcon: String {
        switch installment.status {
        case .paid: return "checkmark.circle.fill"
        case .partial: return "circle.lefthalf.filled"
        case .overdue: return "exclamationmark.circle.fill"
        case .pending: return "circle"
        }
    }

    private var statusLabel: LocalizedStringKey {
        switch installment.status {
        case .pending: return "status.pending"
        case .partial: return "status.partial"
        case .paid: return "status.paid"
        case .overdue: return "status.overdue"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedFormat("debtor.installment.number", installment.number))
                        .font(.headline)
                    Text(installment.dueDate, format: .dateTime.day().month().year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatter.string(from: installment.amount))
                        .font(.title3.bold())
                    HStack(spacing: 4) {
                        Image(systemName: statusIcon)
                            .font(.caption)
                        Text(statusLabel)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15), in: Capsule())
                }
            }

            // Progress
            if installment.paidAmount > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(String(localized: "payment.paid"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatter.string(from: installment.paidAmount))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    ProgressView(
                        value: Double(truncating: installment.paidAmount as NSNumber),
                        total: Double(truncating: installment.amount as NSNumber)
                    )
                    .tint(.green)
                }
            }

            // Payments list
            if !installment.payments.isEmpty {
                Button(action: { showPayments.toggle() }) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.caption)
                        Text(String(localized: "payment.history"))
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Image(systemName: showPayments ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                    .padding(10)
                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                if showPayments {
                    VStack(spacing: 8) {
                        ForEach(installment.payments.sorted(by: { $0.date > $1.date }), id: \.id) { payment in
                            PaymentRow(payment: payment, formatter: formatter)
                        }
                    }
                }
            }

            // Register payment button
            if installment.status != .paid {
                Button(action: onPayment) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(String(localized: "payment.register"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(statusColor.opacity(0.25), lineWidth: 1.5)
        )
        .shadow(color: statusColor.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

private struct PaymentRow: View {
    let payment: Payment
    let formatter: CurrencyFormatter

    private var methodLabel: LocalizedStringKey {
        switch payment.method {
        case .pix: return "payment.method.pix"
        case .cash: return "payment.method.cash"
        case .transfer: return "payment.method.transfer"
        case .other: return "payment.method.other"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text(payment.date, format: .dateTime.day().month().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(methodLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatter.string(from: payment.amount))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
        }
        .padding(10)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct PaymentForm: View {
    let installment: Installment
    @Binding var draft: PaymentDraft
    let formatter: CurrencyFormatter
    var completion: (ResultAction) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "payment.form.details")) {
                    TextField(String(localized: "payment.form.amount"), value: $draft.amount, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker(String(localized: "payment.form.date"), selection: $draft.date, displayedComponents: .date)
                    Picker(String(localized: "payment.form.method"), selection: $draft.method) {
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            Text(methodLabel(for: method)).tag(method)
                        }
                    }
                    TextField(String(localized: "payment.form.note"), text: $draft.note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    HStack {
                        Text(String(localized: "payment.form.remaining"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatter.string(from: installment.remainingAmount))
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle(String(localized: "payment.form.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { completion(.cancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) { completion(.save(draft)) }
                        .disabled(draft.amount <= 0 || draft.amount > installment.remainingAmount)
                }
            }
        }
    }

    private func methodLabel(for method: PaymentMethod) -> LocalizedStringKey {
        switch method {
        case .pix: return "payment.method.pix"
        case .cash: return "payment.method.cash"
        case .transfer: return "payment.method.transfer"
        case .other: return "payment.method.other"
        }
    }

    enum ResultAction {
        case save(PaymentDraft)
        case cancel
    }
}

private struct AgreementDetailBackground: View {
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
                colors: [Color.blue.opacity(colorScheme == .dark ? 0.20 : 0.10), Color.clear],
                center: .topLeading,
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

private struct LocalizedErrorWrapper: Identifiable {
    let id = UUID()
    let error: AppError

    var localizedDescription: String {
        error.errorDescription ?? ""
    }
}
