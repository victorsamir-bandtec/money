import Foundation

// MARK: - Category Filtering

/// Filters items by category using case-insensitive comparison.
/// Eliminates duplicated category filtering logic across ViewModels.
struct CategoryFilter {
    /// Filters a collection by matching category.
    ///
    /// Usage:
    /// ```swift
    /// let filtered = CategoryFilter.apply(to: expenses, selectedCategory: "Food")
    /// ```
    static func apply<T: Categorizable>(
        to items: [T],
        selectedCategory: String?
    ) -> [T] {
        guard let category = selectedCategory?.lowercased(), !category.isEmpty else {
            return items
        }

        return items.filter { item in
            (item.category ?? "").lowercased() == category
        }
    }
}

// MARK: - Search Text Filtering

/// Filters items by search text across multiple string fields.
/// Eliminates duplicated search logic across ViewModels.
struct SearchFilter {
    /// Filters items using a search predicate.
    ///
    /// Usage:
    /// ```swift
    /// let filtered = SearchFilter.apply(to: expenses, searchText: "internet") { expense in
    ///     expense.name.containsIgnoringCase($0) ||
    ///     (expense.category?.containsIgnoringCase($0) ?? false)
    /// }
    /// ```
    static func apply<T>(
        to items: [T],
        searchText: String,
        matching predicate: (String) -> (T) -> Bool
    ) -> [T] {
        guard let query = searchText.normalizedOrNil else {
            return items
        }

        return items.filter(predicate(query))
    }
}

// MARK: - Filter Pipeline

/// Composable filter pipeline for chaining multiple filters.
///
/// Usage:
/// ```swift
/// let filtered = FilterPipeline(items: expenses)
///     .filter(by: searchText) { expense, query in
///         expense.name.containsIgnoringCase(query)
///     }
///     .filter(by: selectedCategory, using: CategoryFilter.apply)
///     .result
/// ```
struct FilterPipeline<T> {
    private var items: [T]

    init(items: [T]) {
        self.items = items
    }

    /// Applies a custom filter predicate.
    func filter(where predicate: (T) -> Bool) -> FilterPipeline<T> {
        FilterPipeline(items: items.filter(predicate))
    }

    /// Applies a search text filter.
    func filter(
        by searchText: String,
        matching: @escaping (String) -> (T) -> Bool
    ) -> FilterPipeline<T> {
        FilterPipeline(items: SearchFilter.apply(to: items, searchText: searchText, matching: matching))
    }

    /// Returns the filtered result.
    var result: [T] {
        items
    }
}

// MARK: - Categorizable Extension

extension Collection where Element: Categorizable {
    /// Extracts unique normalized categories, sorted alphabetically.
    ///
    /// Usage:
    /// ```swift
    /// let categories = expenses.uniqueCategories
    /// ```
    var uniqueCategories: [String] {
        Array(Set(self.compactMap { $0.normalizedCategory }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
