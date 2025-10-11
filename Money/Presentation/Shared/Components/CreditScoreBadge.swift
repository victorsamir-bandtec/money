import SwiftUI

struct CreditScoreBadge: View {
    let score: Int
    let riskLevel: RiskLevel
    var style: Style = .compact
    var withCard: Bool = true
    var showIcon: Bool = true
    @State private var isAnimating = false

    enum Style {
        case compact
        case prominent
    }

    var body: some View {
        let content = Group {
            if showIcon {
                HStack(spacing: style.spacing) {
                    Image(systemName: riskLevel.icon)
                        .font(.system(size: style.iconSize, weight: .semibold))
                        .foregroundStyle(riskLevel.color)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))

                    scoreContent
                }
            } else {
                scoreContent
            }
        }
        .padding(.horizontal, withCard ? style.horizontalPadding : 0)
        .padding(.vertical, withCard ? style.verticalPadding : 0)

        return Group {
            if withCard {
                content
                    .moneyCard(
                        tint: riskLevel.color,
                        cornerRadius: style.cornerRadius,
                        shadow: .compact,
                        intensity: .standard
                    )
            } else {
                content
            }
        }
        .scaleEffect(isAnimating ? 1.0 : 0.8)
        .opacity(isAnimating ? 1.0 : 0.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }

    private var scoreContent: some View {
        VStack(spacing: style == .prominent ? 6 : 2) {
            Text("\(score)")
                .font(style.scoreFont)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            if style == .prominent {
                Text(riskLevel.titleKey)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(riskLevel.color)
            }
        }
        .frame(maxWidth: showIcon ? nil : .infinity)
    }

    private var accessibilityDescription: String {
        let riskDescription: String
        switch riskLevel {
        case .low: riskDescription = String(localized: "credit.risk.low")
        case .medium: riskDescription = String(localized: "credit.risk.medium")
        case .high: riskDescription = String(localized: "credit.risk.high")
        }
        return String(localized: "credit.score.accessibility", defaultValue: "Score de crédito: \(score). Nível de risco: \(riskDescription)")
    }
}

private extension CreditScoreBadge.Style {
    var spacing: CGFloat {
        switch self {
        case .compact: return 8
        case .prominent: return 16
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .compact: return 14
        case .prominent: return 32
        }
    }

    var scoreFont: Font {
        switch self {
        case .compact: return .subheadline
        case .prominent: return .system(size: 64, weight: .bold, design: .rounded)
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
