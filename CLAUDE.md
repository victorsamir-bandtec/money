# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Money is a SwiftUI (Swift 6) iOS app for tracking debtors, installment agreements, payments, fixed expenses, and salary. The project uses MVVM architecture, SwiftData for local persistence, and targets iOS 17+ with a "Liquid Glass" visual design. The primary language is Portuguese (pt-BR) with English (en-US) localization.

## Build & Development Commands

**Open project:**
```bash
open Money.xcodeproj
```

**Build:**
```bash
xcodebuild -scheme Money -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' clean build
```

**Run all tests:**
```bash
xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Format code (before PRs):**
```bash
swiftformat .
```

**Requirements:**
- Xcode 16 beta+ with iOS 26 SDK (automatic fallback to iOS 17+)
- SwiftFormat installed: `brew install swiftformat`

## Architecture

### MVVM Pattern
Each Scene has a corresponding ViewModel that exposes state and async commands. Views observe via `@StateObject`/`@ObservedObject` and never access SwiftData directly.

```
MoneyApp → RootView → FeatureScene → FeatureViewModel → Services/Core
```

### Dependency Injection
`AppEnvironment` centralizes shared services (formatters, notification scheduler, sample data service). Injected via `Environment(\.appEnvironment)` and made available through `Environment+Injection.swift`.

### Data Flow
1. `MoneyApp.swift` creates `AppEnvironment` with SwiftData `ModelContainer`
2. `RootView` injects `modelContext` to all scenes
3. `RootView` triggers `SampleDataService.populateIfNeeded()` on first launch
4. ViewModels use `ModelContext` for fetch/insert/delete with `FetchDescriptor` and `#Predicate`
5. Updates execute `try context.save()` and notify views via `@Published`

### Core Services (Money/Core/Services)
- **CurrencyFormatter**: Centralized BRL monetary formatting (use this instead of creating NumberFormatter instances)
- **FinanceCalculator**: Business rules for installments, compound interest, projections
- **NotificationScheduler**: Wraps `UNUserNotificationCenter` for local notifications
- **CSVExporter**: Generates reports following spec (devedores.csv, acordos.csv, parcelas.csv, pagamentos.csv, despesas.csv)
- **SampleDataService**: Populates example data (debtor "Marlon") on first run

### SwiftData Models (Money/Core/Models/FinanceModels.swift)
All models use `@Model` annotation:
- `Debtor` - debt tracking with computed properties like `totalOwed`, `isActive`
- `DebtAgreement` - agreements linked to debtors
- `Installment` - auto-generated installments with `remainingAmount`, `isOverdue`
- `Payment` - payment records
- `FixedExpense` - recurring expenses
- `SalarySnapshot` - monthly salary tracking

### Feature Structure (Money/Presentation)
Each feature has a dedicated folder with Scene + ViewModel:
- **Dashboard/** - Monthly metrics, upcoming due dates, alerts
- **Debtors/** - Debtor list with search/filters, detail view with agreements
- **Expenses/** - Fixed expenses and salary management
- **Settings/** - App preferences, CSV export, sample data population

Shared components live in `Presentation/Shared/` (e.g., `MetricCard`, `RootView`).

### Navigation
- Each Scene owns its local navigation (e.g., `NavigationStack` within scenes)
- Tabs are isolated within `TabView` to prevent state leakage
- Primary navigation in `RootView`: Resumo (Dashboard) → Devedores → Despesas → Ajustes

### Styling & Theme
- **GlassBackgroundStyle** (Money/Support/): Encapsulates translucent materials with automatic fallback to `.regularMaterial`/`.ultraThinMaterial`
- **AppTheme.swift**: Global app tint is SeaGreen (#2E8B57), destructive actions use red tint
- Colors defined in Assets.xcassets; components prefer asset colors or tint variations
- All UI elements support Dynamic Type and include accessibility labels

## Code Conventions

- **Indentation**: 4 spaces, trailing commas on multi-line collections
- **Naming**: UpperCamelCase for types, lowerCamelCase for values
- **Monetary values**: Always use `Decimal` with two-decimal rounding
- **ViewModels**: Separate files within the same feature folder as the Scene
- **Helpers**: View-specific helpers can be extensions in same file; reusable utilities go to `Support/` or `Core/Services`
- **Localization**: Keys in pt-BR (default) and en-US; keep translations synchronized

## Testing

### Test Structure
- **MoneyTests/**: Unit tests for ViewModels and services (FinanceCalculator, etc.)
- **MoneyUITests/**: Critical flows (tab navigation, debtor registration, payment recording)

### Test Practices
- Use `@MainActor` and `XCTExpectations` for async operations
- Naming: `test_whenCondition_expectOutcome`
- UI tests: Use `launchArguments += ["--uitesting"]` to clean database before scenarios
- Debug SwiftData: Enable `com.apple.CoreData.SQLDebug 1` in scheme launch arguments

### Running Single Tests
In Xcode, use Test Navigator to run individual test methods. For command line, filter by test class or method name with `-only-testing`:
```bash
xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MoneyTests/DashboardViewModelTests
```

## Feature Flags

Managed via `FeatureFlags.swift` backed by `UserDefaults`. Currently includes:
- iCloud sync toggle (exposed in Settings; requires CloudKit container setup in Signing & Capabilities)

## Widgets & Intents

- **MoneyWidgets/** target: Monthly summary widget with static timeline
- Shares models via `Bundle+Module` and `SampleDataService` for consistent previews
- **MoneyShortcuts.swift**: Siri/Spotlight integration

## iCloud Configuration

The "Sincronizar com iCloud" feature flag in Settings prepares for CloudKit sync. To enable:
1. Enable iCloud Documents in Signing & Capabilities
2. Configure CloudKit container identifier
3. Implement sync logic when flag is activated

## Development Workflow

1. **Model changes**: Update `Core/Models/FinanceModels.swift` for persistent data changes
2. **Business logic**: Encapsulate in `Core/Services/` or create new service
3. **ViewModel**: Expose state via `@Published`, use `CurrencyFormatter` for monetary display
4. **Scene/View**: Build UI in `Presentation/<Feature>/`, use shared components where possible
5. **Tests**: Add unit tests for ViewModels, UI tests for navigation flows
6. **Documentation**: Update docs/ if architecture or important decisions change

## Git & Pull Requests

- **Commit format**: `type: short description` (e.g., `feat: add debtor list filtering`)
- **PR requirements**:
  - Summary of changes
  - Test evidence (`xcodebuild test` output)
  - Screenshots for visual changes
  - Wait for CI green before merging
- **Before PR**: Run `swiftformat .`

## Debugging Tips

- Use SwiftUI Previews (⌥+Cmd+P) for rapid iteration
- Avoid unnecessary `Task {}` in views; prefer `.task` modifier or `@MainActor` in ViewModel
- For SwiftData debugging, enable SQL logging in scheme launch arguments
- Notification permissions: Check `SettingsViewModel` for user guidance when access denied

## Current Roadmap

- Implement actual CloudKit sync when iCloud flag is enabled
- Complete notification automation for partial payment scenarios
- Add widget and intent tests once dedicated targets are configured in project
