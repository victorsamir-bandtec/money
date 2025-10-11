import SwiftUI
import WidgetKit

/// Small widget view - displays available balance prominently
struct SmallWidgetView: View {
    @Environment(\.widgetFamily) var family
    let summary: WidgetSummary

    private var availableIcon: String {
        summary.availableToSpend >= .zero ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis"
    }

    var body: some View {
        if summary.isEmpty {
            EmptyWidgetView(size: family)
        } else {
            contentView
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(summary.availableTint)
                Text("Money")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(summary.availableTint)
            }
            .padding(.bottom, 6)

            Spacer(minLength: 0)

            // Main metric
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(summary.availableTint.opacity(0.2))
                        .overlay {
                            Image(systemName: availableIcon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(summary.availableTint)
                        }
                        .frame(width: 28, height: 28)

                    Text("Saldo disponível")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(summary.availableTint)
                        .lineLimit(1)
                }

                Text(WidgetSummary.formatter.string(from: summary.availableToSpend))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Spacer(minLength: 0)

            // Footer hint
            if summary.overdue > .zero {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.orange)
                    Text("Em atraso")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            } else if summary.planned > .zero {
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.blue)
                    Text("Previsto: \(WidgetSummary.formatter.string(from: summary.planned))")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "money://dashboard"))
    }
}
