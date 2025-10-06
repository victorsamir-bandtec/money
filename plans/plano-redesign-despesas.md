# Plano: Redesenho e novas funcionalidades da tela de Despesas

## Objetivo
Unificar a tela de Despesas ao padrão visual em cartões usado na tela de Devedores e ampliar as funcionalidades para facilitar análise, filtro e manutenção das despesas fixas e do salário mensal.

## Diagnóstico Atual
- `Money/Presentation/Expenses/ExpensesScene.swift:18-107` usa `List` com `Section` simples, sem fundo customizado, cartões translúcidos ou espaçamentos amplos como em `DebtorsScene`.
- A lista mostra apenas nome, valor, vencimento e categoria; não há busca, filtro, ordenação, indicadores de status ou ações além de remover (`ExpensesScene.swift:94-104`).
- O salário é exibido de forma minimalista (`ExpensesScene.swift:68-87`), sem métricas de cobertura do orçamento, histórico ou acesso rápido ao formulário.
- `Money/Presentation/Expenses/ExpensesViewModel.swift` expõe apenas arrays crus e não trata estados derivados (despesas ativas x arquivadas, totais por categoria, diferença em relação ao salário etc.).
- O modelo `FixedExpense` já possui o campo `active`, porém o fluxo atual não permite arquivar/restaurar despesas; funcionalidades como duplicar ou editar registros existentes também estão ausentes.

## Plano de Ação Detalhado

1. **Alinhar layout com o padrão de cartões**
   - Migrar `ExpensesScene` para a mesma estrutura visual do módulo de Devedores: `NavigationStack` + `List` com seções espaçadas, `listRowBackground(.clear)` e `DebtorsBackground` adaptado (criar `ExpensesBackground` caso haja ajustes de cor).
   - Introduzir um cabeçalho em cartão translúcido (`GlassBackgroundStyle`) contendo título e subtítulo da tela para reforçar a identidade visual.
   - Revisitar o uso de `.animation` para evitar travamentos e seguir a experiência suave do módulo de Devedores.

2. **Cabeçalho com métricas e filtros avançados**
   - Criar `ExpensesSummaryCard`, reutilizando `MetricCard` para exibir: soma das despesas ativas, salário do mês, saldo restante e percentual de cobertura.
   - Adicionar campo de busca (`DebtorsSearchField` pode servir de referência) e picker segmentado para alternar entre despesas ativas/arquivadas (`FixedExpense.active`).
   - Incluir menu de ordenação (por valor, vencimento, nome) e filtro por categoria com chips dinâmicos calculados a partir das despesas.

3. **Cartões de despesa com novas ações**
   - Substituir `ExpenseRow` por `ExpenseCard`: layout em cartão com ícone do vencimento, chip de categoria/cor, indicador quando a data atual já passou do `dueDay` e rótulo “Arquivada” quando `active == false`.
   - Implementar ações contextuais: editar (abrir o mesmo formulário preenchido), duplicar e arquivar/restaurar via `swipeActions`. Remover permanece disponível.
   - Transformar o toque no cartão em navegação/folha com detalhes adicionais (histórico de alterações, notas e botão de duplicar), mantendo consistência com outros fluxos do app.

4. **Evoluir o ViewModel e o domínio**
   - Estender `ExpensesViewModel` com estado derivado: `@Published searchText`, `selectedStatus`, `selectedCategory`, `sortOrder`, `filteredExpenses`, `metrics` (struct consolidada).
   - Implementar métodos `toggleArchive(_:)`, `duplicate(_:)`, `updateExpense(_:with:)` e calcular automaticamente `dueDateDescriptor` (data real do próximo vencimento a partir do `dueDay`).
   - Persistir notas opcionais em `FixedExpense` (novo campo `note`) para suportar descrição adicional no cartão e formulário, criando migração SwiftData correspondente.
   - Expor histórico resumido de `SalarySnapshot` (últimos meses) para alimentar gráficos/listas auxiliares.

5. **Refinar formulários e fluxos auxiliares**
   - Atualizar `ExpenseForm` para suportar modo de edição (identificar registro e preencher campos), permitir seleção rápida de categorias sugeridas e capturar nota.
   - Ajustar `SalaryForm` para mostrar mês atual por padrão, permitir comentário opcional (`SalarySnapshot.note`) e incentivar atualização a partir da tela principal via botões de atalho no cabeçalho.
   - Introduzir folha/modal “Resumo do mês” com gráfico simples (barra ou donut) mostrando distribuição por categoria, aproveitando os dados já agregados no ViewModel.

6. **Localização, acessibilidade e feedback**
   - Registrar novas chaves de texto em `Money/Core/Localization/pt-BR.lproj/Localizable.strings` e `en.lproj/Localizable.strings`, seguindo a convenção existente (`expenses.*`).
   - Garantir contrastes e labels de acessibilidade nos novos cartões, chips e botões (VoiceOver descrevendo categoria, vencimento e status).
   - Aplicar haptics leves nas ações de arquivar/duplicar para reforçar feedback.

7. **Qualidade e testes**
   - Criar testes de unidade para `ExpensesViewModel` cobrindo filtragem, ordenação, cálculo de métricas e alternância de status (usar container em memória como nas suites existentes).
   - Adicionar cenário em `MoneyUITests` verificando busca, filtro por categoria e swipe para arquivar/restaurar.
   - Atualizar/gerar previews (`#Preview`) para os novos componentes e validar layout em temas claro/escuro.
   - Rodar `xcodebuild -scheme Money -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' clean build` e `xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15'` antes da entrega.

## Considerações
- Avaliar impacto da migração SwiftData para introduzir `note` em `FixedExpense` e possíveis dados legados; seguir padrão de migrações do projeto.
- Reaproveitar componentes existentes (ex.: `MetricCard`, `DebtorsSearchField`) para manter consistência e reduzir código duplicado.
- Monitorar performance: listas aninhadas/gráficos devem usar `LazyVStack` e evitar recomputações caras no corpo da view (preferir valores pré-calculados no ViewModel).
