# Repository Guidelines

## Project Structure & Module Organization
The SwiftUI app lives under `Money/`, with the entry point in `MoneyApp.swift` and main view logic in `ContentView.swift`. Domain models such as `Item` also live here. UI assets are managed through `Assets.xcassets`. Unit coverage sits in `MoneyTests/` while UI automation scenarios are stored in `MoneyUITests/`. Keep new feature files within the `Money/` folder and mirror any supporting tests inside the matching test target directory.

## Build, Test, and Development Commands
Open the project with `open Money.xcodeproj` when using Xcode. For automated builds run `xcodebuild -scheme Money -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' clean build`. Execute the full test suite with `xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15'`. When iterating on a single file, prefer Xcode’s previews to validate SwiftUI views quickly.

## Coding Style & Naming Conventions
Follow Swift API Design Guidelines with four-space indentation and trailing commas on multi-line collections. Use UpperCamelCase for types (`ExpenseListView`), lowerCamelCase for properties and functions, and prefix environment-dependent values with `app` for clarity (`appThemeColor`). Co-locate simple view-specific helpers in extensions within the same file, but move reusable logic into dedicated `*ViewModel` types.

## Testing Guidelines
XCTest is the primary framework; UI tests rely on XCUITest. Name tests using the `test_whenCondition_expectOutcome` pattern and group by feature. Always add a unit test for new view models and a UI test for flows touching navigation. Aim to keep coverage at or above the existing suite; run `xcodebuild test` before opening a PR and attach failing logs when issues appear.

## Commit & Pull Request Guidelines
Write small, purposeful commits using `type: short summary` (for example, `feat: add expense list filtering`). Describe user-facing changes in the body and mention related issue numbers. Pull requests should summarize behaviour changes, detail test evidence (`xcodebuild test` output), and include screenshots or screen recordings for any UI update. Request review before merging and wait for CI to pass.
