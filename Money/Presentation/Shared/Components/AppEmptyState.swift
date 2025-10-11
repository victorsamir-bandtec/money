import SwiftUI

/// Universal empty state component following the app's design system.
/// Replaces duplicated empty state implementations in Debtors, Expenses, and other scenes.
///
/// Usage:
/// ```swift
/// AppEmptyState(
///     icon: "person.badge.plus",
///     title: "No Debtors",
///     message: "Add your first debtor to get started",
///     actionTitle: "Add Debtor",
///     action: { /* action */ }
/// )
/// ```
struct AppEmptyState: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil
    var style: Style = .standard

    init(
        icon: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil,
        style: Style = .standard
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.style = style
    }

    var body: some View {
        VStack(spacing: style.spacing) {
            iconView
            titleView
            messageView
            if let actionTitle, let action {
                actionButton(title: actionTitle, action: action)
            }
        }
        .padding(style.padding)
        .frame(maxWidth: .infinity, alignment: style.alignment)
        .background(backgroundView)
    }

    private var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: style.iconSize, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .symbolRenderingMode(.hierarchical)
    }

    private var titleView: some View {
        Text(title)
            .font(style.titleFont)
            .fontWeight(.semibold)
            .multilineTextAlignment(.center)
    }

    private var messageView: some View {
        Text(message)
            .font(style.messageFont)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private func actionButton(title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.accentColor)
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style.background {
        case .clear:
            EmptyView()
        case .material:
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(GlassBackgroundStyle.current.material)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08))
                )
        case .secondary:
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
    }
}

// MARK: - Style Configuration

extension AppEmptyState {
    enum Style {
        case compact        // Smaller, minimal padding
        case standard       // Default style with glass background
        case prominent      // Larger, more visible
        case minimal        // No background, minimal spacing

        var iconSize: CGFloat {
            switch self {
            case .compact:
                return 36
            case .standard:
                return 44
            case .prominent:
                return 52
            case .minimal:
                return 40
            }
        }

        var titleFont: Font {
            switch self {
            case .compact:
                return .subheadline
            case .standard:
                return .headline
            case .prominent:
                return .title3
            case .minimal:
                return .headline
            }
        }

        var messageFont: Font {
            switch self {
            case .compact:
                return .caption
            case .standard, .prominent:
                return .subheadline
            case .minimal:
                return .footnote
            }
        }

        var spacing: CGFloat {
            switch self {
            case .compact:
                return 12
            case .standard:
                return 16
            case .prominent:
                return 20
            case .minimal:
                return 10
            }
        }

        var padding: CGFloat {
            switch self {
            case .compact:
                return 24
            case .standard:
                return 32
            case .prominent:
                return 40
            case .minimal:
                return 16
            }
        }

        var alignment: Alignment {
            .center
        }

        var background: Background {
            switch self {
            case .compact:
                return .secondary
            case .standard:
                return .material
            case .prominent:
                return .material
            case .minimal:
                return .clear
            }
        }

        enum Background {
            case clear
            case material
            case secondary
        }
    }
}

// MARK: - Convenience Initializers

extension AppEmptyState {
    /// Creates an empty state for no data scenarios
    static func noData(
        icon: String = "tray",
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) -> AppEmptyState {
        AppEmptyState(
            icon: icon,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action,
            style: .standard
        )
    }

    /// Creates an empty state for filtered results
    static func noResults(
        icon: String = "line.3.horizontal.decrease.circle",
        title: LocalizedStringKey = "common.no.results",
        message: LocalizedStringKey = "common.no.results.message"
    ) -> AppEmptyState {
        AppEmptyState(
            icon: icon,
            title: title,
            message: message,
            style: .minimal
        )
    }

    /// Creates an empty state for search results
    static func noSearchResults(
        searchTerm: String,
        message: LocalizedStringKey = "common.no.search.results.message"
    ) -> AppEmptyState {
        AppEmptyState(
            icon: "magnifyingglass",
            title: "common.no.search.results",
            message: message,
            style: .minimal
        )
    }

    /// Creates an empty state with custom action
    static func withAction(
        icon: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> AppEmptyState {
        AppEmptyState(
            icon: icon,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action,
            style: .standard
        )
    }
}

#Preview("Empty State Variants") {
    ScrollView {
        VStack(spacing: 40) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Standard with Action")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AppEmptyState(
                    icon: "person.badge.plus",
                    title: "No Debtors",
                    message: "Add your first debtor to start tracking",
                    actionTitle: "Add Debtor",
                    action: {},
                    style: .standard
                )
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Compact Style")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AppEmptyState(
                    icon: "doc.text",
                    title: "No Documents",
                    message: "No documents found",
                    style: .compact
                )
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Prominent Style")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AppEmptyState(
                    icon: "creditcard",
                    title: "No Expenses",
                    message: "Start adding your monthly expenses to track your budget",
                    actionTitle: "Add Expense",
                    action: {},
                    style: .prominent
                )
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Minimal Style")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AppEmptyState(
                    icon: "line.3.horizontal.decrease.circle",
                    title: "No Results",
                    message: "Try adjusting your filters",
                    style: .minimal
                )
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Convenience - No Data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AppEmptyState.noData(
                    title: "No Items",
                    message: "Add your first item to get started",
                    actionTitle: "Add Item",
                    action: {}
                )
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Convenience - No Results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AppEmptyState.noResults()
            }
        }
        .padding()
    }
}

#Preview("Empty State - Dark Mode") {
    VStack(spacing: 40) {
        AppEmptyState(
            icon: "person.badge.plus",
            title: "No Debtors",
            message: "Add your first debtor to start tracking",
            actionTitle: "Add Debtor",
            action: {}
        )

        AppEmptyState.noResults()
    }
    .padding()
    .background(Color(.systemBackground))
    .preferredColorScheme(.dark)
}
