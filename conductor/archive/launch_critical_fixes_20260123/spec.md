# Track Spec: Launch Critical Fixes

## Contexto
Uma auditoria de pré-lançamento identificou três áreas de risco crítico no aplicativo Money: estabilidade dos modelos (crashes), integridade de cálculos financeiros (juros altos) e performance da UI (dashboard lags).

## Objetivos
1.  **Estabilidade:** Eliminar crashes fatais (`precondition`) substituindo por inicializadores falíveis (`init?`).
2.  **Precisão:** Padronizar o tratamento de juros como "Porcentagem" em todo o sistema, corrigindo a lógica ambígua para taxas > 100%.
3.  **Performance:** Otimizar o `DashboardViewModel` para reduzir recargas redundantes e queries pesadas em memória.

## Mudanças Necessárias

### 1. Core Models (Estabilidade)
-   **Arquivos:** `FinanceModels.swift`
-   **Ação:** Substituir `precondition` por `guard` retornando `nil` em:
    -   `Debtor`, `DebtAgreement`, `Installment`, `Payment`, `CashTransaction`, `FixedExpense`.
-   **Impacto:** ViewModels devem tratar `nil` ao instanciar modelos, evitando crashes em produção.

### 2. Lógica de Juros (Precisão)
-   **Arquivos:** `FinanceCalculator.swift`, `DebtService.swift`
-   **Ação:**
    -   `FinanceCalculator`: Remover verificação `if rate > 1`. Assumir que o parâmetro `monthlyInterest` é SEMPRE uma porcentagem (ex: 1.5 para 1.5%) e dividir por 100 internamente.
    -   `DebtService`: Ajustar para passar o valor cru (percentual) para a calculadora, sem pré-dividir, garantindo fonte única de verdade.

### 3. Dashboard (Performance)
-   **Arquivos:** `DashboardViewModel.swift`
-   **Ação:**
    -   Dividir `load()` em `loadSummary()` e `loadDetailedList()`.
    -   Observadores (`financialDataDidChange`) devem acionar apenas as partes necessárias.
    -   Otimizar Predicates para filtrar em banco, não em memória (especialmente `variableExpenses` e `upcoming`).

## Critérios de Aceite
-   [ ] Tentativa de criar Entidade com valor inválido retorna `nil` (sem crash).
-   [ ] Juros de 150% são calculados corretamente (dívida aumenta 1.5x, não 0.015x).
-   [ ] Dashboard carrega instantaneamente e não trava a UI ao registrar pagamentos.
