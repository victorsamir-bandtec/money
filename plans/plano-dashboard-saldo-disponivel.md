# Plano: Recalibrar métricas do dashboard para saldo disponível

## Contexto
- `DashboardSummary.netBalance = salary + received - fixedExpenses` (Money/Presentation/Dashboard/DashboardViewModel.swift:12).
- Fórmula ignora valores previstos/atrasados e despesas variáveis, dificultando responder “quanto ainda posso gastar”.

## Objetivo
Apresentar no dashboard indicadores claros de:
1. `Previsto a receber` (parcelas futuras)
2. `Recebido no mês`
3. `Atrasado`
4. `Despesas fixas` (atuais)
5. `Saldo disponível` = `(salário + recebido + previsto curto prazo) - (despesas fixas + atrasos + gastos variáveis)`

## Passos de Implementação
1. **Estender `DashboardSummary`**
   - Adicionar campos `planned`, `remainingToReceive`, `availableToSpend`.
   - Atualizar `init` e `static empty`.
2. **Atualizar `fetchSummary`**
   - Calcular `planned` como soma das parcelas com `dueDate` restante no mês (status não pago).
   - Calcular `overdue` separado (já tratado no Plano de atrasos) e utilizar na fórmula do saldo.
   - Recalcular `availableToSpend` considerando entradas/saídas disponíveis (incluir futura integração com gastos variáveis, ver Plano de transações variáveis).
3. **Atualizar `DashboardScene`**
   - Ajustar cartões (ex.: usar `MetricCard` adicional para `availableToSpend` com copy “Quanto ainda posso gastar”).
   - Revisar texto e acessibilidade.
4. **Integração com gastos variáveis**
   - Inicialmente, usar zero até que o novo modelo (Plano de transações variáveis) esteja pronto; deixar ponto de integração comentado.
5. **Testes**
   - Adicionar `DashboardSummaryTests` validando a fórmula com cenários de parcelas pagas, pendentes e atrasadas.

## Riscos e Mitigações
- **Complexidade UX**: Discussão com produto sobre copy exata dos cards; preparar protótipo simples.
- **Dependência do Plano 8**: Resultado final dependerá de registrar gastos variáveis; implementar fallback (0) para evitar bloqueio.

## Validação
- Testes unitários e revisão visual em preview do SwiftUI.
- Fluxo manual: registrar salário, despesas fixas, parcelas com diferentes status e conferir saldo exibido.
