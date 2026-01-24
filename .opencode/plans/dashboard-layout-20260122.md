# Track Definition: Dashboard Layout Reorganization

## Metadata
- **ID:** dashboard-layout-20260122
- **Status:** New
- **Type:** Feature
- **Description:** Reorganização do layout do Dashboard para melhor visibilidade

## Spec (`spec.md`)

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

## Plan (`plan.md`)

# Plan: Dashboard Layout Reorganization

### Fase 1: Arquitetura & Componentização
- [ ] Extrair e refatorar `HeroCard` (Simplificado) 💡 Skill: component-architect
- [ ] Criar componente `MetricsGrid` (LazyVGrid 2 colunas) 💡 Skill: ios-ui-crafter

### Fase 2: Integração
- [ ] Atualizar `DashboardScene` com novo layout 💡 Skill: ios-ui-crafter
- [ ] Ajustar `DashboardViewModel` para fornecer dados estruturados para o Grid (se necessário) 💡 Skill: code-refactor-master

### Fase 3: Qualidade
- [ ] Verificar Acessibilidade e Dynamic Type 💡 Skill: ios-quality-engineer
- [ ] Rodar Testes e Linter 💡 Skill: ios-quality-engineer
- [ ] Tarefa: Conductor - Verificação Manual do Usuário 'UI Polish' (Protocolo em workflow.md)
