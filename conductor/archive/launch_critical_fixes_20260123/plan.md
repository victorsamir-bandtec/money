# Implementation Plan - Launch Critical Fixes

## Phase 1: Core Model Hardening (Stability)
Objetivo: Prevenir crashes substituindo preconditions por inicializadores falíveis.

- [x] Task: Criar Testes de Estabilidade (Crash Safety)
    - Escrever testes em `MoneyTests/ModelTests.swift` tentando instanciar modelos com valores inválidos (negativos, strings vazias).
    - Validar que atualmente eles crasham (ou falham) e o objetivo é retornarem nil.
    - 💡 Skill: `ios-quality-engineer`

- [x] Task: Refatorar Inicializadores dos Modelos
    - Alterar `init` para `init?` em `Debtor`, `DebtAgreement`, `Installment`, `Payment`, `CashTransaction`.
    - Substituir `precondition` por `guard` checks.
    - 💡 Skill: `ios-architect`

- [x] Task: Atualizar Consumidores dos Modelos (Services & VMs)
    - Ajustar `DebtService`, `DebtorDetailViewModel` e outros pontos de criação para tratar o retorno opcional (`if let` ou `guard let`).
    - Garantir tratamento de erro apropriado na UI se a criação falhar.
    - 💡 Skill: `ios-architect`

- [x] Task: Conductor - Verificação Manual do Usuário 'Core Model Hardening' (Protocolo em workflow.md)

## Phase 2: Interest Logic Standardization (Precision)
Objetivo: Corrigir cálculo de juros para taxas altas e remover ambiguidade.

- [x] Task: Testes de Cálculo de Juros (High Rates)
    - Adicionar casos de teste em `FinanceCalculatorTests` para taxas > 100% (ex: 150%).
    - Verificar resultado esperado (juros massivos vs juros irrisórios).
    - 💡 Skill: `ios-quality-engineer`

- [x] Task: Refatorar FinanceCalculator e DebtService
    - `FinanceCalculator`: Remover lógica `rate > 1`. Assumir entrada sempre como porcentagem e dividir por 100.
    - `DebtService`: Passar valor bruto do draft para a calculadora.
    - 💡 Skill: `ios-architect`

- [x] Task: Conductor - Verificação Manual do Usuário 'Interest Logic Standardization' (Protocolo em workflow.md)

## Phase 3: Dashboard Optimization (Performance)
Objetivo: Melhorar responsividade e reduzir recargas.

- [x] Task: Refatorar DashboardViewModel
    - Separar `load()` em `loadSummary` (leve) e `loadInstallments` (pesado).
    - Implementar verificação de `Set<UUID>` ou similar para evitar recarregar listas se os IDs não mudaram (opcional, foco na separação de loads primeiro).
    - Otimizar Predicates para `FetchDescriptor` de despesas variáveis.
    - 💡 Skill: `ios-ui-crafter`

- [x] Task: Verificação de Performance
    - Rodar profile básico ou teste manual para garantir que navegar e registrar pagamento não trava a UI.
    - 💡 Skill: `ios-quality-engineer`

- [x] Task: Conductor - Verificação Manual do Usuário 'Dashboard Optimization' (Protocolo em workflow.md)
