# Plano: Componentizar cartão padrão de métricas

## Contexto
- Os cartões da tela **Resumo** (`BalanceOverviewCard`, `QuickMetricTile`, `SpendingBreakdownCard`) aplicam o modificador `dashboardCard` com gradiente + sombra dupla (`Money/Presentation/Dashboard/DashboardScene.swift:232-413`).
- Em outros fluxos repetimos variações com `RoundedRectangle` e `glassBackground`, gerando inconsistências (ex.: `DebtorsSummaryCard`, `DebtorRow`, `AgreementCard`, `VariableHeroCard`, `ExpenseCard`).
- O componente compartilhado `MetricCard` (`Money/Presentation/Shared/MetricCard.swift`) é amplamente usado, mas possui um backplate próprio (sem a mesma sombra/tinta).

## Objetivo
Criar um componente reutilizável (ex.: `MoneyCard`) que encapsule o estilo do Resumo e aplicá-lo a todos os cartões que exibem valores/métricas (Resumo, Devedores, Lançamentos, Acordos), garantindo consistência em light/dark mode e boa acessibilidade.

## Escopo & Alvos
- **Scenes**: Dashboard, Debtors, DebtorDetail, AgreementDetail, Transactions (hero + filtros + cards), revisitar também `MoneyWidgets` se houver cartões similares.
- **Componentes existentes**: `MetricCard`, `dashboardCard`, `HeroBackground`, `AgreementCard`, `InstallmentCard`, `ExpenseCard`, `DebtorRow`, `TransactionsSummaryCard`, `ExpensesSummaryCard`, `TransactionsHeader`.
- Fora de escopo: cartões puramente informativos com vidro (`GlassBackgroundStyle`) quando não exibem métricas financeiras.

## Estratégia de Implementação
1. **Mapear tokens visuais**
   - Extrair corner radius, gradientes, opacidades e sombras do `DashboardCardModifier`.
   - Catalogar espaçamentos/tipografia em `MetricCard`, `HeroBackground`, `AgreementCard`, `ExpenseCard` para entender variações necessárias.
2. **Criar base compartilhada**
   - Adicionar em `Presentation/Shared` um `MoneyCardStyle` (ViewModifier) que recebe tint, corner radius e intensidade (`standard` / `compact`).
   - Expor `View.moneyCard(tint:cornerRadius:shadow:)` reutilizando o mesmo gradiente e sombra dupla do Resumo.
3. **Variações e presets**
   - Implementar `MoneyCard` view genérica com slots (`header`, `content`, `footer`) para layouts comuns.
   - Reescrever `MetricCard` para usar `MoneyCardStyle`, preservando a API (`Style.standard/prominent`) e o badge de ícone.
4. **Migrar Dashboard**
   - Substituir `dashboardCard` pelo novo estilo e remover `DashboardCardModifier`.
   - Atualizar `BalanceOverviewCard`, `SpendingBreakdownCard`, `QuickMetricTile` para usar `MoneyCard` mantendo layout atual.
5. **Migrar Devedores**
   - Atualizar `DebtorsSummaryCard` (`Money/Presentation/Debtors/DebtorsScene.swift:118-204`) para envolver os blocos em `MoneyCard`.
   - Refatorar `DebtorRow` (`Money/Presentation/Debtors/DebtorsScene.swift:293-360`) usando `moneyCard` em modo compacto.
   - Em `DebtorDetailScene` (`Money/Presentation/Debtors/DebtorDetailScene.swift:33-215`) aplicar `MoneyCard` nos blocos de métricas e na seção de informações do devedor.
6. **Migrar AgreementDetail**
   - Atualizar as métricas iniciais e o card de progresso (`Money/Presentation/Debtors/AgreementDetailScene.swift:96-220`) para o novo componente.
   - Revisar `AgreementCard` e `InstallmentCard` para trocar `glassBackground`/`RoundedRectangle` por `MoneyCardStyle` sem quebrar animações ou gestos de swipe.
7. **Migrar Transactions**
   - Aplicar `MoneyCard` em `VariableHeroCard` e `FixedExpensesHeroCard` (`Money/Presentation/Transactions/TransactionsScene.swift:440-540`).
   - Envolver `TransactionsSummaryCard` e `ExpensesSummaryCard` (`Money/Presentation/Transactions/TransactionsScene.swift:788-930`) com o novo estilo.
   - Atualizar `ExpenseCard` (`Money/Presentation/Transactions/TransactionsScene.swift:1050-1140`) garantindo contraste dos badges pós-migração.
8. **Varredura final**
   - Executar `rg "RoundedRectangle(cornerRadius" Money/Presentation` para encontrar cartões restantes (ex.: `ExpensesEmptyState`, `DebtorsEmptyState`) e decidir caso a caso.
   - Atualizar previews das principais telas para facilitar QA visual.
9. **Remoção e limpeza**
   - Remover `HeroBackground`, `DashboardCardModifier` e duplicações após a migração completa.
   - Revisar `Assets.xcassets` para garantir que os tints usados estejam centralizados.
10. **Testes e validação**
    - Rodar `xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15'`.
    - Validar manualmente em simulador iPhone 15 nos modos claro/escuro e com Dynamic Type Large.
    - Verificar contrastes via Accessibility Inspector e ajustar se necessário.

## Riscos & Mitigações
- **Regressão visual**: manter screenshots de referência e usar SwiftUI previews para comparação antes/depois.
- **Animar cartões existentes**: `InstallmentCard` usa animações customizadas; ajustar `clipShape` e sombras para evitar "pop".
- **Desempenho**: gradientes + sombras podem pesar; medir com Instruments caso surjam quedas de FPS.

## Entregáveis
- Novo componente em `Presentation/Shared`.
- Refatorações nas scenes listadas.
- Atualização (ou adição) de testes e documentação curta descrevendo o padrão.

## Validação Final
- Revisão visual com design/PM.
- Execução completa da suíte de testes.
- Checklist de contrastes e acessibilidade antes do PR.
