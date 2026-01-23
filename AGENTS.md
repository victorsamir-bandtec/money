# Money iOS - Agent Guidelines

## Project Overview
SwiftUI personal finance app using Swift 6, SwiftData persistence, and MVVM architecture. Primary language: Brazilian Portuguese (pt-BR). Minimum iOS 17+, targeting iOS 26 with Liquid Glass design.

## Project Structure
```
Money/
├── App/              # AppEnvironment, FeatureFlags, AppError, AppTheme
├── Core/
│   ├── Models/       # SwiftData @Model classes (Debtor, DebtAgreement, Installment, etc.)
│   └── Services/     # Business logic (CurrencyFormatter, FinanceCalculator, NotificationScheduler)
├── Presentation/     # UI layer by feature (Dashboard/, Debtors/, Expenses/, Settings/, Shared/)
├── Support/          # Extensions, helpers, GlassBackgroundStyle
└── MoneyApp.swift    # Entry point
MoneyTests/           # Unit tests (XCTest + Swift Testing)
MoneyUITests/         # UI automation (XCUITest)
MoneyWidgets/         # iOS widgets
```

## Build, Test, and Lint Commands

```bash
# Open project in Xcode
open Money.xcodeproj

# Clean build (simulator)
xcodebuild -scheme Money -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' clean build

# Run ALL tests
xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15'

# Run a SINGLE test file (filter by class name)
xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MoneyTests/DashboardViewModelTests

# Run a SINGLE test method
xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MoneyTests/DashboardViewModelTests/loadsOverdueAndUpcoming

# Run UI tests only
xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MoneyUITests

# Lint/format (if SwiftFormat is installed)
swiftformat Money/ MoneyTests/ MoneyUITests/ --config .swiftformat
```

## Code Style Guidelines

### Imports
- Order: Foundation, SwiftData, SwiftUI, then third-party, then local modules
- Use `@testable import Money` only in test files
- Prefer specific imports when possible

### Formatting
- 4-space indentation (no tabs)
- Trailing commas in multi-line collections and initializers
- Max line length: 120 characters (soft limit)
- Use `// MARK: -` to separate logical sections

### Types and Naming
- Types: `UpperCamelCase` (e.g., `DashboardViewModel`, `InstallmentOverview`)
- Properties/functions: `lowerCamelCase` (e.g., `fetchSummary`, `remainingAmount`)
- Protocols: noun or adjective (`Sendable`, `Identifiable`)
- Boolean properties: prefix with `is`, `has`, `should` (e.g., `isOverdue`, `hasPayments`)
- Environment values: prefix with `app` (e.g., `appEnvironment`, `appThemeColor`)

### SwiftData Models
- Annotate with `@Model final class`
- Use `@Attribute(.unique)` for IDs
- Define relationships with `@Relationship(deleteRule:)`
- Store enums as raw values with computed property wrappers:
```swift
var statusRaw: Int
var status: InstallmentStatus {
    get { InstallmentStatus(rawValue: statusRaw) ?? .pending }
    set { statusRaw = newValue.rawValue }
}
```

### ViewModels
- Annotate with `@MainActor final class` and conform to `ObservableObject`
- Use `@Published` for observable state
- Inject dependencies via constructor (context, formatters, services)
- Keep business logic in Services; ViewModels coordinate and expose state

### Concurrency (Swift 6 Strict)
- Use `async/await` for all async code; avoid completion handlers
- Annotate UI classes with `@MainActor`
- DTOs and value types must conform to `Sendable`
- Use `.task` modifier in SwiftUI for lifecycle-bound async work

### Error Handling
- Never force unwrap (`!`); use `guard let`, `if let`, or `??`
- Use `precondition()` in initializers for programmer errors
- Domain errors via `AppError` enum with `LocalizedError` conformance
- Propagate errors with `throws`; catch at presentation layer for alerts

### Optionals
- Prefer optional chaining and nil coalescing
- Use `guard let` for early returns
- Avoid deeply nested `if let` pyramids

### SwiftUI Views
- Break complex views into smaller sub-views
- Keep views thin; delegate logic to ViewModels
- Modifier order: Content -> Layout -> Appearance
- Use `@Environment` for dependency injection

## Testing Guidelines

### Unit Tests (MoneyTests/)
- Framework: Swift Testing (`@Test`) preferred; XCTest also supported
- Naming: `test_whenCondition_expectOutcome` or descriptive string in `@Test("...")`
- Use in-memory `ModelContainer` for SwiftData tests
- Mark async tests with `@MainActor` when touching UI-bound code

```swift
@Test("Inclui parcelas vencidas e proximas") @MainActor
func loadsOverdueAndUpcoming() throws {
    let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    // ... test logic
    #expect(viewModel.upcoming.count == 2)
}
```

### UI Tests (MoneyUITests/)
- Framework: XCUITest
- Use `LocalizedKey` helper for localized accessibility identifiers
- Add `app.launchArguments += ["--uitesting"]` to reset state
- One test file per feature flow (e.g., `DashboardUITests`, `DebtorFlowUITests`)

### Running Tests
```bash
# Full suite
xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15'

# Single test class
xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MoneyTests/CurrencyFormatterTests

# Single test method (Swift Testing)
xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MoneyTests/DashboardViewModelTests/includesSalaryInAvailableCalculation
```

## Commit & PR Guidelines
- Format: `type: short summary` (e.g., `feat: add expense filtering`, `fix: correct overdue calculation`)
- Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
- Body: describe user-facing changes; reference issue numbers
- PRs: summarize changes, include test evidence, attach screenshots for UI changes
- Run `xcodebuild test` before opening PR; CI must pass before merge

## Key Services Reference
- `CurrencyFormatter`: monetary formatting (BRL locale)
- `FinanceCalculator`: installment calculations, interest, projections
- `NotificationScheduler`: local notification scheduling via `UNUserNotificationCenter`
- `CSVExporter`: CSV report generation for export
- `SampleDataService`: populates demo data for previews/development
- `AppEnvironment`: central DI container with `ModelContext`, formatters, services

## Additional Resources
- Style guide: `conductor/code_styleguides/swift.md`
- Architecture docs: `docs/architecture.md`
- Development guide: `docs/development-guide.md`
- Project structure: `docs/project-structure.md`
