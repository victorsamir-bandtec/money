import SwiftUI

struct ProjectionCardView: View {
    let scenario: ProjectionScenario
    let projectedBalance: String
    let confidence: String
    let isSelected: Bool
    
    // MARK: - Design Tokens
    
    private var scenarioColor: Color {
        switch scenario {
        case .optimistic: return .mint
        case .realistic: return .indigo
        case .pessimistic: return .orange
        }
    }
    
    private var scenarioIcon: String {
        switch scenario {
        case .optimistic: return "chart.line.uptrend.xyaxis"
        case .realistic: return "chart.line.flattrend.xyaxis"
        case .pessimistic: return "chart.line.downtrend.xyaxis"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Container
            ZStack {
                Circle()
                    .fill(scenarioColor.opacity(isSelected ? 0.2 : 0.1))
                
                Image(systemName: scenarioIcon)
                    .font(.system(.title2, design: .default, weight: .semibold))
                    .foregroundStyle(scenarioColor)
            }
            .frame(width: 52, height: 52)
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(scenario.titleKey)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                // Value
                Text(projectedBalance)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                
                // Confidence Badge
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.caption2)
                    Text(confidence)
                        .font(.caption2.weight(.medium))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Selection Indicator
            ZStack {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(scenarioColor)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(.quaternary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .moneyCard(
            tint: scenarioColor,
            cornerRadius: 24,
            shadow: isSelected ? .standard : .compact,
            intensity: isSelected ? .standard : .subtle
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isSelected ? scenarioColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    ZStack {
        AppBackground(variant: .dashboard)
        
        VStack(spacing: 20) {
            ProjectionCardView(
                scenario: .optimistic,
                projectedBalance: "R$ 5.230,00",
                confidence: "Confiança: 85%",
                isSelected: false
            )
            
            ProjectionCardView(
                scenario: .realistic,
                projectedBalance: "R$ 4.100,00",
                confidence: "Confiança: 95%",
                isSelected: true
            )
            
            ProjectionCardView(
                scenario: .pessimistic,
                projectedBalance: "R$ 3.050,00",
                confidence: "Confiança: 90%",
                isSelected: false
            )
        }
        .padding()
    }
}
