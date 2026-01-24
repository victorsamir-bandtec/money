# Plan: Melhoria na Análise Histórica e Projeções

## Fase 1: Preparação e Testes (Logic First)
- [ ] Criar fixture de dados para `HistoricalAnalysisTests` (Snapshots variados e Installments). 💡 Skill: `ios-quality-engineer`
- [ ] Escrever testes unitários em `CashFlowProjectorTests` validando: 💡 Skill: `ios-quality-engineer`
    - [ ] Cálculo de média ignorando mês atual e não pagos.
    - [ ] Variação Otimista (+10% Rec, -10% Desp).
    - [ ] Variação Realista (Sem mudança).
    - [ ] Variação Pessimista (-10% Rec, +10% Desp).
- [ ] Implementar nova lógica em `CashFlowProjector.swift`. 💡 Skill: `critical-thinking`
- [ ] Implementar ajustes no `HistoricalAggregator` (se necessário para filtrar "apenas pagos"). 💡 Skill: `critical-thinking`
- [ ] Garantir que testes unitários passem. 💡 Skill: `ios-quality-engineer`
- [ ] Tarefa: Conductor - Verificação Manual do Usuário 'Fase 1' (Protocolo em workflow.md).

## Fase 2: Interface de Usuário (UI)
- [ ] Criar novo componente `ProjectionCardView.swift` com design profissional (Novo Padrão). 💡 Skill: `ios-ui-crafter`
- [ ] Atualizar `HistoricalAnalysisScene.swift` para usar os novos cards. 💡 Skill: `ios-ui-crafter`
- [ ] Ajustar layout e espaçamento da seção de projeções. 💡 Skill: `ios-ui-crafter`
- [ ] Tarefa: Conductor - Verificação Manual do Usuário 'Fase 2' (Protocolo em workflow.md).

## Fase 3: Refinamento e Verificação Final
- [ ] Rodar SwiftFormat no projeto. 💡 Skill: `ios-quality-engineer`
- [ ] Rodar suíte completa de testes (`xcodebuild test`). 💡 Skill: `ios-quality-engineer`
- [ ] Verificar acessibilidade (Dynamic Type e Labels) nos novos cards. 💡 Skill: `ios-ui-crafter`
- [ ] Tarefa: Conductor - Verificação Manual do Usuário 'Fase 3' (Protocolo em workflow.md).
