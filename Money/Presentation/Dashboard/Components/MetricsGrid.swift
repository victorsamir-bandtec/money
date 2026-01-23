import SwiftUI

struct MetricsGrid: View {
    let summary: DashboardSummary
    let formatted: (Decimal) -> String
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            if summary.overdue > 0 {
                MetricTile(
                    title: "dashboard.metric.overdue",
                    value: formatted(summary.overdue),
                    icon: "exclamationmark.triangle.fill",
                    tint: .orange,
                    caption: "dashboard.metric.overdue.caption"
                )
            }
            
            MetricTile(
                title: "dashboard.metric.expenses.fixed",
                value: formatted(summary.fixedExpenses),
                icon: "doc.text.fill",
                tint: .pink
            )
            
            MetricTile(
                title: "dashboard.metric.expenses.variable",
                value: formatted(summary.variableExpenses),
                icon: "arrow.uturn.down.circle.fill",
                tint: .orange
            )
            
            MetricTile(
                title: "dashboard.metric.expenses.income",
                value: formatted(summary.variableIncome),
                icon: "tray.full.fill",
                tint: .green
            )
            
            MetricTile(
                title: "dashboard.metric.salary",
                value: formatted(summary.salary),
                icon: "banknote.fill",
                tint: .blue
            )
            
            MetricTile(
                title: "dashboard.metric.planned",
                value: formatted(summary.planned),
                icon: "calendar.badge.clock",
                tint: .purple
            )
            
            MetricTile(
                title: "dashboard.metric.received",
                value: formatted(summary.received),
                icon: "arrow.down.circle.fill",
                tint: .green
            )
        }
    }
}

private struct MetricTile: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let tint: Color
    var caption: LocalizedStringKey? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Circle()
                .fill(tint.opacity(0.15))
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(tint)
                    .lineLimit(2)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .moneyCard(
            tint: tint,
            cornerRadius: 20,
            shadow: .compact,
            intensity: .standard
        )
    }
}
