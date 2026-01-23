# Relatório de Auditoria: Lógica de Negócio e Arquitetura

**Data:** 22/01/2026
**Status:** Análise Completa

## 1. Auditoria de Modelos (SwiftData)

### Pontos Fortes
- Definições de `@Model` estão corretas e seguem o padrão SwiftData.
- Regras de deleção (`cascade`) bem configuradas para evitar orfãos.
- Uso de `precondition` garante integridade básica dos dados.

### Falhas Identificadas
- **Risco de Crash:** Preconditions em `init` (ex: `Debtor`, `FixedExpense`) podem causar crashes em produção se dados corrompidos forem carregados ou migrados, pois o app aborta imediatamente.
- **Relacionamentos Inversos:** `DebtAgreement` possui `debtor`, mas a inferência do relacionamento inverso pode ser frágil sem anotação explícita em casos complexos.
- **Lógica em Modelos:** `Installment.isOverdue` depende de `Calendar.current` e `Date.now`, tornando o modelo não-determinístico e difícil de testar de forma isolada (depende do horário do sistema).

## 2. Lógica Financeira (`FinanceCalculator`, `CurrencyFormatter`)

### Falhas Críticas
- **Erro de Precisão (Tabela Price):** Em `FinanceCalculator.priceSchedule`, a lógica de amortização fixa o valor da parcela (`paymentValue`) arredondado e ajusta o saldo.
    - **Problema:** O loop não garante que o saldo final seja zero na última parcela. Acumula resíduos de arredondamento, podendo gerar uma última parcela inconsistente ou saldo residual "escondido" pelo `clamped(to: .zero...)`.
    - **Correção Necessária:** Ajustar a última parcela para absorver a diferença residual ou usar cálculo de precisão maior antes de arredondar.
- **Performance de Formatação:** `CurrencyFormatter` recria `NumberFormatter` a cada inicialização. Como é usado frequentemente em loops de UI (listas), isso causa impacto severo na performance de rolagem.

### Falhas Menores
- **Cálculo de Atraso:** O cálculo de dias de atraso (`daysLate`) em vários lugares usa `Calendar.current` e não considera fusos horários consistentemente, podendo gerar "falsos atrasos" dependendo da hora do dia.

## 3. Arquitetura e MVVM

### Inconsistências
- **ViewModels "Gordas":** ViewModels como `DebtorDetailViewModel` e `DashboardViewModel` contêm lógica de negócio pesada (geração de parcelas, queries complexas, cálculos de agregação).
    - **Violação:** Isso fere o princípio de separação de responsabilidades. A criação de um acordo e suas parcelas deveria estar em um `DebtService`.
- **Efeitos Colaterais em Leitura:** `DebtorDetailViewModel.load()` executa `updateClosedStatus()` e salva o contexto. Operações de leitura não deveriam mutar dados persistentemente sem ação explícita do usuário.
- **Duplicação de Código:** O padrão de salvamento (`saveWithCallbacks`) e lógica de filtragem/ordenação é repetido em múltiplos ViewModels.

## 4. Recomendações Prioritárias

1.  **Refatorar `FinanceCalculator`:** Corrigir a matemática da Tabela Price para garantir saldo zero.
2.  **Otimizar `CurrencyFormatter`:** Implementar cache ou singleton para o `NumberFormatter`.
3.  **Extrair Services:** Mover lógica de criação de empréstimo (`DebtorDetailViewModel`) e agregação (`DashboardViewModel`) para `DebtService` e `DashboardService`.
4.  **Remover `precondition`:** Substituir por tratamento de erro (`throw`) ou valores default seguros em inicializadores de modelos.
