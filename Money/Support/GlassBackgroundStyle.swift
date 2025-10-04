import SwiftUI

struct GlassBackgroundStyle {
    let material: Material

    static var current: GlassBackgroundStyle {
        if #available(iOS 26, *) {
            // TODO: Substituir pelo material oficial "Liquid Glass" quando disponível publicamente.
            return GlassBackgroundStyle(material: .ultraThickMaterial)
        }
        if #available(iOS 15, *) {
            return GlassBackgroundStyle(material: .regularMaterial)
        }
        return GlassBackgroundStyle(material: .ultraThinMaterial)
    }
}

extension View {
    func glassBackground() -> some View {
        background(GlassBackgroundStyle.current.material)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
