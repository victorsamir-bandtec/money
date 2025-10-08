import SwiftUI

/// Unified background component for the app following the "Liquid Glass" design philosophy.
/// Provides a rich, premium visual experience with three layers:
/// 1. Base color (systemBackground)
/// 2. Linear gradient (diagonal, rich colors)
/// 3. Radial gradient (customizable accent color and position)
struct AppBackground: View {
    let variant: Variant

    @Environment(\.colorScheme) private var colorScheme

    /// Background variants for different sections of the app
    enum Variant {
        /// Dashboard (Resumo) - SeaGreen theme, centered radial
        case dashboard
        /// Debtors management - SeaGreen theme, top-leading radial
        case debtors
        /// Transactions and expenses - Pink theme, top-trailing radial
        case transactions
        /// Settings and configuration - Neutral gray theme, subtle radial
        case settings

        var accentColor: Color {
            switch self {
            case .dashboard, .debtors:
                return .appThemeColor
            case .transactions:
                return .pink
            case .settings:
                return .gray
            }
        }

        var radialCenter: UnitPoint {
            switch self {
            case .dashboard:
                return .top
            case .debtors:
                return .topLeading
            case .transactions:
                return .topTrailing
            case .settings:
                return .center
            }
        }

        func radialOpacity(for colorScheme: ColorScheme) -> Double {
            let baseOpacity = colorScheme == .dark ? 0.25 : 0.12
            // Settings has more subtle radial effect
            return self == .settings ? baseOpacity * 0.6 : baseOpacity
        }
    }

    var body: some View {
        ZStack {
            // Layer 1: Base background
            Color(.systemBackground)

            // Layer 2: Rich diagonal linear gradient
            LinearGradient(
                colors: linearGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(colorScheme == .dark ? 1 : 0.6)

            // Layer 3: Radial gradient with customizable accent color
            RadialGradient(
                colors: [
                    variant.accentColor.opacity(variant.radialOpacity(for: colorScheme)),
                    Color.clear
                ],
                center: variant.radialCenter,
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    /// Rich gradient colors that adapt to light/dark mode
    private var linearGradientColors: [Color] {
        if colorScheme == .dark {
            // Deep, rich colors for dark mode - premium night theme
            return [
                Color(red: 0.05, green: 0.08, blue: 0.13), // Deep blue-black
                Color(red: 0.01, green: 0.02, blue: 0.05)  // Almost pure black
            ]
        } else {
            // Soft, system-native colors for light mode
            return [
                Color(.systemGroupedBackground),
                Color(.secondarySystemGroupedBackground)
            ]
        }
    }
}

#Preview("Dashboard Variant - Dark") {
    AppBackground(variant: .dashboard)
        .preferredColorScheme(.dark)
}

#Preview("Dashboard Variant - Light") {
    AppBackground(variant: .dashboard)
        .preferredColorScheme(.light)
}

#Preview("Debtors Variant - Dark") {
    AppBackground(variant: .debtors)
        .preferredColorScheme(.dark)
}

#Preview("Transactions Variant - Dark") {
    AppBackground(variant: .transactions)
        .preferredColorScheme(.dark)
}

#Preview("Settings Variant - Dark") {
    AppBackground(variant: .settings)
        .preferredColorScheme(.dark)
}
