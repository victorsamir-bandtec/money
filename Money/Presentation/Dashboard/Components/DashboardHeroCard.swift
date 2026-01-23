import SwiftUI

struct DashboardHeroCard: View {
    let summary: DashboardSummary
    let formatter: (Decimal) -> String
    
    private var availableTint: Color {
        summary.availableToSpend >= .zero ? .blue : .red
    }
    
    private var availableIcon: String {
        summary.availableToSpend >= .zero ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Circle()
                    .fill(availableTint.opacity(0.2))
                    .overlay {
                        Image(systemName: availableIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(availableTint)
                    }
                    .frame(width: 44, height: 44)
                
                Text(String(localized: "dashboard.metric.available"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(availableTint)
                
                Spacer()
            }
            
            // Main Value
            Text(formatter(summary.availableToSpend))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            
            // Secondary Context
            if summary.remainingToReceive > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.left")
                        .font(.caption.weight(.semibold))
                    Text(String(localized: "dashboard.metric.remaining"))
                        .fontWeight(.medium)
                    Text("•")
                    Text(formatter(summary.remainingToReceive))
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .moneyCard(
            tint: availableTint,
            cornerRadius: 28,
            shadow: .standard,
            intensity: .prominent
        )
    }
}

#Preview {
    ZStack {
        AppBackground(variant: .dashboard)
        DashboardHeroCard(
            summary: DashboardSummary(
                salary: 5000,
                received: 1000,
                overdue: 0,
                fixedExpenses: 2000,
                planned: 1500
            ),
            formatter: { value in
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.locale = Locale(identifier: "pt_BR")
                return formatter.string(from: value as NSNumber) ?? "R$ 0,00"
            }
        )
        .padding()
    }
}
