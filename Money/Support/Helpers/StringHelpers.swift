import Foundation

// MARK: - String Extensions for Common Operations

extension String {
    /// Returns the string trimmed of whitespace and newlines, or nil if empty after trimming.
    /// Replaces duplicated `normalized()` implementations across ViewModels.
    ///
    /// Usage:
    /// ```swift
    /// let name = userInput.normalizedOrNil // Returns nil if empty/whitespace
    /// let category = draft.category.normalizedOrNil ?? "Uncategorized"
    /// ```
    var normalizedOrNil: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Returns the string trimmed of whitespace and newlines.
    /// Never returns nil, returns empty string if only whitespace.
    ///
    /// Usage:
    /// ```swift
    /// let displayName = userInput.normalized // Always returns a string
    /// ```
    var normalized: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns true if the string is empty or contains only whitespace/newlines.
    ///
    /// Usage:
    /// ```swift
    /// if !name.isBlankOrEmpty {
    ///     // Process valid name
    /// }
    /// ```
    var isBlankOrEmpty: Bool {
        self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Returns true if the string is not empty and contains non-whitespace characters.
    var isNotBlank: Bool {
        !self.isBlankOrEmpty
    }
}

// MARK: - Optional String Extensions

extension Optional where Wrapped == String {
    /// Returns the normalized string, or nil if the optional is nil or empty after trimming.
    /// Extremely useful for optional text fields.
    ///
    /// Usage:
    /// ```swift
    /// let note = draft.note.normalizedOrNil // Handles nil and empty
    /// let category = expense.category.normalizedOrNil ?? "General"
    /// ```
    var normalizedOrNil: String? {
        guard let value = self else { return nil }
        return value.normalizedOrNil
    }

    /// Returns true if the optional string is nil, empty, or contains only whitespace.
    ///
    /// Usage:
    /// ```swift
    /// if debtor.note.isNilOrBlank {
    ///     // Show placeholder
    /// }
    /// ```
    var isNilOrBlank: Bool {
        guard let value = self else { return true }
        return value.isBlankOrEmpty
    }

    /// Returns true if the optional string has meaningful content (not nil, not blank).
    var hasContent: Bool {
        !self.isNilOrBlank
    }
}

// MARK: - Collection String Extensions

extension Collection where Element == String {
    /// Filters and normalizes strings, removing blank entries.
    /// Useful for processing user input arrays.
    ///
    /// Usage:
    /// ```swift
    /// let validTags = tags.normalizedNonEmpty // Removes empty/whitespace strings
    /// ```
    var normalizedNonEmpty: [String] {
        self.compactMap { $0.normalizedOrNil }
    }
}

// MARK: - String Comparison Helpers

extension String {
    /// Case-insensitive equality check with optional strings.
    /// Handles nil gracefully.
    ///
    /// Usage:
    /// ```swift
    /// if category.equalsIgnoringCase(selectedCategory) {
    ///     // Match found
    /// }
    /// ```
    func equalsIgnoringCase(_ other: String?) -> Bool {
        guard let other = other else { return false }
        return self.localizedCaseInsensitiveCompare(other) == .orderedSame
    }

    /// Case-insensitive contains check.
    ///
    /// Usage:
    /// ```swift
    /// if debtor.name.containsIgnoringCase(searchText) {
    ///     // Match found
    /// }
    /// ```
    func containsIgnoringCase(_ substring: String) -> Bool {
        return self.localizedCaseInsensitiveContains(substring)
    }
}

// MARK: - Validation Helpers

extension String {
    /// Returns true if string represents a valid decimal number.
    var isValidDecimal: Bool {
        Decimal(string: self) != nil
    }

    /// Returns true if string represents a valid integer.
    var isValidInteger: Bool {
        Int(self) != nil
    }

    /// Returns true if string has minimum length after normalization.
    func hasMinimumLength(_ length: Int) -> Bool {
        self.normalized.count >= length
    }

    /// Returns true if string has maximum length after normalization.
    func hasMaximumLength(_ length: Int) -> Bool {
        self.normalized.count <= length
    }
}

// MARK: - String Formatting Helpers

extension String {
    /// Capitalizes first letter only, leaving rest unchanged.
    /// Useful for proper name formatting.
    ///
    /// Usage:
    /// ```swift
    /// let name = "joão silva".capitalizedFirstLetter // "João silva"
    /// ```
    var capitalizedFirstLetter: String {
        guard !self.isEmpty else { return self }
        return self.prefix(1).uppercased() + self.dropFirst()
    }

    /// Truncates string to maximum length with ellipsis if needed.
    ///
    /// Usage:
    /// ```swift
    /// let preview = note.truncated(to: 50) // "This is a long note that will be truncat..."
    /// ```
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count <= length {
            return self
        }
        let truncatedLength = max(0, length - trailing.count)
        return String(self.prefix(truncatedLength)) + trailing
    }
}

// MARK: - Common Validation Patterns

struct StringValidator {
    /// Validates that a name is not blank and has reasonable length.
    static func isValidName(_ name: String?, minLength: Int = 1, maxLength: Int = 100) -> Bool {
        guard let name = name?.normalizedOrNil else { return false }
        return name.count >= minLength && name.count <= maxLength
    }

    /// Validates that a category/tag is properly formatted.
    static func isValidCategory(_ category: String?) -> Bool {
        guard let category = category?.normalizedOrNil else { return false }
        return category.count >= 2 && category.count <= 50
    }

    /// Validates that a note is within acceptable length.
    static func isValidNote(_ note: String?, maxLength: Int = 500) -> Bool {
        guard let note = note else { return true } // Notes are optional
        let normalized = note.normalized
        return normalized.isEmpty || normalized.count <= maxLength
    }
}

// MARK: - Categorizable Protocol

/// Protocol for models that have an optional category field.
/// Provides consistent category normalization across all types.
protocol Categorizable {
    var category: String? { get }
}

extension Categorizable {
    /// Returns the normalized category (trimmed and non-empty) or nil.
    var normalizedCategory: String? {
        category.normalizedOrNil
    }
}

#if DEBUG
// MARK: - Preview Helpers

extension String {
    /// Generates a placeholder text for previews.
    static func placeholder(length: Int = 50) -> String {
        String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: (length / 57) + 1)
            .prefix(length)
            .trimmingCharacters(in: .whitespaces)
    }
}
#endif
