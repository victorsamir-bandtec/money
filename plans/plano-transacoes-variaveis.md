# Plano: Introduzir lançamentos de transações variáveis

## Contexto
- Modelo atual cobre apenas `FixedExpense`, mantendo foco em despesas recorrentes (Money/Core/Models/FinanceModels.swift:103-158).
- Usuário não consegue registrar gastos pontuais, receitas extras ou pagamentos avulsos.

## Objetivo
Adicionar suporte a lançamentos manuais (gastos e receitas) impactando o saldo mensal e oferecendo visão completa de caixa.

## Passos de Implementação
1. **Modelagem SwiftData**
   - Criar `@Model final class CashTransaction` com campos: `id`, `date`, `amount`, `type` (enum gasto/receita), `category`, `note`, `createdAt`.
   - Adicionar ao `Schema` em `AppEnvironment` e atualizar migração (se já em produção, criar migration SwiftData).
2. **Serviços auxiliares**
   - Atualizar `CSVExporter` para exportar `CashTransaction`.
   - Atualizar `SampleDataService` para criar algumas transações exemplo.
3. **ViewModel e UI**
   - Criar `TransactionsViewModel` (ou expandir `DashboardViewModel`) responsável por carregar transações do mês e calcular `variableSpending`/`variableIncome`.
   - decidir se fica numa aba existente (ex.: `ExpensesScene` adicionando seção "Transações do mês") ou nova aba "Lançamentos".
   - Fornecer `TransactionsScene` com lista agrupada por dia + botão "Adicionar transação".
4. **Integração com Dashboard**
   - `DashboardViewModel` passa a considerar `variableSpending` e `variableIncome` ao calcular o saldo disponível (ver Plano do dashboard).
   - Exibir card “Gastos do mês” com breakdown fixa x variável.
5. **Persistência e edição**
   - Implementar formulários para criar/editar/excluir transações (SwiftUI Form com `Stepper`, `Picker` de categoria, etc.).
   - Incluir filtros básicos (categoria, tipo).
6. **Notificações e testes**
   - Ao salvar, emitir `.financialDataDidChange`.
   - Escrever testes em `MoneyTests` validando filtros, soma mensal e integração com o dashboard.

## Riscos e Mitigações
- **Complexidade de UI**: começar com implementação básica (lista + formulário) e iterar.
- **Migração SwiftData**: se dados já persistidos, criar migration que adiciona nova entidade sem afetar existentes.

## Validação
- Testes unitários cobrindo cálculos.
- Teste manual: lançar gasto/receita e verificar impacto imediato na métrica “Saldo disponível”.
