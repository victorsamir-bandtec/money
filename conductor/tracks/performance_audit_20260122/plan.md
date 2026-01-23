# Plano de Implementação: Otimização de Performance (iOS Focus)

## Fase 1: Análise e Preparação
- [x] Validar execução atual dos testes (`xcodebuild test`) 💡 Skill: critical-thinking
- [x] Analisar impacto de dependências em `Installment.isOverdue` 💡 Skill: critical-thinking
- [x] Tarefa: Conductor - Verificação Manual do Usuário 'Análise e Preparação'

## Fase 2: Otimização de Modelos (Core)
- [x] Refatorar `Installment.isOverdue` para usar data de referência injetada (evitar `Calendar.current` em loops) 💡 Skill: critical-thinking
- [x] Otimizar `InstallmentOverview` para remover dependências pesadas e garantir `Sendable` 💡 Skill: critical-thinking
- [ ] Refatorar `FinanceCalculator` para garantir eficiência em projeções futuras 💡 Skill: critical-thinking
- [x] Atualizar testes unitários de Modelos afetados 💡 Skill: critical-thinking
- [x] Tarefa: Conductor - Verificação Manual do Usuário 'Otimização de Modelos'

## Fase 3: Refatoração da Dashboard (Gargalo Crítico)
- [x] Refatorar `DashboardViewModel.fetchUpcoming` para usar `FetchDescriptor<Installment>` com Predicate (SQLite) 💡 Skill: critical-thinking
- [x] Remover lógica de filtro em memória (O(n)) de `fetchUpcoming` 💡 Skill: critical-thinking
- [x] Refatorar `DashboardViewModel.fetchSummary` para otimizar queries de agregação 💡 Skill: critical-thinking
- [x] Atualizar `DashboardViewModelTests` para refletir nova estratégia de fetch 💡 Skill: critical-thinking
- [x] Tarefa: Conductor - Verificação Manual do Usuário 'Refatoração da Dashboard'

## Fase 4: Validação Final
- [x] Rodar suíte completa de testes (`xcodebuild test`) para garantir não-regressão 💡 Skill: critical-thinking
- [x] Verificação manual de fluidez na UI (Scroll e Navegação) 💡 Skill: critical-thinking
- [x] Tarefa: Conductor - Verificação Manual do Usuário 'Validação Final'
