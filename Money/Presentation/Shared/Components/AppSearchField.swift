import SwiftUI

/// Unified search field component following the app's design system.
/// Replaces duplicated search field implementations in Debtors and Transactions scenes.
///
/// Usage:
/// ```swift
/// AppSearchField(text: $searchText, prompt: "Search debtors...")
/// AppSearchField(text: $searchText, prompt: "Search expenses...", capitalization: .never)
/// ```
struct AppSearchField: View {
    @Binding var text: String
    let prompt: LocalizedStringKey
    var capitalization: TextInputAutocapitalization = .words
    var clearable: Bool = true
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(
        text: Binding<String>,
        prompt: LocalizedStringKey,
        capitalization: TextInputAutocapitalization = .words,
        clearable: Bool = true
    ) {
        self._text = text
        self.prompt = prompt
        self.capitalization = capitalization
        self.clearable = clearable
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.body)

            TextField(prompt, text: $text)
                .textInputAutocapitalization(capitalization)
                .disableAutocorrection(true)
                .focused($isFocused)

            if clearable && !text.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        text = ""
                    }
                    isFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("common.clear")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(backgroundShape)
        .overlay(borderShape)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(fillColor)
    }

    private var borderShape: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(strokeColor, lineWidth: isFocused ? 1.5 : 1)
    }

    private var fillColor: Color {
        if isFocused {
            return colorScheme == .dark
                ? Color.white.opacity(0.12)
                : Color.black.opacity(0.06)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.05)
    }

    private var strokeColor: Color {
        if isFocused {
            return Color.accentColor.opacity(0.4)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }
}

// MARK: - Convenience Variants

extension AppSearchField {
    /// Search field optimized for names and text (word capitalization)
    static func forNames(text: Binding<String>, prompt: LocalizedStringKey = "common.search") -> AppSearchField {
        AppSearchField(text: text, prompt: prompt, capitalization: .words)
    }

    /// Search field optimized for categories and tags (no capitalization)
    static func forCategories(text: Binding<String>, prompt: LocalizedStringKey = "common.search") -> AppSearchField {
        AppSearchField(text: text, prompt: prompt, capitalization: .never)
    }

    /// Search field with clear button disabled
    static func noClear(text: Binding<String>, prompt: LocalizedStringKey = "common.search") -> AppSearchField {
        AppSearchField(text: text, prompt: prompt, clearable: false)
    }
}

#Preview("Search Field States") {
    VStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default")
                .font(.caption)
                .foregroundStyle(.secondary)
            AppSearchField(text: .constant(""), prompt: "Search debtors...")
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("With Text")
                .font(.caption)
                .foregroundStyle(.secondary)
            AppSearchField(text: .constant("João Silva"), prompt: "Search debtors...")
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("No Capitalization")
                .font(.caption)
                .foregroundStyle(.secondary)
            AppSearchField(text: .constant("category"), prompt: "Search expenses...", capitalization: .never)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("No Clear Button")
                .font(.caption)
                .foregroundStyle(.secondary)
            AppSearchField(text: .constant("Search term"), prompt: "Search...", clearable: false)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Convenience - Names")
                .font(.caption)
                .foregroundStyle(.secondary)
            AppSearchField.forNames(text: .constant(""))
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Convenience - Categories")
                .font(.caption)
                .foregroundStyle(.secondary)
            AppSearchField.forCategories(text: .constant(""))
        }
    }
    .padding()
}

#Preview("Search Field - Dark Mode") {
    VStack(spacing: 24) {
        AppSearchField(text: .constant(""), prompt: "Search...")
        AppSearchField(text: .constant("Test Search"), prompt: "Search...")
    }
    .padding()
    .background(Color(.systemBackground))
    .preferredColorScheme(.dark)
}
