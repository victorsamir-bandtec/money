# 🚀 Novas Funcionalidades Estratégicas - Money App

## 📋 Índice de Planos

Este documento conecta os 3 planos detalhados de funcionalidades estratégicas para elevar o Money de uma ferramenta operacional para uma plataforma de inteligência financeira.

---

## 🎯 Visão Geral da Estratégia

### Objetivo Principal
Transformar o Money em uma plataforma de **decisões financeiras inteligentes**, não apenas um registro passivo de transações.

### Cobertura das Funcionalidades

| Funcionalidade | Problema que Resolve | Arquivo do Plano | Impacto |
|----------------|---------------------|------------------|---------|
| **Score de Crédito de Devedores** | Decisões de crédito baseadas em intuição | `plano-score-credito-devedores.md` | ⭐⭐⭐⭐⭐ |
| **Dashboard Preditivo** | Falta de planejamento de médio/longo prazo | `plano-dashboard-preditivo-projecao.md` | ⭐⭐⭐⭐⭐ |
| **Orçamento Inteligente** | Gastos sem controle por categoria | `plano-orcamento-inteligente-categorias.md` | ⭐⭐⭐⭐ |

---

## 📊 Arquitetura Integrada

### Fluxo de Dados

```
┌─────────────────────────────────────────────────────────────────┐
│                     SwiftData (Core/Models)                      │
├─────────────────────────────────────────────────────────────────┤
│  Debtor → DebtAgreement → Installment → Payment                 │
│  FixedExpense → CashTransaction → SalarySnapshot                │
│                                                                  │
│  NOVOS MODELOS:                                                  │
│  ├─ DebtorCreditProfile (Score)                                 │
│  ├─ MonthlySnapshot (Histórico)                                 │
│  ├─ CashFlowProjection (Projeções)                              │
│  ├─ CategoryBudget (Orçamentos)                                 │
│  └─ CategorySpending (Gastos por Categoria)                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   Serviços (Core/Services)                       │
├─────────────────────────────────────────────────────────────────┤
│  EXISTENTES:                                                     │
│  ├─ CurrencyFormatter                                            │
│  ├─ FinanceCalculator                                            │
│  ├─ NotificationScheduler                                        │
│  └─ CSVExporter                                                  │
│                                                                  │
│  NOVOS:                                                          │
│  ├─ CreditScoreCalculator (Score 0-100)                         │
│  ├─ HistoricalAggregator (Snapshots mensais)                    │
│  ├─ CashFlowProjector (Projeções futuras)                       │
│  └─ BudgetAnalyzer (Análise de orçamentos)                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              ViewModels (Presentation/*/ViewModel)               │
├─────────────────────────────────────────────────────────────────┤
│  EXISTENTES:                                                     │
│  ├─ DashboardViewModel                                           │
│  ├─ DebtorsListViewModel                                         │
│  └─ ExpensesViewModel                                            │
│                                                                  │
│  NOVOS:                                                          │
│  ├─ DebtorCreditProfileViewModel                                │
│  ├─ HistoricalAnalysisViewModel                                 │
│  ├─ ProjectionViewModel                                          │
│  └─ BudgetViewModel                                              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              Views/Scenes (Presentation/*/Scene)                 │
├─────────────────────────────────────────────────────────────────┤
│  EXISTENTES:                                                     │
│  ├─ DashboardScene                                               │
│  ├─ DebtorsListScene                                             │
│  ├─ DebtorDetailScene                                            │
│  └─ ExpensesScene                                                │
│                                                                  │
│  NOVOS:                                                          │
│  ├─ CreditProfileDetailView                                      │
│  ├─ HistoricalAnalysisScene (nova tab)                          │
│  ├─ ProjectionScene                                              │
│  └─ BudgetScene (nova tab)                                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│         Componentes Reutilizáveis (Presentation/Shared)          │
├─────────────────────────────────────────────────────────────────┤
│  EXISTENTES (REUTILIZADOS):                                      │
│  ├─ MetricCard                                                   │
│  ├─ MoneyCard / MoneyCardStyle                                   │
│  ├─ FilterChip                                                   │
│  ├─ AppEmptyState                                                │
│  ├─ AppBackground                                                │
│  └─ CurrencyField                                                │
│                                                                  │
│  NOVOS:                                                          │
│  ├─ CreditScoreBadge                                             │
│  ├─ TrendChart (Swift Charts)                                    │
│  ├─ CategoryProgressBar                                          │
│  └─ ScenarioCard                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔗 Integração Entre Funcionalidades

### 1️⃣ Score de Crédito ↔️ Dashboard Preditivo

**Conexão:** Score influencia projeções de recebimentos

```swift
// No CashFlowProjector:
func adjustProjectionByRisk(
    debtor: Debtor,
    projection: Decimal
) -> Decimal {
    guard let profile = debtor.creditProfile else { return projection }

    // Devedor de alto risco: reduzir projeção em 30%
    if profile.riskLevel == .high {
        return projection * 0.7
    }

    return projection
}
```

**Resultado:** Projeções mais realistas considerando risco de inadimplência

---

### 2️⃣ Dashboard Preditivo ↔️ Orçamento Inteligente

**Conexão:** Histórico alimenta sugestões de orçamento

```swift
// No BudgetAnalyzer:
func suggestBudgets(context: ModelContext) throws -> [ExpenseCategory: Decimal] {
    // Buscar snapshots históricos dos últimos 3 meses
    let snapshots = try HistoricalAggregator().fetchSnapshots(...)

    // Agrupar por categoria e calcular média
    let averages = calculateAveragesByCategory(snapshots)

    // Adicionar 10% de margem
    return averages.mapValues { $0 * 1.1 }
}
```

**Resultado:** Sugestões automáticas baseadas em comportamento real

---

### 3️⃣ Score de Crédito ↔️ Orçamento Inteligente

**Conexão:** Receita de juros aparece como categoria "Financeiro"

```swift
// No DashboardViewModel:
func calculateInterestIncome() -> Decimal {
    let profiles = try context.fetch(FetchDescriptor<DebtorCreditProfile>())
    return profiles.reduce(.zero) { $0 + $1.totalInterestEarned }
}
```

**Resultado:** Usuário vê quanto ganha com juros como "receita financeira"

---

## 📅 Roadmap de Implementação Sugerido

### Opção 1: Implementação Sequencial (Recomendado)
**Vantagem:** Permite validar cada funcionalidade antes de prosseguir

1. **Mês 1:** Score de Crédito de Devedores
   - Impacto imediato no negócio principal (cobrança)
   - Base para melhorar projeções futuras

2. **Mês 2:** Orçamento Inteligente com Categorias
   - Estrutura categorias para análises futuras
   - Impacto rápido no controle de gastos

3. **Mês 3:** Dashboard Preditivo
   - Usa dados de categorias já estruturadas
   - Usa score para ajustar projeções
   - Funcionalidade mais complexa por último

### Opção 2: Implementação em Paralelo (Mais Rápido)
**Vantagem:** Lança todas funcionalidades juntas em 6-8 semanas

- **Time 1:** Score de Crédito (Dev Senior)
- **Time 2:** Orçamento Inteligente (Dev Pleno)
- **Time 3:** Dashboard Preditivo (Dev Senior)

---

## 🎨 Princípios de Design Mantidos

### Consistência Visual
✅ Todos os planos reutilizam componentes existentes:
- `MetricCard` para métricas resumidas
- `MoneyCard` para cards padronizados
- `FilterChip` para seleção de filtros
- `AppEmptyState` para estados vazios

### Zero Duplicação de Código
✅ Serviços compartilhados:
- `CurrencyFormatter` para formatação monetária
- `FinanceCalculator` para cálculos financeiros
- `NotificationScheduler` para alertas

### Arquitetura MVVM Consistente
✅ Todos seguem o mesmo padrão:
```
Scene → ViewModel → Service → Models (SwiftData)
```

---

## 📊 Métricas de Sucesso Consolidadas

### Adoção (Primeiros 3 Meses)
| Funcionalidade | Meta de Adoção |
|----------------|----------------|
| Score de Crédito | 80%+ visualizam perfis |
| Dashboard Preditivo | 70%+ acessam análise histórica |
| Orçamento Inteligente | 85%+ definem orçamentos |

### Impacto no Negócio (6 Meses)
| Métrica | Meta |
|---------|------|
| Redução de Inadimplência | -30% |
| Redução de Gastos Não Essenciais | -20% |
| Aumento de Receita de Juros | +15% (cobrar juros adequados) |
| Tempo Economizado em Gestão | 5h/mês por usuário |

### Satisfação do Usuário
| Funcionalidade | NPS Alvo |
|----------------|----------|
| Score de Crédito | > 8 |
| Dashboard Preditivo | > 8 |
| Orçamento Inteligente | > 8 |

---

## 🛠️ Recursos Técnicos Necessários

### Novas Dependências
- **Swift Charts** (iOS 16+) para gráficos nativos
  - Fallback: gráficos customizados com SwiftUI
- Nenhuma biblioteca externa necessária! ✅

### Performance
| Operação | Tempo Máximo |
|----------|-------------|
| Cálculo de Score | < 500ms |
| Agregação de Histórico | < 1s |
| Geração de Projeções (12 meses) | < 2s |
| Análise de Orçamentos | < 300ms |

### Armazenamento
| Modelo | Tamanho Estimado (1000 registros) |
|--------|-----------------------------------|
| DebtorCreditProfile | ~500KB |
| MonthlySnapshot | ~1MB |
| CashFlowProjection | ~200KB |
| CategoryBudget | ~50KB |

**Total adicional:** ~2MB para usuário típico (12 meses de dados)

---

## ✅ Checklist de Preparação

Antes de iniciar a implementação:

- [ ] Aprovação do roadmap de implementação (sequencial vs paralelo)
- [ ] Definição de prioridade entre as 3 funcionalidades
- [ ] Alocação de recursos (desenvolvedores, designers)
- [ ] Validação de requisitos com stakeholders
- [ ] Setup de ambiente de testes com dados mockados
- [ ] Criação de protótipos de interface (Figma/Sketch)
- [ ] Definição de KPIs e métrica de sucesso
- [ ] Planejamento de comunicação com usuários (changelog, tour)

---

## 📚 Próximos Passos

1. **Revisar os 3 planos detalhados:**
   - `plano-score-credito-devedores.md`
   - `plano-dashboard-preditivo-projecao.md`
   - `plano-orcamento-inteligente-categorias.md`

2. **Escolher ordem de implementação:**
   - Recomendo: Score → Orçamento → Dashboard
   - Alternativa: Todas em paralelo (se tiver time)

3. **Criar branch de feature:**
   ```bash
   git checkout -b feature/score-credito
   git checkout -b feature/dashboard-preditivo
   git checkout -b feature/orcamento-inteligente
   ```

4. **Seguir ordem de implementação de cada plano:**
   - Cada plano tem seção "Ordem de Implementação" detalhada
   - Começar sempre por modelos → serviços → ViewModels → Views

5. **Executar testes continuamente:**
   ```bash
   xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15'
   ```

---

## 🤝 Contribuindo

Ao implementar essas funcionalidades:

1. Siga o guia de estilo em `CLAUDE.md`
2. Execute `swiftformat .` antes de cada commit
3. Mantenha cobertura de testes > 80%
4. Atualize localização (pt-BR e en-US)
5. Teste em light/dark mode
6. Valide acessibilidade (VoiceOver, Dynamic Type)

---

## 📞 Suporte

Para dúvidas sobre os planos:
1. Leia o plano detalhado específico
2. Verifique código de exemplo incluído
3. Consulte arquitetura existente em `CLAUDE.md`

---

**Última atualização:** 2025-10-11
**Versão:** 1.0.0
**Autor:** Claude Code (Anthropic)
