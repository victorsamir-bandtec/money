import SwiftUI
import UIKit
import SwiftData

struct AgreementDetailScene: View {
    @StateObject private var viewModel: AgreementDetailViewModel
    private let environment: AppEnvironment
    @State private var selectedInstallment: Installment?
    @State private var paymentDraft = PaymentDraft()
    @State private var showingSuccessToast = false
    @State private var successMessage = ""
    @State private var toastDismissTask: Task<Void, Never>?

    init(agreement: DebtAgreement, environment: AppEnvironment, context: ModelContext) {
        self.environment = environment
        let scheduler: NotificationScheduling? = environment.featureFlags.enableNotifications ? environment.notificationScheduler : nil
        let viewModel = AgreementDetailViewModel(agreement: agreement, context: context, notificationScheduler: scheduler)
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            // Metrics
            Section {
                metricsSection
            }
            .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 8, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // Agreement info
            Section {
                agreementInfoSection
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 16, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // Installments
            Section {
                if viewModel.sortedInstallments.isEmpty {
                    // Empty state inside list
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        Text(String(localized: "agreement.installments.empty"))
                            .font(.headline)
                        Text(String(localized: "agreement.installments.empty.message"))
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity)
                    .background(
                        GlassBackgroundStyle.current.material,
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08))
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 24, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.sortedInstallments, id: \.id) { installment in
                        InstallmentCard(
                            installment: installment,
                            formatter: environment.currencyFormatter,
                            onPayment: {
                                selectedInstallment = installment
                                paymentDraft = PaymentDraft(amount: installment.remainingAmount)
                            },
            onMarkAsPaid: {
                viewModel.markAsPaidFull(installment)
                successMessage = String(localized: "payment.mark.paid.success")
                withAnimation(UIAnim.primarySpring) { showingSuccessToast = true }
                toastDismissTask?.cancel()
                toastDismissTask = Task { [toastHideDelay = UIAnim.toastHideDelay] in
                    try? await Task.sleep(nanoseconds: UInt64(toastHideDelay * 1_000_000_000))
                    await MainActor.run { withAnimation(UIAnim.toastOut) { showingSuccessToast = false } }
                }
            },
            onUndo: {
                viewModel.undoLastPayment(installment)
            }
        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "agreement.installments.title"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "agreement.installments.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 4)
            }
            .textCase(nil)
            .headerProminence(.increased)
        }
        .listStyle(.plain)
        .listRowSpacing(12)
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .background(AgreementDetailBackground())
        // Drive list animations by an Equatable proxy (IDs + status)
        .transaction { $0.animation = nil }
        .navigationTitle(viewModel.agreement.title ?? String(localized: "debtor.agreement.untitled"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedInstallment) { installment in
            RegisterPaymentScene(
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
                    selectedInstallment = nil
                    paymentDraft = PaymentDraft()
                case .cancel:
                    selectedInstallment = nil
                    paymentDraft = PaymentDraft()
                }
            }
            .presentationDetents([.medium, .large])
        }
        .task { try? viewModel.load() }
        .appErrorAlert(errorBinding)
        .overlay(alignment: .top) {
            if showingSuccessToast {
                SuccessToast(message: successMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
            }
        }
        .onDisappear { toastDismissTask?.cancel() }
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
            // Conteúdo do cartão que se move com o gesto
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

    // Removed "installmentsSection" (substituído por List + Section no body)

    private var errorBinding: Binding<AppError?> {
        Binding(
            get: { viewModel.error },
            set: { viewModel.error = $0 }
        )
    }
}

// Equatable animation key for list updates (IDs + status)
private struct InstallmentAnimKey: Hashable, Equatable {
    let id: UUID
    let status: Int
}

// Centraliza timings de animação para harmonia visual
private enum UIAnim {
    static let listSnappy = Animation.snappy(duration: 0.22)
    static let disclosure = Animation.snappy(duration: 0.22)
    static let primarySpring = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let buttonPress = Animation.spring(response: 0.22, dampingFraction: 0.8)
    static let toastIn = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let toastOut = Animation.easeOut(duration: 0.24)
    static let checkIn = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let checkFade = Animation.easeOut(duration: 0.24)
    static let checkFadeDelay: Double = 0.35
    static let toastHideDelay: Double = 1.8
    static let checkVisible: Double = 0.9
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
    var onMarkAsPaid: () -> Void
    var onUndo: () -> Void
    @State private var showPayments = false
    @State private var animationPhase: PaymentAnimationPhase = .idle
    @State private var animationTask: Task<Void, Never>?
    // Swipe state handled by built-in `.swipeActions`.

    private enum PaymentAnimationPhase: Equatable {
        case idle
        case confirming
        case completed
    }

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

    private var highlightBorderColor: Color {
        switch animationPhase {
        case .confirming:
            return statusColor.opacity(0.35)
        default:
            return statusColor.opacity(0.18)
        }
    }

    private var highlightFill: Color {
        switch animationPhase {
        case .confirming:
            return statusColor.opacity(0.12)
        default:
            return .clear
        }
    }

    var body: some View {
        // Card content
        ZStack {
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

            // Payments list (DisclosureGroup melhora gesto de swipe do row)
            if !installment.payments.isEmpty {
                DisclosureGroup(isExpanded: $showPayments) {
                    VStack(spacing: 8) {
                        ForEach(installment.payments.sorted(by: { $0.date > $1.date }), id: \.id) { payment in
                            PaymentRow(payment: payment, formatter: formatter)
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.caption)
                        Text(String(localized: "payment.history"))
                            .font(.caption.weight(.semibold))
                        Spacer()
                    }
                    .foregroundStyle(.blue)
                    .padding(10)
                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .animation(UIAnim.disclosure, value: showPayments)
            }

            // Action area
            if installment.status == .paid {
                // Paid status with undo option
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(String(localized: "payment.paid.full"))
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))

                    if !installment.payments.isEmpty {
                        Button(action: onUndo) {
                            Image(systemName: "arrow.uturn.backward")
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                                .frame(width: 44, height: 44)
                                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            // Fecha VStack do conteúdo antes dos modificadores do cartão
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(highlightFill)
                            .animation(.easeOut(duration: 0.25), value: animationPhase)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(highlightBorderColor, lineWidth: animationPhase == .confirming ? 2 : 1)
                    .animation(.easeOut(duration: 0.25), value: animationPhase)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
            .overlay {
                if animationPhase == .confirming {
                    CheckmarkAnimation()
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            // Movimento visual do cartão
        }
        // Clip para manter o cartão com cantos arredondados
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(Rectangle())
        // Swipe right-to-left (trailing) → Mark as paid
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if installment.status != .paid {
                Button {
                    startConfirmationHighlight()
                    onMarkAsPaid()
                } label: {
                    Label("payment.mark.paid", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
        }
        // Swipe left-to-right (leading) → Open register payment
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if installment.status != .paid {
                Button {
                    onPayment()
                } label: {
                    Label("payment.register", systemImage: "dollarsign.circle.fill")
                }
                .tint(.accentColor)
            }
        }
        .onAppear { animationPhase = installment.status == .paid ? .completed : .idle }
        .onChange(of: installment.status) { handleStatusChange($0) }
        .onDisappear { animationTask?.cancel() }
    }

    private func startConfirmationHighlight() {
        animationTask?.cancel()
        animationPhase = .confirming
        animationTask = Task { [delay = UIAnim.checkVisible] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run { animationPhase = .completed }
        }
    }

    private func handleStatusChange(_ status: InstallmentStatus) {
        switch status {
        case .paid:
            startConfirmationHighlight()
        case .partial, .pending, .overdue:
            animationTask?.cancel()
            animationPhase = .idle
        }
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

// Moved to RegisterPaymentScene.swift

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

// MARK: - Quick Action Components

private struct QuickActionButton: View {
    enum ButtonStyle {
        case primary
        case secondary
    }

    let title: LocalizedStringKey
    let icon: String
    let color: Color
    var style: ButtonStyle = .primary
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(UIAnim.buttonPress) { isPressed = true }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(UIAnim.buttonPress) { isPressed = false }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: style == .primary ? .infinity : nil)
            .padding(.vertical, 12)
            .padding(.horizontal, style == .primary ? 16 : 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(style == .primary ? color : color.opacity(0.15))
            )
            .foregroundStyle(style == .primary ? .white : color)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

private struct CheckmarkAnimation: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 100, height: 100)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(UIAnim.checkIn) {
                scale = 1.1
                opacity = 1
            }
            withAnimation(UIAnim.checkFade.delay(UIAnim.checkFadeDelay)) {
                opacity = 0
            }
        }
    }
}

private struct SuccessToast: View {
    let message: String
    @State private var offset: CGFloat = -100
    @State private var opacity: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(UIAnim.toastIn) {
                offset = 0
                opacity = 1
            }
        }
    }
}
