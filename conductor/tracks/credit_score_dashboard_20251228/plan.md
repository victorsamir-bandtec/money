# Plan: Sistema de Score de Confiança e Dashboards Preditivos

## Phase 1: Core Logic & Tests (Score Calculator)
Foco na implementação do algoritmo de cálculo de score, garantindo robustez matemática e testes unitários.

- [ ] Task: Definir interfaces e estruturas de dados para o Score.
    - Criar `struct CreditScore` e definir enumerações para faixas de risco (High, Medium, Low).
- [ ] Task: Implementar algoritmo base de cálculo (TDD).
    - **Write Tests:** Criar `CreditScoreCalculatorTests.swift` cobrindo cenários: pagamento pontual, atraso leve, atraso grave, sem histórico.
    - **Implement Feature:** Criar `Core/Services/CreditScoreCalculator.swift` implementando a lógica.
- [ ] Task: Integrar cálculo ao modelo `Debtor` (Extension).
    - Criar propriedade computada ou método assíncrono em `Debtor` que utiliza o serviço para retornar o score atual.
- [ ] Task: Conductor - User Manual Verification 'Core Logic & Tests' (Protocol in workflow.md)

## Phase 2: UI Integration (Debtor Profile)
Exibir o score calculado na interface do usuário de forma discreta e elegante.

- [ ] Task: Criar componente visual de Score.
    - **Write Tests:** Testes de Snapshot (se aplicável) ou validação de ViewModels para o componente `CreditScoreBadge`.
    - **Implement Feature:** Criar `Presentation/Components/CreditScoreBadge.swift` usando design Liquid Glass.
- [ ] Task: Atualizar `DebtorDetailViewModel`.
    - Adicionar lógica para buscar e expor o score formatado para a View.
- [ ] Task: Integrar na `DebtorDetailScene`.
    - Adicionar o badge de score ao cabeçalho do perfil do devedor.
- [ ] Task: Conductor - User Manual Verification 'UI Integration' (Protocol in workflow.md)

## Phase 3: Dashboard Projections (Data & Charts)
Implementar a lógica de projeção financeira e a visualização gráfica no Dashboard.

- [ ] Task: Criar serviço de projeção de fluxo de caixa.
    - **Write Tests:** Criar `CashFlowProjectorTests.swift` validando a soma de parcelas por mês futuro.
    - **Implement Feature:** Criar `Core/Services/CashFlowProjector.swift` que agrega parcelas futuras por mês.
- [ ] Task: Criar componente de Gráfico de Projeção.
    - Utilizar Swift Charts (nativo do iOS 16+) para criar um gráfico de barras moderno.
    - Implementar `Presentation/Components/ProjectionChart.swift`.
- [ ] Task: Atualizar `DashboardViewModel`.
    - Integrar o `CashFlowProjector` para fornecer dados ao gráfico.
- [ ] Task: Integrar no `DashboardScene`.
    - Adicionar o gráfico de projeção em uma nova seção "Fluxo Futuro" no Dashboard.
- [ ] Task: Conductor - User Manual Verification 'Dashboard Projections' (Protocol in workflow.md)

## Phase 4: Refinement & Polish
Ajustes finais, animações e garantia de performance.

- [ ] Task: Adicionar animações de entrada para o gráfico e o badge de score.
- [ ] Task: Otimizar performance (garantir que cálculos pesados rodem em background).
- [ ] Task: Revisão final de Acessibilidade (VoiceOver para o gráfico e score).
- [ ] Task: Conductor - User Manual Verification 'Refinement & Polish' (Protocol in workflow.md)
