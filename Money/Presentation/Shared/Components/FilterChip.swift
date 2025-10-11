import SwiftUI

/// Unified filter chip component for categories, tags, and filters.
/// Replaces FilterChip and CategoryChip implementations across Transactions and Expenses scenes.
///
/// Usage:
/// ```swift
/// FilterChip(title: "Food", isSelected: true) { /* action */ }
/// FilterChip(title: "Transport", isSelected: false, style: .prominent) { /* action */ }
/// ```
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var style: Style = .standard
    var size: Size = .medium
    let action: () -> Void

    init(
        title: String,
        isSelected: Bool,
        style: Style = .standard,
        size: Size = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.style = style
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(size.font)
                .fontWeight(.semibold)
                .padding(.horizontal, size.horizontalPadding)
                .padding(.vertical, size.verticalPadding)
                .background(backgroundColor, in: Capsule())
                .overlay(borderOverlay)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundColor)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(style.selectedBackgroundOpacity)
        }
        return style.unselectedBackgroundColor
    }

    private var foregroundColor: Color {
        isSelected ? Color.accentColor : .secondary
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if style.showBorder {
            Capsule()
                .strokeBorder(borderColor, lineWidth: 1)
        }
    }

    private var borderColor: Color {
        Color.accentColor.opacity(isSelected ? 0.6 : 0.25)
    }
}

// MARK: - Size Configuration

extension FilterChip {
    enum Size {
        case small
        case medium
        case large

        var font: Font {
            switch self {
            case .small:
                return .caption2
            case .medium:
                return .footnote
            case .large:
                return .subheadline
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small:
                return 10
            case .medium:
                return 14
            case .large:
                return 18
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small:
                return 6
            case .medium:
                return 8
            case .large:
                return 10
            }
        }
    }
}

// MARK: - Style Configuration

extension FilterChip {
    enum Style {
        case standard     // Standard with border
        case simple       // No border, minimal style
        case prominent    // Higher opacity, more visible

        var selectedBackgroundOpacity: Double {
            switch self {
            case .standard:
                return 0.2
            case .simple:
                return 0.15
            case .prominent:
                return 0.25
            }
        }

        var unselectedBackgroundColor: Color {
            switch self {
            case .standard, .prominent:
                return Color(.secondarySystemBackground)
            case .simple:
                return Color.primary.opacity(0.08)
            }
        }

        var showBorder: Bool {
            switch self {
            case .standard, .prominent:
                return true
            case .simple:
                return false
            }
        }
    }
}

// MARK: - Convenience Wrappers

extension FilterChip {
    /// Creates a simple filter chip without border
    static func simple(title: String, isSelected: Bool, action: @escaping () -> Void) -> FilterChip {
        FilterChip(title: title, isSelected: isSelected, style: .simple, action: action)
    }

    /// Creates a prominent filter chip with higher visibility
    static func prominent(title: String, isSelected: Bool, action: @escaping () -> Void) -> FilterChip {
        FilterChip(title: title, isSelected: isSelected, style: .prominent, action: action)
    }

    /// Creates a small filter chip
    static func small(title: String, isSelected: Bool, action: @escaping () -> Void) -> FilterChip {
        FilterChip(title: title, isSelected: isSelected, size: .small, action: action)
    }
}

// MARK: - Multiple Chips Container

/// Container view for displaying a horizontal row of filter chips
struct FilterChipRow: View {
    let categories: [String]
    let selectedCategory: String?
    let onToggle: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    FilterChip(
                        title: category,
                        isSelected: selectedCategory?.localizedCaseInsensitiveCompare(category) == .orderedSame,
                        action: { onToggle(category) }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview("Filter Chips") {
    VStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 12) {
            Text("States")
                .font(.headline)
            HStack(spacing: 12) {
                FilterChip(title: "Selected", isSelected: true) {}
                FilterChip(title: "Unselected", isSelected: false) {}
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Styles")
                .font(.headline)
            HStack(spacing: 12) {
                FilterChip(title: "Standard", isSelected: true, style: .standard) {}
                FilterChip(title: "Simple", isSelected: true, style: .simple) {}
                FilterChip(title: "Prominent", isSelected: true, style: .prominent) {}
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Sizes")
                .font(.headline)
            HStack(spacing: 12) {
                FilterChip(title: "Small", isSelected: true, size: .small) {}
                FilterChip(title: "Medium", isSelected: true, size: .medium) {}
                FilterChip(title: "Large", isSelected: true, size: .large) {}
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Convenience Methods")
                .font(.headline)
            HStack(spacing: 12) {
                FilterChip.simple(title: "Simple", isSelected: true) {}
                FilterChip.prominent(title: "Prominent", isSelected: true) {}
                FilterChip.small(title: "Small", isSelected: false) {}
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Filter Chip Row")
                .font(.headline)
            FilterChipRow(
                categories: ["Food", "Transport", "Health", "Entertainment", "Shopping"],
                selectedCategory: "Food",
                onToggle: { _ in }
            )
        }
    }
    .padding()
}

#Preview("Filter Chips - Dark Mode") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            FilterChip(title: "Selected", isSelected: true) {}
            FilterChip(title: "Unselected", isSelected: false) {}
        }
        FilterChipRow(
            categories: ["Category 1", "Category 2", "Category 3"],
            selectedCategory: "Category 2",
            onToggle: { _ in }
        )
    }
    .padding()
    .background(Color(.systemBackground))
    .preferredColorScheme(.dark)
}
