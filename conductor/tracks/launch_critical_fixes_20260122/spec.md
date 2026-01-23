# Especificação da Track: Correções Críticas de Lançamento

## 1. Contexto
Análise de código revelou três falhas críticas que impedem um lançamento seguro: imprecisão em cálculos financeiros (uso de Double), lógica de vencimento agressiva e risco de corrupção de dados por schemas divergentes entre App e Widget.

## 2. Requisitos

### 2.1 Precisão Financeira
- **Problema:** `FinanceCalculator` converte `Decimal` para `Double` para cálculos de juros/amortização, causando erros de arredondamento.
- **Solução:** Refatorar `FinanceCalculator` para usar estritamente `Decimal`.
  - Usar `NSDecimalNumber` para operações de potência (`pow`) mantendo precisão.
  - Eliminar todas as conversões para `Double` nas fórmulas de PMT e Price.

### 2.2 Lógica de Vencimento
- **Problema:** Parcelas são marcadas como vencidas (`isOverdue`) no momento exato que `Date.now` ultrapassa `dueDate`, mesmo que seja no mesmo dia.
- **Solução:** Ajustar `Installment.isOverdue` para considerar o dia inteiro do vencimento como válido.
  - A parcela só deve ser considerada vencida se o dia atual for estritamente posterior ao dia do vencimento (D+1).

### 2.3 Integridade de Dados (SwiftData)
- **Problema:** `SharedContainer` define Schemas diferentes para App e Widget (Widget desconhece alguns modelos), mas ambos acessam o mesmo arquivo SQLite.
- **Solução:** Unificar a definição do `Schema`.
  - Criar uma definição única e compartilhada de todos os modelos persistidos.
  - Garantir que tanto App quanto Widget inicializem o `ModelContainer` com a lista completa de modelos.

## 3. Critérios de Aceite
- Testes unitários de amortização devem passar sem erros de arredondamento.
- Parcelas com vencimento "Hoje" devem aparecer como "Pendentes" ou "Hoje", nunca "Vencidas".
- O Widget deve carregar dados sem erros de CoreData/SwiftData ao ser executado simultaneamente com o App.
