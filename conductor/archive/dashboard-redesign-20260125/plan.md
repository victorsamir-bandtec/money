# Implementation Plan - Redesign Dashboard

## Phase 1: Component Design (UI First)
Focus: Create the individual SwiftUI components with Liquid Glass styling.
- [x] Create `GlassBackgroundStyle` helper (if not exists or needs update) 💡 Skill: ios-ui-crafter
- [x] Create `BalanceHeroView` (Hero Section) 💡 Skill: ios-ui-crafter
- [x] Create `SummaryCardView` (Generic card for secondary metrics) 💡 Skill: ios-ui-crafter
- [x] Create `BudgetProgressView` (Visualizer) 💡 Skill: ios-ui-crafter
- [x] Create `UpcomingPaymentsView` (List component) 💡 Skill: ios-ui-crafter
- [x] Task: Conductor - Verify Components (Previews & Dark Mode)

## Phase 2: Logic & Integration (MVVM)
Focus: Update ViewModel and integrate components into the main Scene.
- [x] Update `DashboardViewModel` to compute available balance (Salary - Expenses) 💡 Skill: ios-quality-engineer
- [x] Update `DashboardViewModel` to expose budget progress data 💡 Skill: ios-quality-engineer
- [x] Implement `DashboardScene` with new `ScrollView` layout 💡 Skill: ios-architect
- [x] Integrate `BalanceHeroView` with ViewModel data 💡 Skill: ios-architect
- [x] Integrate Secondary Content (Cards, Visualizer, List) 💡 Skill: ios-architect
- [x] Task: Conductor - Verify Dashboard Integration (Run App)

## Phase 3: Polish & Verification
Focus: Animations, transitions, and final quality checks.
- [x] Add transition animations for state changes 💡 Skill: ios-ui-crafter
- [x] Audit Accessibility (Dynamic Type & VoiceOver labels) 💡 Skill: ios-quality-engineer
- [x] Verify functionality with empty states (no data) 💡 Skill: ios-quality-engineer
- [x] Run full test suite and SwiftFormat 💡 Skill: ios-quality-engineer
- [x] Task: Conductor - Final Verification (User Acceptance)
