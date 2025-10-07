import SwiftUI

enum MoneyCardShadow {
    case standard
    case compact

    func radius(for size: CGSize?) -> CGFloat {
        let base: CGFloat
        switch self {
        case .standard: base = 28
        case .compact: base = 18
        }
        guard let size else { return base }
        let scale = max(min(size.width, size.height) / 200, 0.7)
        return base * scale
    }

    func offset(for size: CGSize?) -> CGFloat {
        let base: CGFloat
        switch self {
        case .standard: base = 20
        case .compact: base = 12
        }
        guard let size else { return base }
        let scale = max(min(size.width, size.height) / 200, 0.7)
        return base * scale
    }

    func tintOpacity(for size: CGSize?) -> Double {
        let base: Double
        switch self {
        case .standard: base = 0.22
        case .compact: base = 0.16
        }
        guard let size else { return base }
        let scale = max(min(Double(min(size.width, size.height) / 200), 1.1), 0.7)
        return base * scale
    }

    func softRadius(for size: CGSize?) -> CGFloat {
        radius(for: size) * 0.55
    }

    func softOffset(for size: CGSize?) -> CGFloat {
        offset(for: size) * 0.6
    }
}

enum MoneyCardIntensity {
    case subtle
    case standard
    case prominent

    var gradientOpacity: (Double, Double) {
        switch self {
        case .subtle: return (0.12, 0.04)
        case .standard: return (0.18, 0.05)
        case .prominent: return (0.24, 0.08)
        }
    }

    var borderOpacity: Double {
        switch self {
        case .subtle: return 0.14
        case .standard: return 0.2
        case .prominent: return 0.28
        }
    }
}

private struct MoneyCardStyle: ViewModifier {
    let tint: Color
    let cornerRadius: CGFloat
    let shadow: MoneyCardShadow
    let intensity: MoneyCardIntensity

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    ZStack {
                        shadowOverlay(size: proxy.size)
                        shape
                            .fill(baseGradient)
                            .overlay(
                                shape
                                    .fill(tintGradient)
                                    .blendMode(.plusLighter)
                            )
                        shape.strokeBorder(borderGradient, lineWidth: 1)
                    }
                }
            )
    }

    private func shadowOverlay(size: CGSize?) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color.clear, lineWidth: 0)
            .shadow(
                color: Color.black.opacity(0.08),
                radius: shadow.softRadius(for: size),
                x: 0,
                y: shadow.softOffset(for: size)
            )
            .shadow(
                color: tint.opacity(shadow.tintOpacity(for: size)),
                radius: shadow.radius(for: size),
                x: 0,
                y: shadow.offset(for: size)
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    private var baseGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemBackground).opacity(0.96),
                Color(.secondarySystemBackground).opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var tintGradient: LinearGradient {
        LinearGradient(
            colors: [
                tint.opacity(intensity.gradientOpacity.0),
                tint.opacity(intensity.gradientOpacity.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.55),
                tint.opacity(intensity.borderOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct MoneyCard<Content: View>: View {
    let tint: Color
    var cornerRadius: CGFloat = 24
    var shadow: MoneyCardShadow = .standard
    var intensity: MoneyCardIntensity = .standard
    let content: () -> Content

    init(
        tint: Color,
        cornerRadius: CGFloat = 24,
        shadow: MoneyCardShadow = .standard,
        intensity: MoneyCardIntensity = .standard,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.intensity = intensity
        self.content = content
    }

    var body: some View {
        content()
            .moneyCard(tint: tint, cornerRadius: cornerRadius, shadow: shadow, intensity: intensity)
    }
}

extension View {
    func moneyCard(
        tint: Color,
        cornerRadius: CGFloat = 24,
        shadow: MoneyCardShadow = .standard,
        intensity: MoneyCardIntensity = .standard
    ) -> some View {
        modifier(MoneyCardStyle(tint: tint, cornerRadius: cornerRadius, shadow: shadow, intensity: intensity))
    }
}
