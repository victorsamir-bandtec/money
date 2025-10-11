import SwiftUI
import SwiftData

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
            VStack(spacing: DesignSystem.sectionSpacing) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                        .transition(.opacity)
                } else if let profile = viewModel.profile {
                    Group {
                        scoreSection(profile: profile)
                        metricsSection(profile: profile)
                        profitabilitySection(profile: profile)
                        recommendationsSection(profile: profile)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    AppEmptyState(
                        icon: "chart.bar.doc.horizontal",
                        title: "credit.empty.title",
                        message: "credit.empty.message",
                        style: .minimal
                    )
                }
            }
            .padding(.horizontal, DesignSystem.horizontalPadding)
            .padding(.vertical, DesignSystem.verticalPadding)
        }
        .background(AppBackground(variant: .dashboard))
        .navigationTitle("credit.profile.title")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("credit.profile.recalculate") {
                    Task { await viewModel.recalculate(for: debtor) }
                }
                .font(.subheadline)
                .fontWeight(.semibold)
            }
        }
        .task {
            await viewModel.loadProfile(for: debtor)
        }
    }

    private func scoreSection(profile: DebtorCreditProfile) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 18) {
                Text("credit.score.title")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                CreditScoreBadge(
                    score: profile.score,
                    riskLevel: profile.riskLevel,
                    style: .prominent,
                    withCard: false,
                    showIcon: false
                )

                Text(profile.riskLevel.descriptionKey)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .padding(.horizontal, 24)
            .moneyCard(
                tint: profile.riskLevel.color,
                cornerRadius: 28,
                shadow: .standard,
                intensity: .prominent
            )

            EnhancedScoreProgressBar(
                score: profile.score,
                riskLevel: profile.riskLevel
            )
        }
    }

    private func metricsSection(profile: DebtorCreditProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("credit.metrics.title")
                .font(.headline)
                .foregroundStyle(.secondary)

            CreditMetricsGrid(profile: profile, viewModel: viewModel)
        }
    }

    private func profitabilitySection(profile: DebtorCreditProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("credit.profitability.title")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    profitRow(
                        label: "credit.profitability.lent",
                        value: viewModel.currencyFormatter.string(from: profile.totalLent),
                        color: .blue
                    )

                    profitRow(
                        label: "credit.profitability.paid",
                        value: viewModel.currencyFormatter.string(from: profile.totalPaid),
                        color: .green
                    )

                    Divider()
                        .padding(.vertical, 4)

                    profitRow(
                        label: "credit.profitability.interest",
                        value: viewModel.formattedTotalInterest(),
                        color: .teal,
                        prominent: true
                    )

                    profitRow(
                        label: "credit.profitability.roi",
                        value: viewModel.formattedROI(),
                        color: .purple,
                        prominent: true
                    )

                    Divider()
                        .padding(.vertical, 4)

                    profitRow(
                        label: "credit.profitability.outstanding",
                        value: viewModel.formattedCurrentOutstanding(),
                        color: .orange
                    )

                    profitRow(
                        label: "credit.profitability.collection.rate",
                        value: viewModel.formattedCollectionRate(),
                        color: .cyan
                    )
                }
                .padding(24)
                .moneyCard(
                    tint: .teal,
                    cornerRadius: 28,
                    shadow: .standard,
                    intensity: .standard
                )
            }
        }
    }

    private func profitRow(label: LocalizedStringKey, value: String, color: Color, prominent: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(prominent ? .headline : .subheadline)
                .foregroundStyle(prominent ? color : .secondary)
            Spacer()
            Text(value)
                .font(prominent ? .title3 : .body)
                .fontWeight(prominent ? .bold : .semibold)
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }

    private func recommendationsSection(profile: DebtorCreditProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("credit.recommendations.title")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(Recommendation.recommendations(for: profile), id: \.id) { recommendation in
                RecommendationCard(recommendation: recommendation)
            }
        }
    }
}

private enum DesignSystem {
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 28
}

private struct EnhancedScoreProgressBar: View {
    let score: Int
    let riskLevel: RiskLevel
    @State private var animatedProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .frame(height: 16)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    riskLevel.color,
                                    riskLevel.color.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * animatedProgress, height: 16)

                    HStack(spacing: 0) {
                        ForEach([40, 75], id: \.self) { threshold in
                            Spacer()
                                .frame(width: geometry.size.width * CGFloat(threshold) / 100.0)
                            Rectangle()
                                .fill(Color(.systemBackground).opacity(0.7))
                                .frame(width: 2, height: 16)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 16)

            HStack {
                Label {
                    Text("credit.risk.high")
                        .font(.caption2)
                } icon: {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
                .foregroundStyle(.secondary)

                Label {
                    Text("credit.risk.medium")
                        .font(.caption2)
                } icon: {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                }
                .foregroundStyle(.secondary)

                Label {
                    Text("credit.risk.low")
                        .font(.caption2)
                } icon: {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2)) {
                animatedProgress = CGFloat(score) / 100.0
            }
        }
    }
}

private struct CreditMetricsGrid: View {
    let profile: DebtorCreditProfile
    let viewModel: DebtorCreditProfileViewModel

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            MetricCard(
                title: "credit.metric.ontime.rate",
                value: viewModel.formattedOnTimeRate(),
                icon: "checkmark.circle.fill",
                tint: profile.onTimePaymentRate >= 0.8 ? .green : .orange
            )

            MetricCard(
                title: "credit.metric.average.delay",
                value: viewModel.formattedAverageDelay(),
                icon: "clock.fill",
                tint: profile.averageDaysLate > 7 ? .red : .orange
            )

            MetricCard(
                title: "credit.metric.current.overdue",
                value: "\(profile.overdueCount)",
                icon: profile.overdueCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.shield.fill",
                tint: profile.overdueCount > 0 ? .red : .green
            )

            MetricCard(
                title: "credit.metric.streak",
                value: "\(profile.consecutiveOnTimePayments)",
                icon: "flame.fill",
                tint: .blue
            )
        }
    }
}

private struct Recommendation: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    let message: String

    static func recommendations(for profile: DebtorCreditProfile) -> [Recommendation] {
        var results: [Recommendation] = []

        switch profile.riskLevel {
        case .high:
            results.append(Recommendation(
                icon: "exclamationmark.triangle.fill",
                color: .red,
                title: "credit.recommendation.high.title",
                message: String(localized: "credit.recommendation.high.message")
            ))
        case .medium:
            results.append(Recommendation(
                icon: "exclamationmark.circle.fill",
                color: .orange,
                title: "credit.recommendation.medium.title",
                message: String(localized: "credit.recommendation.medium.message")
            ))
        case .low:
            results.append(Recommendation(
                icon: "checkmark.seal.fill",
                color: .green,
                title: "credit.recommendation.low.title",
                message: String(localized: "credit.recommendation.low.message")
            ))
        }

        if profile.consecutiveOnTimePayments >= 5 {
            results.append(Recommendation(
                icon: "star.fill",
                color: .yellow,
                title: "credit.recommendation.premium.title",
                message: String(localized: "credit.recommendation.premium.message", defaultValue: "Este devedor tem \(profile.consecutiveOnTimePayments) pagamentos consecutivos em dia")
            ))
        }

        if profile.returnOnInvestment > 10 {
            results.append(Recommendation(
                icon: "chart.line.uptrend.xyaxis",
                color: .purple,
                title: "credit.recommendation.profit.title",
                message: String(localized: "credit.recommendation.profit.message", defaultValue: "ROI excelente de \(String(format: "%.1f%%", NSDecimalNumber(decimal: profile.returnOnInvestment).doubleValue))")
            ))
        }

        return results
    }
}

private struct RecommendationCard: View {
    let recommendation: Recommendation

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: recommendation.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(recommendation.color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(recommendation.color.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(recommendation.color)

                Text(recommendation.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyCard(
            tint: recommendation.color,
            cornerRadius: 22,
            shadow: .compact,
            intensity: .subtle
        )
    }
}
