# Auditoria de Funcionalidades — Money (2025-10-06)

A revisão concentrou-se nas jornadas essenciais do aplicativo (controle de devedores, acordos/parcela, fluxo de caixa mensal e ajustes). Abaixo estão os principais pontos que precisam de correção ou evolução para alinhar o produto ao objetivo de "saber quanto ainda falta receber/pagar e quanto ainda posso gastar".

## 1. Métricas e alertas do dashboard não consideram parcelas realmente vencidas
**Problema**  
`fetchSummary` e `fetchUpcoming` filtram apenas parcelas com vencimento dentro do mês corrente ou dos próximos 14 dias (`Money/Presentation/Dashboard/DashboardViewModel.swift:70`, `Money/Presentation/Dashboard/DashboardViewModel.swift:125`). Com isso:
- valores vencidos em meses anteriores somem das métricas `overdue`/`alerts`;
- `alerts` nunca inclui atrasados detectados automaticamente (o filtro exige `dueDate >= date`).

**Solução proposta**  
- Criar duas consultas: uma para parcelas vencidas (`dueDate < currentDate && status != .paid`) e outra para próximas (`currentDate...+14 dias`), populando `alerts` com a união ordenada;
- Ajustar `monthIncome` para separar "previsto no mês" de "atrasado acumulado" para leitura mais clara.

**Benefícios esperados**  
Dashboard passa a refletir corretamente quanto está atrasado, eliminando a necessidade de o usuário vasculhar acordos manualmente e permitindo ação imediata.

## 2. Dashboard não atualiza após editar despesas
**Problema**  
`ExpensesViewModel.persistChanges` salva/recupera dados mas não emite `financialDataDidChange` (`Money/Presentation/Expenses/ExpensesViewModel.swift:106`). Assim, o dashboard mantém totais desatualizados até que o usuário puxe refresh manualmente.

**Solução proposta**  
Após `try context.save()` chamar `NotificationCenter.default.post(name: .financialDataDidChange, object: nil)` (mesmo ponto para duplicar, arquivar, remover). Considere centralizar o post em um helper para manter consistência.

**Benefícios esperados**  
O saldo do mês e o comparativo salário x despesas passam a refletir cada alteração imediatamente, evitando decisões com base em números incorretos.

## 3. Acordos nunca chegam ao estado "Encerrado" e continuam gerando lembretes
**Problema**  
`DebtAgreement.closed` é sempre `false` (não há atualização após pagamentos) e as rotinas de pagamento agendam lembretes de qualquer forma (`Money/Presentation/Debtors/AgreementDetailViewModel.swift:63`, `Money/Presentation/Debtors/DebtorDetailViewModel.swift:155`, `Money/Core/Services/NotificationScheduler.swift:34`). Resultado: acordos exibidos como "abertos" mesmo quitados, e notificações disparando para parcelas liquidadas.

**Solução proposta**  
- Após registrar/atualizar/ desfazer pagamento, verificar `agreement.installments.allSatisfy { $0.status == .paid }`; setar `agreement.closed` e cancelar lembretes via `cancelReminders`;
- Reabrir (`closed = false`) se alguma parcela voltar a `pending/partial/overdue`;
- Disparar `agreementDataDidChange` para sincronizar outras telas.

**Benefícios esperados**  
Estado do acordo fica confiável, elimina notificações indevidas e permite novas automações (ex.: relatório de devedores ativos).

## 4. Preferência "Receber lembretes" não é persistida
**Problema**  
`FeatureFlags.enableNotifications` vive apenas em memória (`Money/App/AppEnvironment.swift:6`, `Money/App/FeatureFlags.swift:3`). Ao reiniciar o app, o toggle volta para `true`, contrariando a escolha do usuário (`Money/Presentation/Settings/SettingsViewModel.swift:31`).

**Solução proposta**  
Persistir os flags em `UserDefaults`/`AppStorage` ou criar `FeatureFlagsStore` com carregamento/salvamento automático no `AppEnvironment`. Atualizar o toggle para refletir o valor persistido.

**Benefícios esperados**  
Respeita a configuração do usuário, reduzindo frustração e evitando possíveis violações de LGPD por envio de alerta sem consentimento.

## 5. Lembretes continuam agendados mesmo após quitação manual
**Problema**  
Quando o usuário marca uma parcela como paga diretamente (`mark`, `markAsPaidFull`), o código agenda novamente notificações com a mesma data (`Money/Presentation/Debtors/DebtorDetailViewModel.swift:168`, `Money/Presentation/Debtors/AgreementDetailViewModel.swift:123`). Além disso, `trigger(for:)` pode gerar requests com datas passadas, desperdiçando cotas de notificação.

**Solução proposta**  
- Não reagendar se `status == .paid` e usar `cancelReminders` para remover lembretes pendentes;
- Ignorar agendamento se `dueDate` + deslocamento já for `< Date()`;
- Extrair lógica de agendamento para um helper que receba o novo status e decida entre agendar/cancelar.

**Benefícios esperados**  
Evita spam de notificações após acordos quitados e garante que lembretes futuros sejam sempre relevantes.

## 6. Criação de acordo não avisa o resto do app
**Problema**  
Após `createAgreement` o fluxo apenas recarrega a tela corrente (`Money/Presentation/Debtors/DebtorDetailViewModel.swift:103`); nenhum `financialDataDidChange`/`agreementDataDidChange` é emitido. Dashboard e lista de devedores ficam desatualizados até o usuário trocar de aba ou aplicar refresh manual.

**Solução proposta**  
Emitir `NotificationCenter` logo após o `context.save()` e, se necessário, notificar `paymentDataDidChange` (para dashboards que dependem das parcelas associadas).

**Benefícios esperados**  
Experiência consistente: ao criar um acordo, os totais e próximos vencimentos aparecem imediatamente nas demais telas.

## 7. Indicador de saldo não responde à pergunta "quanto ainda posso gastar"
**Problema**  
`DashboardSummary.netBalance` hoje é `salary + received - fixedExpenses` (`Money/Presentation/Dashboard/DashboardViewModel.swift:12`). A fórmula ignora:
- valores ainda a receber (parcelas futuras e atrasadas);
- despesas variáveis/realizadas;
- impacto dos pagamentos já feitos no mês (usa receita bruta, não saldo).

**Solução proposta**  
- Expandir o resumo para incluir "previsto a receber", "valor atrasado" e "saldo realmente disponível" (considerando salário, despesas ativas, pagamentos já feitos e próximos vencimentos);
- Exibir cartões separados para "Recebido x Previsto" e "Disponível para gastar" com base nesses cálculos.

**Benefícios esperados**  
Usuário passa a enxergar claramente o dinheiro comprometido vs. disponível, atendendo o propósito principal do app.

## 8. Falta registrar despesas variáveis / gastos reais do mês
**Problema**  
O domínio só modela `FixedExpense` (`Money/Core/Models/FinanceModels.swift:103`), ou seja, compromissos recorrentes. Não existe forma de lançar compras pontuais, recebimentos extras ou pagamentos feitos (além dos devedores). Isso limita a visão real de caixa.

**Solução proposta**  
- Introduzir um modelo `CashTransaction` (data, categoria, tipo gasto/receita, valor, nota);
- Criar tela simples de lançamentos rápidos e integrar com o dashboard para calcular saldo diário/mensal;
- Permitir filtrar despesas/incomes por categoria para planejamento.

**Benefícios esperados**  
Entrega valor direto ao objetivo do app (controle financeiro completo), permitindo saber com precisão quanto já foi gasto no mês e quanto resta.

## 9. Tratamento de erros duplicado em várias telas
**Problema**  
A struct `LocalizedErrorWrapper` foi copiada em múltiplos lugares (`Money/Presentation/Debtors/DebtorsScene.swift:431`, `Money/Presentation/Debtors/DebtorDetailScene.swift:235`, `Money/Presentation/Debtors/AgreementDetailScene.swift:640`, `Money/Presentation/Settings/SettingsScene.swift:240`). Manter mensagens e estilo em sincronia fica custoso.

**Solução proposta**  
Extrair para um tipo único em `Support/` (ex.: `struct AppErrorAlertItem`) com init a partir de `AppError` e reaproveitar nas telas via `Alert.init(item:)`.

**Benefícios esperados**  
Menos código duplicado, fácil padronização visual e menor risco de divergência de UX em novos fluxos.

---

### Próximos passos sugeridos
1. Priorizar correções críticas de dados (itens 1–6) e validar com testes funcionais/UI já existentes.
2. Em seguida, evoluir métricas do dashboard (itens 7 e 8) para alinhar o produto ao objetivo de controle financeiro completo.
3. Finalizar com as melhorias de manutenção (item 9) e ajustes de UX/resultados (ex.: mensagens e notificações).

Todos os pontos acima já incluem um caminho de implementação. Recomenda-se criar tarefas separadas por tema para facilitar code review e cobertura de testes.
