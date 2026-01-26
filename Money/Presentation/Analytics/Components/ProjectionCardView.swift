import SwiftUI

struct ProjectionCardView: View {
    let scenario: ProjectionScenario
    let projectedBalance: String
    let confidence: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Container
            Circle()
                .fill(scenario.color.opacity(isSelected ? 0.2 : 0.1))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: scenario.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(scenario.color)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(scenario.titleKey)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                // Value
                Text(projectedBalance)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                
                // Confidence Badge
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 10))
                    Text(confidence)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Selection Indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(scenario.color)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(16)
        .moneyCard(
            tint: scenario.color,
            cornerRadius: 20,
            shadow: isSelected ? .standard : .compact,
            intensity: isSelected ? .subtle : .subtle
        )
        .scaleEffect(isSelected ? 1.0 : 0.98)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    ZStack {
        AppBackground(variant: .dashboard)
        
        VStack(spacing: 16) {
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
