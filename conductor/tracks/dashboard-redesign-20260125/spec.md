# Specification: Redesign Dashboard (Resumo)

## Context
Refactor the existing `DashboardScene` to provide a modern, clear financial overview using the "Liquid Glass" design language. The goal is to highlight the user's available balance and provide quick access to key financial metrics and upcoming obligations.

## Requirements

### 1. Visual Style
- **Liquid Glass:** Use `GlassBackgroundStyle` (or create similar) for cards to provide depth, translucency, and blur.
- **Modern Layout:** Clean spacing, rounded corners, and clear typography hierarchy.

### 2. Header
- Keep standard large title "Resumo".
- Add contextual greeting or date if appropriate for the "Standard" feel, but keep it clean.

### 3. Hero Section: Available Balance
- **Prominence:** This is the most important element.
- **Content:** Display "Saldo disponível" and the calculated value (Salary - Fixed/Variable Expenses).
- **Visuals:** Large, bold typography. Potentially a subtle background gradient or glass effect to separate it.

### 4. Secondary Content
- **Summary Cards (Grid/Row):**
    - Fixed Expenses (Total)
    - Variable Expenses (Total)
    - Extra Income (Total)
- **Budget Visualizer:**
    - A visual representation (progress bar or ring) of budget consumption (Expenses vs Income).
- **Upcoming Payments:**
    - A section showing the next few upcoming installments (debtors or own debts).
    - Empty state if no upcoming payments.

### 5. Technical Changes
- **Modify:** `DashboardScene.swift` to implement the new layout using `ScrollView` and `VStack`.
- **Refactor/Create:**
    - Update `DashboardHeroCard.swift` or create `BalanceHeroView.swift`.
    - Update/Create `MetricsGrid.swift` to support the new card style.
    - Create `UpcomingPaymentsView.swift`.
    - Create `BudgetProgressView.swift`.
- **ViewModel:** Update `DashboardViewModel.swift` to expose the necessary data for these new views (if not already available).

## Acceptance Criteria
- Dashboard displays Available Balance prominently.
- Summary cards show correct totals for Fixed, Variable, and Extra Income.
- "Upcoming Payments" shows relevant items or empty state.
- UI follows Liquid Glass design (translucency, blur).
- Dark mode support is verified.
