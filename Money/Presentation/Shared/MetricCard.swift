import SwiftUI

struct MetricCard: View {
    enum Style {
        case standard
        case prominent
    }

    let title: LocalizedStringKey
    let value: String
    var caption: LocalizedStringKey? = nil
    var icon: String = "chart.bar"
    var tint: Color = .accentColor
    var style: Style = .standard

    private var padding: CGFloat { style == .prominent ? 24 : 20 }
    private var cornerRadius: CGFloat { style == .prominent ? 28 : 22 }
    private var spacing: CGFloat { style == .prominent ? 18 : 14 }
    private var iconSize: CGFloat { style == .prominent ? 42 : 36 }
    private var iconFont: Font { .system(size: style == .prominent ? 19 : 17, weight: .semibold) }
    private var valueFont: Font {
        style == .prominent
            ? .system(size: 32, weight: .bold, design: .rounded)
            : .system(size: 22, weight: .semibold, design: .rounded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            HStack(spacing: 12) {
                iconBadge
                Text(title)
                    .font(style == .prominent ? .headline : .subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
            }

            Text(value)
                .font(valueFont)
                .foregroundStyle(.primary)

            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardStroke)
        .shadow(color: tint.opacity(style == .prominent ? 0.22 : 0.15), radius: style == .prominent ? 16 : 12, x: 0, y: style == .prominent ? 12 : 8)
    }

    private var iconBadge: some View {
        Circle()
            .fill(tint.opacity(0.2))
            .overlay {
                Circle()
                    .strokeBorder(tint.opacity(0.3), lineWidth: 1)
            }
            .overlay {
                Image(systemName: icon)
                    .font(iconFont)
                    .foregroundStyle(tint)
            }
            .frame(width: iconSize, height: iconSize)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(style == .prominent ? 0.8 : 0.6)
            }
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(tint.opacity(0.25), lineWidth: style == .prominent ? 1.2 : 1)
    }

    private var gradientColors: [Color] {
        [
            tint.opacity(style == .prominent ? 0.35 : 0.25),
            tint.opacity(0.08)
        ]
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            MetricCard(
                title: "A receber",
                value: "R$ 1.250,00",
                caption: "Total previsto no mês",
                icon: "tray.and.arrow.down.fill",
                tint: .green,
                style: .prominent
            )

            MetricCard(
                title: "Recebido",
                value: "R$ 750,00",
                caption: "Até agora",
                icon: "checkmark.seal.fill",
                tint: .teal
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
