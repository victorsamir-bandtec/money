import SwiftUI

// MARK: - Legacy Compatibility
/// Mantido para compatibilidade com AppEmptyState e outros componentes legados.
struct GlassBackgroundStyle {
    let material: Material
    
    static var current: GlassBackgroundStyle {
        GlassBackgroundStyle(material: .regular)
    }
}

// MARK: - Modern Liquid Glass Style
/// Um estilo visual "Liquid Glass" que aplica blur (Material), borda translúcida e sombra suave.
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 20
    var material: Material = .regular
    var shadowRadius: CGFloat = 10
    
    func body(content: Content) -> some View {
        content
            .background(material)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, x: 0, y: 5)
    }
}

// MARK: - View Extension
extension View {
    /// Aplica o efeito "Liquid Glass" ao view.
    func glassBackground(cornerRadius: CGFloat = 20, material: Material = .regular) -> some View {
        self.modifier(GlassBackground(cornerRadius: cornerRadius, material: material))
    }
}
