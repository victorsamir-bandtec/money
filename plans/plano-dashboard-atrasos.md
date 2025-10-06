# Plano: Corrigir métricas e alertas de parcelas vencidas no Dashboard

## Contexto
- `DashboardViewModel.fetchSummary` e `fetchUpcoming` (Money/Presentation/Dashboard/DashboardViewModel.swift:70-134) apenas consideram parcelas do mês atual ou dos próximos 14 dias.
- Parcela vencida antes do mês corrente desaparece do total `overdue` e da lista `alerts`, impedindo ação rápida.

## Objetivo
Garantir que o dashboard sempre mostre:
1. Total vencido acumulado (independente do mês de referência).
2. Lista combinando parcelas já vencidas e próximas a vencer.
3. Diferença clara entre "receita prevista" e "atraso acumulado".

## Passos de Implementação
1. **Refatorar `fetchSummary`**
   - Separar três coleções: parcelas vencidas (`dueDate < currentDate && status != .paid`), parcelas do mês atual e pagamentos do mês.
   - Calcular `monthIncome` com parcelas cujo `dueDate` está no mês corrente.
   - Calcular `overdue` usando a nova coleção de vencidos (somando `remainingAmount`).
   - Adicionar propriedade `overdueCount` se útil para UI (opcional).
2. **Refatorar `fetchUpcoming`**
   - Separar consultas: `overdue = installments where dueDate < currentDate && status != .paid` e `upcomingWindow = installments where dueDate in currentDate...currentDate+14d`.
   - Definir `alerts = (overdue + upcomingWindow).sorted(by: dueDate)` sem duplicar registros (usar `Set` por `id`).
   - Manter `upcoming` apenas com o período futuro para não quebrar UI atual.
3. **Atualizar `DashboardScene` (Money/Presentation/Dashboard/DashboardScene.swift)**
   - Garantir que o texto de "alertas" explique que inclui atrasos.
   - Se necessário, exibir badge com `overdue.count`.
4. **Validar consultas SwiftData**
   - Adicionar testes unitários no estilo `DashboardViewModelTests` (criar novo arquivo em MoneyTests) cobrindo cenários com parcelas vencidas em meses anteriores, abertas e quitadas.
5. **Teste manual**
   - Popular dados via `SampleDataService` ou caso manual; garantir que dashboard mostra corretamente atrasados, próximos vencimentos e totais.

## Riscos e Mitigações
- **Performance**: múltiplos fetches; mitigar com predicates específicos e reduzindo campos carregados ao necessário.
- **UI**: mudanças no layout do card de alertas; revisar acessibilidade após ajustes.

## Validação
- Rodar `xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15'`.
- Revisar tela Dashboard com dados contendo parcelas vencidas e futuras.
