# Money (iOS)

Money is a SwiftUI-based iOS application for tracking debtors, installment agreements, payments, fixed expenses, and salary. It features a modern "Liquid Glass" design tailored for iOS 26 (with fallback to iOS 17+) and leverages SwiftData for local persistence.

## Project Structure

The project follows an **MVVM architecture** where Views observe ViewModels, and ViewModels interact with Services and the Core Data/SwiftData layer.

### Key Directories
- **`Money/App`**: Application lifecycle, global environment (`AppEnvironment`), and theme configuration.
- **`Money/Core`**:
    - **`Models`**: SwiftData models (`@Model`) like `Debtor`, `DebtAgreement`, `Installment`.
    - **`Services`**: Business logic including `FinanceCalculator`, `CSVExporter`, and `NotificationScheduler`.
- **`Money/Presentation`**: UI Scenes organized by feature (e.g., `Dashboard`, `Debtors`, `Expenses`, `Settings`). Each feature typically contains a `Scene` (View) and a corresponding `ViewModel`.
- **`Money/Support`**: Shared utilities, extensions, and helper classes.
- **`MoneyWidgets`**: Widget extension for Home Screen summaries.
- **`MoneyTests`**: Unit tests focusing on ViewModels and Services.
- **`MoneyUITests`**: UI tests for validating critical user flows.

## Development

### Prerequisites
- **Xcode 16+** (supports iOS 17 SDK).
- **SwiftFormat** (`brew install swiftformat`) for code formatting.

### Build & Run
You can build and run the project directly from Xcode or via the command line.

**Command Line:**
```bash
# Build and Run Tests
xcodebuild -scheme Money -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' clean test
```

### Conventions

*   **Architecture:** MVVM. Views should observe ViewModels (`@StateObject` or `@ObservedObject`). Business logic should reside in Services or ViewModels, not Views.
*   **Persistence:** SwiftData. Models are injected via `ModelContext`.
*   **Formatting:** Run `swiftformat .` before committing changes.
*   **Naming:** Use `UpperCamelCase` for types and `lowerCamelCase` for properties/functions.
*   **UI Components:** Reusable components are located in `Money/Presentation/Shared`.
*   **Strings:** Use `Localizable.strings` for user-facing text (supports en-US and pt-BR).

## Testing

*   **Unit Tests (`MoneyTests`):** Validate logic in ViewModels and Services. Use `XCTest` and strict concurrency checks (`@MainActor`).
*   **UI Tests (`MoneyUITests`):** Validate end-to-end flows like creating a debtor or registering a payment.
*   **Mocking:** Use `SampleDataService` to populate data for previews and testing environments.

## Feature Implementation Flow

1.  **Model:** Update `Core/Models` if the data structure changes.
2.  **Service:** Implement business logic in `Core/Services`.
3.  **ViewModel:** Create a ViewModel to manage state and expose data to the View.
4.  **View:** Build the UI in `Presentation/<Feature>` using shared components.
5.  **Test:** Add unit tests for the ViewModel and UI tests for the user flow.
