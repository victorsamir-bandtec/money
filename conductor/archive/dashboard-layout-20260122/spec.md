# Feature: Dashboard Layout Reorganization

### Context
The current dashboard displays a dense Hero card and a horizontal carousel that hides important metrics. The goal is to improve visibility and clarify the "Available" status.

### Requirements
1. **Hero Section (Simplified)**
   - Display primarily "Available to Spend".
   - Optionally display "Remaining to Receive" as secondary context (high priority).
   - Remove "Salary", "Planned", "Received" from this card.

2. **Metrics Grid (Replaces Carousel)**
   - Implement a fixed Grid layout (2 columns) instead of horizontal scroll.
   - Include critical metrics here for full visibility:
     - Overdue (Highlight if > 0)
     - Fixed Expenses
     - Variable Expenses
     - Variable Income (Extra)
     - Re-homed metrics: Salary, Planned, Received (integrate logically).

3. **Budget Summary**
   - Ensure the "SpendingBreakdownCard" (Progress bar) remains as the visual anchor for "Money Out".

4. **Visuals**
   - Apply consistent "Liquid Glass" styling (padding, corner radius, backgrounds).
   - Ensure Accessibility (Dynamic Type) works with the new Grid.
