import SwiftUI

struct MetricCard: View {
    enum Style {
        case standard
        case prominent
    }

    enum LayoutMode {
        case automatic
        case uniform
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: LocalizedStringKey
    let value: String
    var caption: LocalizedStringKey? = nil
    var icon: String = "chart.bar"
    var tint: Color = .accentColor
    var style: Style = .standard
    var layoutMode: LayoutMode = .automatic

    private var padding: CGFloat { style == .prominent ? 24 : 20 }
    private var cornerRadius: CGFloat { style == .prominent ? 28 : 22 }
    private var spacing: CGFloat { style == .prominent ? 18 : 14 }
    private var iconSize: CGFloat { style == .prominent ? 42 : 36 }
    private var iconFont: Font { .system(size: style == .prominent ? 19 : 17, weight: .semibold) }
    private var titleFont: Font { style == .prominent ? .headline : .subheadline }
    private var captionFont: Font { .footnote }
    private var shadow: MoneyCardShadow { style == .prominent ? .standard : .compact }
    private var intensity: MoneyCardIntensity { style == .prominent ? .prominent : .standard }
    private var valueFont: Font {
        style == .prominent
            ? .system(size: 32, weight: .bold, design: .rounded)
            : .system(size: 22, weight: .semibold, design: .rounded)
    }
    private var useUniformLayout: Bool { layoutMode == .uniform && !dynamicTypeSize.isAccessibilitySize }
    private var shouldRenderCaptionSection: Bool { caption != nil || useUniformLayout }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            headerSection
            valueSection
            if shouldRenderCaptionSection {
                captionSection
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyCard(
            tint: tint,
            cornerRadius: cornerRadius,
            shadow: shadow,
            intensity: intensity
        )
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            iconBadge
            if useUniformLayout {
                ZStack(alignment: .topLeading) {
                    twoLinePlaceholder(font: titleFont, weight: .semibold)
                    titleText(lineLimit: 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                titleText()
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var valueSection: some View {
        if useUniformLayout {
            Text(value)
                .font(valueFont)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(style == .prominent ? 0.7 : 0.75)
        } else {
            Text(value)
                .font(valueFont)
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private var captionSection: some View {
        if useUniformLayout {
            ZStack(alignment: .topLeading) {
                twoLinePlaceholder(font: captionFont)
                if let caption {
                    captionText(caption, lineLimit: 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let caption {
            captionText(caption)
        }
    }

    private func titleText(lineLimit: Int? = nil) -> some View {
        Text(title)
            .font(titleFont)
            .fontWeight(.semibold)
            .foregroundStyle(tint)
            .multilineTextAlignment(.leading)
            .lineLimit(lineLimit)
    }

    private func captionText(_ caption: LocalizedStringKey, lineLimit: Int? = nil) -> some View {
        Text(caption)
            .font(captionFont)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(lineLimit)
    }

    private func twoLinePlaceholder(font: Font, weight: Font.Weight = .regular) -> some View {
        Text("A\nA")
            .font(font)
            .fontWeight(weight)
            .hidden()
            .accessibilityHidden(true)
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
