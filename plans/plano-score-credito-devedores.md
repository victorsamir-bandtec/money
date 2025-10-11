# Plano: Sistema de Score e Perfil de Crédito dos Devedores

## 📋 Contexto

O app Money atualmente rastreia devedores, acordos e pagamentos, mas não oferece análise histórica de comportamento de pagamento. Usuários tomam decisões de crédito baseadas em intuição, sem dados objetivos sobre:
- Quais devedores são confiáveis (pagam em dia)
- Quais são alto risco (atrasam frequentemente)
- Quanto de receita de juros cada devedor gerou
- Tendências de melhora ou piora no comportamento

### Problema de Negócio
Sem análise de risco, o usuário pode:
- ❌ Conceder novos créditos a maus pagadores (aumenta inadimplência)
- ❌ Cobrar juros inadequados (muito baixo em alto risco, muito alto em baixo risco)
- ❌ Perder tempo cobrando devedores com histórico de pontualidade
- ❌ Não identificar devedores que merecem condições melhores (fidelização)

### Solução Proposta
Sistema automatizado de score de crédito (0-100) que:
✅ Calcula pontuação baseada em comportamento histórico
✅ Classifica devedores em categorias de risco (Baixo/Médio/Alto)
✅ Mostra timeline de pagamentos para análise visual
✅ Alerta ao criar novo acordo sobre o histórico do devedor
✅ Rastreia rentabilidade (quanto ganhou com juros)

---

## 🎯 Objetivos

### Principais
1. **Reduzir inadimplência** - Identificar maus pagadores antes de conceder novo crédito
2. **Aumentar receita** - Precificar juros adequadamente baseado em risco
3. **Economizar tempo** - Focar esforços de cobrança nos devedores problemáticos
4. **Melhorar relacionamento** - Premiar devedores pontuais com melhores condições

### Secundários
- Dashboard com ranking de devedores por score
- Histórico completo de interações com cada devedor
- Análise de rentabilidade por devedor (receita de juros)
- Exportação de perfil de crédito em CSV

---

## 🏗️ Arquitetura Técnica

### 1. Camada de Dados (Core/Models)

#### 1.1 Novo Modelo: `DebtorCreditProfile`

**Arquivo:** `Money/Core/Models/CreditModels.swift`

```swift
import Foundation
import SwiftData

/// Perfil de crédito calculado automaticamente para cada devedor.
/// Armazena score, métricas de comportamento e histórico agregado.
@Model final class DebtorCreditProfile {
    @Attribute(.unique) var id: UUID
    @Relationship var debtor: Debtor

    // Score e classificação
    var score: Int                          // 0-100
    var riskLevelRaw: String                // low, medium, high
    var lastCalculated: Date

    // Métricas de pagamento
    var totalAgreements: Int                // Total de acordos históricos (incluindo fechados)
    var totalInstallments: Int              // Total de parcelas
    var paidOnTimeCount: Int                // Parcelas pagas no prazo
    var paidLateCount: Int                  // Parcelas pagas com atraso
    var overdueCount: Int                   // Parcelas em atraso atual
    var averageDaysLate: Double             // Média de dias de atraso
    var onTimePaymentRate: Double           // Taxa de pontualidade (0.0 - 1.0)

    // Métricas financeiras
    var totalLent: Decimal                  // Total emprestado (soma dos principals)
    var totalPaid: Decimal                  // Total pago pelo devedor
    var totalInterestEarned: Decimal        // Receita de juros gerada
    var currentOutstanding: Decimal         // Saldo devedor atual

    // Histórico e tendências
    var firstAgreementDate: Date?           // Data do primeiro acordo
    var lastPaymentDate: Date?              // Data do último pagamento
    var consecutiveOnTimePayments: Int      // Streak de pagamentos pontuais
    var longestDelayDays: Int               // Maior atraso registrado

    // Notas e flags
    var notes: String?                      // Observações do usuário
    var flaggedForReview: Bool              // Marcado para revisão manual

    var riskLevel: RiskLevel {
        get { RiskLevel(rawValue: riskLevelRaw) ?? .medium }
        set { riskLevelRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        debtor: Debtor,
        score: Int = 50,
        riskLevel: RiskLevel = .medium,
        lastCalculated: Date = .now
    ) {
        self.id = id
        self.debtor = debtor
        self.score = score
        self.riskLevelRaw = riskLevel.rawValue
        self.lastCalculated = lastCalculated
        self.totalAgreements = 0
        self.totalInstallments = 0
        self.paidOnTimeCount = 0
        self.paidLateCount = 0
        self.overdueCount = 0
        self.averageDaysLate = 0
        self.onTimePaymentRate = 0
        self.totalLent = .zero
        self.totalPaid = .zero
        self.totalInterestEarned = .zero
        self.currentOutstanding = .zero
        self.consecutiveOnTimePayments = 0
        self.longestDelayDays = 0
        self.flaggedForReview = false
    }
}

enum RiskLevel: String, Codable, CaseIterable, Sendable {
    case low      // Score 75-100: Excelente histórico
    case medium   // Score 40-74: Histórico mediano
    case high     // Score 0-39: Histórico problemático

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    var icon: String {
        switch self {
        case .low: return "checkmark.shield.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "xmark.shield.fill"
        }
    }

    var titleKey: String.LocalizationValue {
        switch self {
        case .low: return "credit.risk.low"
        case .medium: return "credit.risk.medium"
        case .high: return "credit.risk.high"
        }
    }

    var descriptionKey: String.LocalizationValue {
        switch self {
        case .low: return "credit.risk.low.description"
        case .medium: return "credit.risk.medium.description"
        case .high: return "credit.risk.high.description"
        }
    }
}

/// Snapshot histórico de um pagamento para timeline
@Model final class PaymentHistorySnapshot {
    @Attribute(.unique) var id: UUID
    @Relationship var profile: DebtorCreditProfile

    var paymentDate: Date
    var dueDate: Date
    var amount: Decimal
    var daysLate: Int                       // Negativo = adiantado, 0 = pontual, positivo = atrasado
    var installmentNumber: Int
    var agreementTitle: String?

    var wasOnTime: Bool { daysLate <= 0 }
    var wasLate: Bool { daysLate > 0 }

    init(
        id: UUID = UUID(),
        profile: DebtorCreditProfile,
        paymentDate: Date,
        dueDate: Date,
        amount: Decimal,
        daysLate: Int,
        installmentNumber: Int,
        agreementTitle: String? = nil
    ) {
        self.id = id
        self.profile = profile
        self.paymentDate = paymentDate
        self.dueDate = dueDate
        self.amount = amount
        self.daysLate = daysLate
        self.installmentNumber = installmentNumber
        self.agreementTitle = agreementTitle
    }
}
```

#### 1.2 Extensão do Modelo `Debtor`

**Arquivo:** `Money/Core/Models/FinanceModels.swift` (adicionar computed property)

```swift
extension Debtor {
    /// Acesso direto ao perfil de crédito (1:1)
    var creditProfile: DebtorCreditProfile? {
        // Recuperar via fetch no contexto
        // Implementação no ViewModel
        return nil
    }
}
```

---

### 2. Camada de Serviço (Core/Services)

#### 2.1 Serviço: `CreditScoreCalculator`

**Arquivo:** `Money/Core/Services/CreditScoreCalculator.swift`

```swift
import Foundation
import SwiftData

/// Calcula score de crédito (0-100) baseado em histórico de pagamentos.
struct CreditScoreCalculator: Sendable {

    /// Pesos para cálculo do score (soma = 1.0)
    struct Weights {
        let onTimePaymentRate: Double = 0.40        // 40% - Principal fator
        let averageDelayPenalty: Double = 0.25      // 25% - Atrasos médios
        let currentOverduePenalty: Double = 0.20    // 20% - Atrasos atuais
        let relationshipLength: Double = 0.10       // 10% - Fidelidade
        let recentTrend: Double = 0.05              // 5% - Tendência recente
    }

    private let weights = Weights()

    /// Recalcula completamente o perfil de crédito de um devedor.
    func calculateProfile(
        for debtor: Debtor,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> DebtorCreditProfile {

        // 1. Buscar ou criar perfil existente
        let profileDescriptor = FetchDescriptor<DebtorCreditProfile>(
            predicate: #Predicate { $0.debtor.id == debtor.id }
        )
        let existingProfile = try context.fetch(profileDescriptor).first
        let profile = existingProfile ?? DebtorCreditProfile(debtor: debtor)

        // 2. Buscar todos os acordos do devedor (incluindo fechados)
        let agreementsDescriptor = FetchDescriptor<DebtAgreement>(
            predicate: #Predicate { $0.debtor.id == debtor.id }
        )
        let agreements = try context.fetch(agreementsDescriptor)

        guard !agreements.isEmpty else {
            // Devedor sem histórico: score neutro
            profile.score = 50
            profile.riskLevel = .medium
            profile.lastCalculated = .now
            if existingProfile == nil { context.insert(profile) }
            try context.save()
            return profile
        }

        // 3. Coletar todas as parcelas
        var allInstallments: [Installment] = []
        for agreement in agreements {
            allInstallments.append(contentsOf: agreement.installments)
        }

        // 4. Calcular métricas básicas
        let metrics = calculateMetrics(
            installments: allInstallments,
            agreements: agreements,
            calendar: calendar
        )

        // 5. Calcular score (0-100)
        let score = calculateScore(from: metrics)

        // 6. Determinar nível de risco
        let riskLevel = determineRiskLevel(score: score)

        // 7. Atualizar perfil
        profile.score = score
        profile.riskLevel = riskLevel
        profile.lastCalculated = .now
        profile.totalAgreements = metrics.totalAgreements
        profile.totalInstallments = metrics.totalInstallments
        profile.paidOnTimeCount = metrics.paidOnTimeCount
        profile.paidLateCount = metrics.paidLateCount
        profile.overdueCount = metrics.overdueCount
        profile.averageDaysLate = metrics.averageDaysLate
        profile.onTimePaymentRate = metrics.onTimePaymentRate
        profile.totalLent = metrics.totalLent
        profile.totalPaid = metrics.totalPaid
        profile.totalInterestEarned = metrics.totalInterestEarned
        profile.currentOutstanding = metrics.currentOutstanding
        profile.firstAgreementDate = metrics.firstAgreementDate
        profile.lastPaymentDate = metrics.lastPaymentDate
        profile.consecutiveOnTimePayments = metrics.consecutiveOnTimePayments
        profile.longestDelayDays = metrics.longestDelayDays

        // 8. Persistir
        if existingProfile == nil { context.insert(profile) }
        try context.save()

        return profile
    }

    // MARK: - Cálculo de Métricas

    private struct Metrics {
        var totalAgreements: Int
        var totalInstallments: Int
        var paidOnTimeCount: Int
        var paidLateCount: Int
        var overdueCount: Int
        var averageDaysLate: Double
        var onTimePaymentRate: Double
        var totalLent: Decimal
        var totalPaid: Decimal
        var totalInterestEarned: Decimal
        var currentOutstanding: Decimal
        var firstAgreementDate: Date?
        var lastPaymentDate: Date?
        var consecutiveOnTimePayments: Int
        var longestDelayDays: Int
    }

    private func calculateMetrics(
        installments: [Installment],
        agreements: [DebtAgreement],
        calendar: Calendar
    ) -> Metrics {
        let today = calendar.startOfDay(for: .now)

        var paidOnTimeCount = 0
        var paidLateCount = 0
        var overdueCount = 0
        var totalDaysLate = 0
        var latePaymentsCount = 0
        var totalPaid = Decimal.zero
        var totalLent = Decimal.zero
        var totalInterestEarned = Decimal.zero
        var currentOutstanding = Decimal.zero
        var lastPaymentDate: Date?
        var firstAgreementDate: Date?
        var consecutiveOnTimePayments = 0
        var currentStreak = 0
        var longestDelayDays = 0

        // Calcular total emprestado e juros
        for agreement in agreements {
            totalLent += agreement.principal

            // Calcular juros ganhos
            if let rate = agreement.interestRateMonthly, rate > 0 {
                let totalWithInterest = agreement.installments.reduce(Decimal.zero) { $0 + $1.amount }
                let interest = totalWithInterest - agreement.principal
                totalInterestEarned += interest
            }

            if firstAgreementDate == nil || agreement.startDate < firstAgreementDate! {
                firstAgreementDate = agreement.startDate
            }
        }

        // Ordenar parcelas por data de vencimento
        let sortedInstallments = installments.sorted { $0.dueDate < $1.dueDate }

        for installment in sortedInstallments {
            totalPaid += installment.paidAmount

            if installment.status == .paid {
                // Verificar se foi pago no prazo
                if let payment = installment.payments.first {
                    let daysLate = calendar.dateComponents([.day], from: installment.dueDate, to: payment.date).day ?? 0

                    if daysLate <= 0 {
                        paidOnTimeCount += 1
                        currentStreak += 1
                    } else {
                        paidLateCount += 1
                        totalDaysLate += daysLate
                        latePaymentsCount += 1
                        currentStreak = 0
                        longestDelayDays = max(longestDelayDays, daysLate)
                    }

                    if lastPaymentDate == nil || payment.date > lastPaymentDate! {
                        lastPaymentDate = payment.date
                    }
                }
            } else if installment.dueDate < today && installment.remainingAmount > 0 {
                // Parcela em atraso
                overdueCount += 1
                let daysLate = calendar.dateComponents([.day], from: installment.dueDate, to: today).day ?? 0
                totalDaysLate += daysLate
                latePaymentsCount += 1
                currentStreak = 0
                longestDelayDays = max(longestDelayDays, daysLate)
                currentOutstanding += installment.remainingAmount
            } else if installment.remainingAmount > 0 {
                // Parcela futura
                currentOutstanding += installment.remainingAmount
            }
        }

        consecutiveOnTimePayments = currentStreak

        let paidInstallments = paidOnTimeCount + paidLateCount
        let onTimePaymentRate = paidInstallments > 0 ? Double(paidOnTimeCount) / Double(paidInstallments) : 0
        let averageDaysLate = latePaymentsCount > 0 ? Double(totalDaysLate) / Double(latePaymentsCount) : 0

        return Metrics(
            totalAgreements: agreements.count,
            totalInstallments: installments.count,
            paidOnTimeCount: paidOnTimeCount,
            paidLateCount: paidLateCount,
            overdueCount: overdueCount,
            averageDaysLate: averageDaysLate,
            onTimePaymentRate: onTimePaymentRate,
            totalLent: totalLent,
            totalPaid: totalPaid,
            totalInterestEarned: totalInterestEarned,
            currentOutstanding: currentOutstanding,
            firstAgreementDate: firstAgreementDate,
            lastPaymentDate: lastPaymentDate,
            consecutiveOnTimePayments: consecutiveOnTimePayments,
            longestDelayDays: longestDelayDays
        )
    }

    // MARK: - Cálculo do Score

    private func calculateScore(from metrics: Metrics) -> Int {
        var score = 0.0

        // 1. Taxa de pagamento pontual (40%)
        let onTimeScore = metrics.onTimePaymentRate * 100 * weights.onTimePaymentRate
        score += onTimeScore

        // 2. Penalidade por atrasos médios (25%)
        let avgDelayPenalty: Double
        if metrics.averageDaysLate == 0 {
            avgDelayPenalty = 25.0  // Sem atrasos = pontuação máxima
        } else {
            // Atraso de 30 dias = 0 pontos, 0 dias = 25 pontos
            let normalizedDelay = min(metrics.averageDaysLate / 30.0, 1.0)
            avgDelayPenalty = (1.0 - normalizedDelay) * 25.0
        }
        score += avgDelayPenalty

        // 3. Penalidade por atrasos atuais (20%)
        let currentOverduePenalty: Double
        if metrics.overdueCount == 0 {
            currentOverduePenalty = 20.0  // Nenhum atraso = pontuação máxima
        } else {
            // 5+ atrasos = 0 pontos
            let normalizedOverdue = min(Double(metrics.overdueCount) / 5.0, 1.0)
            currentOverduePenalty = (1.0 - normalizedOverdue) * 20.0
        }
        score += currentOverduePenalty

        // 4. Bônus por tempo de relacionamento (10%)
        let relationshipBonus: Double
        if let firstDate = metrics.firstAgreementDate {
            let monthsActive = Calendar.current.dateComponents([.month], from: firstDate, to: .now).month ?? 0
            // 12+ meses = pontuação máxima
            let normalizedMonths = min(Double(monthsActive) / 12.0, 1.0)
            relationshipBonus = normalizedMonths * 10.0
        } else {
            relationshipBonus = 0
        }
        score += relationshipBonus

        // 5. Bônus por tendência recente (5%)
        let recentTrendBonus: Double
        if metrics.consecutiveOnTimePayments >= 3 {
            recentTrendBonus = 5.0  // 3+ pagamentos consecutivos = bônus total
        } else {
            recentTrendBonus = Double(metrics.consecutiveOnTimePayments) * (5.0 / 3.0)
        }
        score += recentTrendBonus

        // Arredondar e clampar entre 0-100
        return max(0, min(100, Int(score.rounded())))
    }

    private func determineRiskLevel(score: Int) -> RiskLevel {
        switch score {
        case 75...100: return .low
        case 40..<75: return .medium
        default: return .high
        }
    }
}
```

---

### 3. Camada de Apresentação (Presentation)

#### 3.1 ViewModel: `DebtorCreditProfileViewModel`

**Arquivo:** `Money/Presentation/Debtors/DebtorCreditProfileViewModel.swift`

```swift
import Foundation
import SwiftData
import Combine

@MainActor
final class DebtorCreditProfileViewModel: ObservableObject {
    @Published private(set) var profile: DebtorCreditProfile?
    @Published private(set) var isLoading = false
    @Published var error: AppError?

    private let context: ModelContext
    private let calculator: CreditScoreCalculator
    private let currencyFormatter: CurrencyFormatter

    init(context: ModelContext, currencyFormatter: CurrencyFormatter) {
        self.context = context
        self.calculator = CreditScoreCalculator()
        self.currencyFormatter = currencyFormatter
    }

    func loadProfile(for debtor: Debtor) async {
        isLoading = true
        defer { isLoading = false }

        do {
            profile = try calculator.calculateProfile(for: debtor, context: context)
        } catch {
            self.error = .persistence("error.profile.load")
        }
    }

    func recalculate(for debtor: Debtor) async {
        await loadProfile(for: debtor)
    }

    // MARK: - Formatters

    func formattedScore() -> String {
        guard let profile else { return "--" }
        return "\(profile.score)"
    }

    func formattedOnTimeRate() -> String {
        guard let profile else { return "0%" }
        return (profile.onTimePaymentRate * 100).formatted(.percent.precision(.fractionLength(0)))
    }

    func formattedAverageDelay() -> String {
        guard let profile else { return "--" }
        let days = Int(profile.averageDaysLate)
        return String(localized: "credit.days.late", defaultValue: "\(days) dias")
    }

    func formattedTotalInterest() -> String {
        guard let profile else { return currencyFormatter.string(from: .zero) }
        return currencyFormatter.string(from: profile.totalInterestEarned)
    }

    func formattedCurrentOutstanding() -> String {
        guard let profile else { return currencyFormatter.string(from: .zero) }
        return currencyFormatter.string(from: profile.currentOutstanding)
    }
}
```

#### 3.2 Componente Visual: `CreditScoreBadge`

**Arquivo:** `Money/Presentation/Shared/Components/CreditScoreBadge.swift`

```swift
import SwiftUI

/// Badge compacto mostrando score de crédito com cor e ícone.
/// Reutiliza MoneyCardStyle para consistência visual.
struct CreditScoreBadge: View {
    let score: Int
    let riskLevel: RiskLevel
    var style: Style = .compact

    enum Style {
        case compact    // Para listas
        case prominent  // Para detalhes
    }

    var body: some View {
        HStack(spacing: style.spacing) {
            Image(systemName: riskLevel.icon)
                .font(.system(size: style.iconSize, weight: .semibold))
                .foregroundStyle(riskLevel.color)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(score)")
                    .font(style.scoreFont)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                if style == .prominent {
                    Text(riskLevel.titleKey)
                        .font(.caption)
                        .foregroundStyle(riskLevel.color)
                }
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
        .moneyCard(
            tint: riskLevel.color,
            cornerRadius: style.cornerRadius,
            shadow: .compact,
            intensity: .standard
        )
    }
}

private extension CreditScoreBadge.Style {
    var spacing: CGFloat {
        switch self {
        case .compact: return 8
        case .prominent: return 12
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .compact: return 14
        case .prominent: return 20
        }
    }

    var scoreFont: Font {
        switch self {
        case .compact: return .subheadline
        case .prominent: return .title2
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .compact: return 10
        case .prominent: return 16
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .compact: return 6
        case .prominent: return 12
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: return 12
        case .prominent: return 18
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CreditScoreBadge(score: 92, riskLevel: .low, style: .compact)
        CreditScoreBadge(score: 55, riskLevel: .medium, style: .prominent)
        CreditScoreBadge(score: 28, riskLevel: .high, style: .prominent)
    }
    .padding()
}
```

#### 3.3 View Completa: `CreditProfileDetailView`

**Arquivo:** `Money/Presentation/Debtors/CreditProfileDetailView.swift`

```swift
import SwiftUI

/// Tela de detalhes do perfil de crédito de um devedor.
/// Mostra score, métricas, rentabilidade e alertas.
struct CreditProfileDetailView: View {
    @StateObject private var viewModel: DebtorCreditProfileViewModel
    let debtor: Debtor

    init(debtor: Debtor, environment: AppEnvironment, context: ModelContext) {
        self.debtor = debtor
        _viewModel = StateObject(
            wrappedValue: DebtorCreditProfileViewModel(
                context: context,
                currencyFormatter: environment.currencyFormatter
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if let profile = viewModel.profile {
                    scoreSection(profile: profile)
                    metricsSection(profile: profile)
                    profitabilitySection(profile: profile)
                    recommendationsSection(profile: profile)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(AppBackground(variant: .dashboard))
        .navigationTitle("Perfil de Crédito")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Recalcular") {
                    Task { await viewModel.recalculate(for: debtor) }
                }
            }
        }
        .task {
            await viewModel.loadProfile(for: debtor)
        }
    }

    // MARK: - Sections

    private func scoreSection(profile: DebtorCreditProfile) -> some View {
        VStack(spacing: 16) {
            // Score principal
            VStack(spacing: 12) {
                Text("Score de Crédito")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                CreditScoreBadge(
                    score: profile.score,
                    riskLevel: profile.riskLevel,
                    style: .prominent
                )

                Text(profile.riskLevel.descriptionKey)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .moneyCard(
                tint: profile.riskLevel.color,
                cornerRadius: 28,
                shadow: .standard,
                intensity: .prominent
            )

            // Barra de progresso visual
            scoreProgressBar(score: profile.score, riskLevel: profile.riskLevel)
        }
    }

    private func scoreProgressBar(score: Int, riskLevel: RiskLevel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)

                    // Progress
                    RoundedRectangle(cornerRadius: 8)
                        .fill(riskLevel.color)
                        .frame(width: geometry.size.width * CGFloat(score) / 100.0, height: 12)
                }
            }
            .frame(height: 12)
        }
        .padding(.horizontal, 20)
    }

    private func metricsSection(profile: DebtorCreditProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Métricas de Comportamento")
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                MetricCard(
                    title: "Taxa de Pontualidade",
                    value: viewModel.formattedOnTimeRate(),
                    icon: "checkmark.circle.fill",
                    tint: .green
                )

                MetricCard(
                    title: "Atraso Médio",
                    value: viewModel.formattedAverageDelay(),
                    icon: "clock.fill",
                    tint: .orange
                )

                MetricCard(
                    title: "Em Atraso Atual",
                    value: "\(profile.overdueCount)",
                    icon: "exclamationmark.triangle.fill",
                    tint: profile.overdueCount > 0 ? .red : .green
                )

                MetricCard(
                    title: "Sequência Pontual",
                    value: "\(profile.consecutiveOnTimePayments)",
                    icon: "flame.fill",
                    tint: .blue
                )
            }
        }
    }

    private func profitabilitySection(profile: DebtorCreditProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rentabilidade")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                profitRow(
                    label: "Total Emprestado",
                    value: viewModel.currencyFormatter.string(from: profile.totalLent),
                    color: .blue
                )

                profitRow(
                    label: "Total Pago",
                    value: viewModel.currencyFormatter.string(from: profile.totalPaid),
                    color: .green
                )

                Divider()

                profitRow(
                    label: "Juros Ganhos",
                    value: viewModel.formattedTotalInterest(),
                    color: .teal,
                    prominent: true
                )

                profitRow(
                    label: "Saldo Devedor",
                    value: viewModel.formattedCurrentOutstanding(),
                    color: .orange
                )
            }
            .padding(20)
            .moneyCard(
                tint: .teal,
                cornerRadius: 24,
                shadow: .compact,
                intensity: .standard
            )
        }
    }

    private func profitRow(label: String, value: String, color: Color, prominent: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(prominent ? .headline : .subheadline)
                .foregroundStyle(prominent ? color : .secondary)
            Spacer()
            Text(value)
                .font(prominent ? .title3 : .subheadline)
                .fontWeight(prominent ? .bold : .semibold)
                .foregroundStyle(color)
        }
    }

    private func recommendationsSection(profile: DebtorCreditProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recomendações")
                .font(.headline)
                .foregroundStyle(.secondary)

            if profile.riskLevel == .high {
                recommendationCard(
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    title: "Alto Risco",
                    message: "Evite conceder novos créditos até melhorar o histórico. Considere juros mais altos ou garantias."
                )
            } else if profile.riskLevel == .medium {
                recommendationCard(
                    icon: "exclamationmark.circle.fill",
                    color: .orange,
                    title: "Risco Moderado",
                    message: "Monitore de perto os pagamentos. Considere acordos com parcelas menores ou prazos mais curtos."
                )
            } else {
                recommendationCard(
                    icon: "checkmark.seal.fill",
                    color: .green,
                    title: "Baixo Risco",
                    message: "Cliente confiável! Considere oferecer condições melhores (juros menores, prazos maiores) para fidelizar."
                )
            }

            if profile.consecutiveOnTimePayments >= 5 {
                recommendationCard(
                    icon: "star.fill",
                    color: .yellow,
                    title: "Cliente Premium",
                    message: "Este devedor tem \(profile.consecutiveOnTimePayments) pagamentos consecutivos em dia. Ofereça benefícios especiais!"
                )
            }
        }
    }

    private func recommendationCard(icon: String, color: Color, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .padding(10)
                .background(color.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .moneyCard(
            tint: color,
            cornerRadius: 20,
            shadow: .compact,
            intensity: .subtle
        )
    }

    private var emptyState: some View {
        AppEmptyState(
            icon: "chart.bar.doc.horizontal",
            title: "Sem Dados",
            message: "Não há histórico suficiente para calcular o perfil de crédito.",
            style: .minimal
        )
    }
}
```

---

### 4. Integração com Telas Existentes

#### 4.1 Adicionar Badge na Lista de Devedores

**Arquivo:** `Money/Presentation/Debtors/DebtorsListScene.swift` (modificar `DebtorRow`)

```swift
// Adicionar ao DebtorRow existente
HStack {
    // ... código existente (avatar, nome, etc.)

    Spacer()

    // NOVO: Badge de score
    if let profile = viewModel.creditProfile(for: debtor) {
        CreditScoreBadge(score: profile.score, riskLevel: profile.riskLevel, style: .compact)
    }
}
```

#### 4.2 Alerta ao Criar Novo Acordo

**Arquivo:** `Money/Presentation/Debtors/AgreementFormView.swift` (adicionar alerta)

```swift
// Adicionar ao início do formulário
if let profile = viewModel.creditProfile(for: debtor), profile.riskLevel == .high {
    HStack(spacing: 12) {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
        VStack(alignment: .leading, spacing: 4) {
            Text("⚠️ Atenção: Cliente de Alto Risco")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("Score: \(profile.score) - Este devedor tem histórico de atrasos.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    .padding(12)
    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal)
}
```

---

### 5. Localização (Strings)

**Arquivo:** `Money/Resources/Localizable.xcstrings`

```json
{
  "credit.risk.low": {
    "pt-BR": "Baixo Risco",
    "en-US": "Low Risk"
  },
  "credit.risk.medium": {
    "pt-BR": "Risco Médio",
    "en-US": "Medium Risk"
  },
  "credit.risk.high": {
    "pt-BR": "Alto Risco",
    "en-US": "High Risk"
  },
  "credit.risk.low.description": {
    "pt-BR": "Excelente histórico de pagamentos. Cliente confiável.",
    "en-US": "Excellent payment history. Trustworthy client."
  },
  "credit.risk.medium.description": {
    "pt-BR": "Histórico mediano. Monitore de perto os pagamentos.",
    "en-US": "Average history. Monitor payments closely."
  },
  "credit.risk.high.description": {
    "pt-BR": "Histórico problemático. Evite novos créditos ou exija garantias.",
    "en-US": "Problematic history. Avoid new credits or require collateral."
  },
  "credit.days.late": {
    "pt-BR": "%d dias",
    "en-US": "%d days"
  }
}
```

---

## 📝 Ordem de Implementação

### Fase 1: Fundação (Semana 1)
1. ✅ Criar `CreditModels.swift` com `DebtorCreditProfile` e `PaymentHistorySnapshot`
2. ✅ Criar `CreditScoreCalculator.swift` com lógica de cálculo
3. ✅ Adicionar testes unitários para `CreditScoreCalculator`
4. ✅ Adicionar strings de localização

### Fase 2: Componentes Visuais (Semana 2)
5. ✅ Criar `CreditScoreBadge.swift` (componente reutilizável)
6. ✅ Criar `DebtorCreditProfileViewModel.swift`
7. ✅ Criar `CreditProfileDetailView.swift` (tela completa)
8. ✅ Adicionar previews para todos os componentes

### Fase 3: Integração (Semana 3)
9. ✅ Adicionar badge na lista de devedores (`DebtorsListScene`)
10. ✅ Adicionar alerta ao criar acordo (`AgreementFormView`)
11. ✅ Adicionar botão "Ver Perfil de Crédito" no `DebtorDetailScene`
12. ✅ Implementar recálculo automático após pagamentos (observar notificações)

### Fase 4: Exportação e Refinamentos (Semana 4)
13. ✅ Atualizar `CSVExporter` para incluir perfis de crédito
14. ✅ Adicionar filtro por risco na lista de devedores
15. ✅ Adicionar testes de UI para fluxo completo
16. ✅ Documentação e ajustes finais

---

## 🧪 Testes

### Testes Unitários

**Arquivo:** `MoneyTests/CreditScoreCalculatorTests.swift`

```swift
import Testing
import SwiftData
@testable import Money

@Suite("CreditScoreCalculator Tests")
struct CreditScoreCalculatorTests {

    @Test("Score máximo para devedor com 100% de pontualidade")
    func testPerfectScore() async throws {
        let calculator = CreditScoreCalculator()
        // ... criar contexto mockado e devedor com histórico perfeito
        // ... validar score entre 90-100
    }

    @Test("Score baixo para devedor com muitos atrasos")
    func testLowScore() async throws {
        // ... devedor com 70% de atrasos
        // ... validar score < 40
    }

    @Test("Bônus por relacionamento longo")
    func testRelationshipBonus() async throws {
        // ... devedor com 2+ anos de histórico
        // ... validar que score é maior que devedor novo com mesma taxa
    }
}
```

---

## ⚠️ Riscos e Mitigações

| Risco | Impacto | Probabilidade | Mitigação |
|-------|---------|---------------|-----------|
| Performance ao recalcular perfis de muitos devedores | Alto | Média | Implementar cache e recálculo assíncrono em background |
| Algoritmo de score muito rígido ou leniente | Médio | Alta | Criar testes com cenários reais e ajustar pesos |
| Usuários não entendem o score | Baixo | Média | Adicionar tooltips e explicações claras |
| Migração de dados existentes | Alto | Baixa | SwiftData cria automaticamente, mas testar com dados legacy |

---

## ✅ Validação Final

### Checklist de Conclusão
- [ ] Todos os testes unitários passando
- [ ] Todos os testes de UI passando
- [ ] Preview funcionando para todos os componentes
- [ ] Localização completa (pt-BR e en-US)
- [ ] Documentação atualizada
- [ ] Badge aparece corretamente na lista
- [ ] Alerta funciona ao criar acordo
- [ ] Exportação CSV inclui perfis
- [ ] Performance validada com 100+ devedores
- [ ] Acessibilidade testada (VoiceOver, Dynamic Type)

---

## 📊 Métricas de Sucesso

- **Adoção:** 80%+ dos usuários visualizam perfis de crédito após implementação
- **Impacto:** Redução de 30%+ em inadimplência após 3 meses de uso
- **Satisfação:** NPS > 8 em pesquisa sobre a funcionalidade
- **Performance:** Tempo de cálculo < 500ms para perfis com 100+ parcelas
