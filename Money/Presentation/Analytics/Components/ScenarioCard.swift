import SwiftUI

/// Card para exibir um cenário de projeção (otimista/realista/pessimista).
/// Reutiliza o estilo do MetricCard para consistência visual.
struct ScenarioCard: View {
    let scenario: ProjectionScenario
    let projectedBalance: String
    let confidence: String
    var isSelected: Bool = false

    private var cornerRadius: CGFloat { 22 }
    private var intensity: MoneyCardIntensity { isSelected ? .prominent : .standard }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                scenarioIcon
                Text(scenario.titleKey)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(scenario.color)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(scenario.color)
                }
            }

            Text(projectedBalance)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Image(systemName: "gauge.medium")
                    .font(.caption)
                Text("analytics.projection.confidence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(confidence)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(scenario.color)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyCard(
            tint: scenario.color,
            cornerRadius: cornerRadius,
            shadow: .compact,
            intensity: intensity
        )
    }

    private var scenarioIcon: some View {
        Circle()
            .fill(scenario.color.opacity(0.2))
            .overlay {
                Circle()
                    .strokeBorder(scenario.color.opacity(0.3), lineWidth: 1)
            }
            .overlay {
                Image(systemName: scenario.iconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(scenario.color)
            }
            .frame(width: 36, height: 36)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ScenarioCard(
                scenario: .optimistic,
                projectedBalance: "R$ 2.500,00",
                confidence: "75%",
                isSelected: false
            )

            ScenarioCard(
                scenario: .realistic,
                projectedBalance: "R$ 1.800,00",
                confidence: "85%",
                isSelected: true
            )

            ScenarioCard(
                scenario: .pessimistic,
                projectedBalance: "R$ 1.200,00",
                confidence: "70%",
                isSelected: false
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
