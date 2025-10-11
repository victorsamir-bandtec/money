import SwiftUI

/// Universal status badge component following the app's design system.
/// Replaces duplicated badge implementations across Dashboard, Debtors, and other scenes.
///
/// Usage:
/// ```swift
/// StatusBadge("status.paid", tint: .green)
/// StatusBadge("status.overdue", tint: .orange, size: .large)
/// StatusBadge("Archived", tint: .gray, style: .subtle)
/// ```
struct StatusBadge: View {
    let title: LocalizedStringKey
    let tint: Color
    var size: Size = .medium
    var style: Style = .standard

    init(_ title: LocalizedStringKey, tint: Color, size: Size = .medium, style: Style = .standard) {
        self.title = title
        self.tint = tint
        self.size = size
        self.style = style
    }

    init(_ title: String, tint: Color, size: Size = .medium, style: Style = .standard) {
        self.title = LocalizedStringKey(title)
        self.tint = tint
        self.size = size
        self.style = style
    }

    var body: some View {
        Text(title)
            .font(size.font)
            .fontWeight(.semibold)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(backgroundColor, in: Capsule())
            .foregroundStyle(foregroundColor)
    }

    private var backgroundColor: Color {
        switch style {
        case .standard:
            return tint.opacity(0.2)
        case .subtle:
            return tint.opacity(0.15)
        case .prominent:
            return tint.opacity(0.25)
        case .filled:
            return tint
        }
    }

    private var foregroundColor: Color {
        style == .filled ? .white : tint
    }
}

// MARK: - Size Configuration

extension StatusBadge {
    enum Size {
        case small
        case medium
        case large

        var font: Font {
            switch self {
            case .small:
                return .caption2
            case .medium:
                return .caption
            case .large:
                return .subheadline
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small:
                return 8
            case .medium:
                return 10
            case .large:
                return 12
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small:
                return 3
            case .medium:
                return 4
            case .large:
                return 6
            }
        }
    }
}

// MARK: - Style Configuration

extension StatusBadge {
    enum Style {
        case standard   // Default opacity
        case subtle     // Lower opacity
        case prominent  // Higher opacity
        case filled     // Solid color with white text
    }
}

// MARK: - Convenience Initializers for Common Statuses

extension StatusBadge {
    /// Creates a badge for paid status (green)
    static func paid(size: Size = .medium) -> StatusBadge {
        StatusBadge("status.paid", tint: .green, size: size)
    }

    /// Creates a badge for overdue status (orange)
    static func overdue(size: Size = .medium) -> StatusBadge {
        StatusBadge("status.overdue", tint: .orange, size: size)
    }

    /// Creates a badge for partial status (yellow)
    static func partial(size: Size = .medium) -> StatusBadge {
        StatusBadge("status.partial", tint: .yellow, size: size)
    }

    /// Creates a badge for pending status (cyan)
    static func pending(size: Size = .medium) -> StatusBadge {
        StatusBadge("status.pending", tint: .cyan, size: size)
    }

    /// Creates a badge for archived status (orange)
    static func archived(size: Size = .medium) -> StatusBadge {
        StatusBadge("debtors.row.archived", tint: .orange, size: size)
    }

    /// Creates a badge for closed/settled status (green)
    static func closed(size: Size = .medium) -> StatusBadge {
        StatusBadge("debtor.agreement.closed", tint: .green, size: size)
    }

    /// Creates a badge for open status (blue)
    static func open(size: Size = .medium) -> StatusBadge {
        StatusBadge("debtor.agreement.open", tint: .blue, size: size)
    }
}

#Preview("Status Badge Variants") {
    VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 12) {
            Text("Standard Style")
                .font(.headline)
            HStack(spacing: 12) {
                StatusBadge.paid()
                StatusBadge.overdue()
                StatusBadge.partial()
                StatusBadge.pending()
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Sizes")
                .font(.headline)
            HStack(spacing: 12) {
                StatusBadge.paid(size: .small)
                StatusBadge.paid(size: .medium)
                StatusBadge.paid(size: .large)
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Styles")
                .font(.headline)
            HStack(spacing: 12) {
                StatusBadge("Subtle", tint: .blue, style: .subtle)
                StatusBadge("Standard", tint: .blue, style: .standard)
                StatusBadge("Prominent", tint: .blue, style: .prominent)
                StatusBadge("Filled", tint: .blue, style: .filled)
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Common Use Cases")
                .font(.headline)
            HStack(spacing: 12) {
                StatusBadge.archived()
                StatusBadge.closed()
                StatusBadge.open()
            }
        }
    }
    .padding()
}
