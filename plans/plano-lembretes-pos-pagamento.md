# Plano: Ajustar agendamento de lembretes após pagamento/manual

## Contexto
- `DebtorDetailViewModel.mark` e `AgreementDetailViewModel.markAsPaidFull/registerPayment` reagem agendando lembretes novamente, mesmo quando a parcela está quitada.
- `LocalNotificationScheduler.trigger(for:)` pode gerar triggers no passado (quando `dueDate` já passou), causando solicitações inúteis.

## Objetivo
Evitar notificações para parcelas pagas e impedir agendamento de triggers expirados, mantendo lembretes apenas para parcelas pendentes.

## Passos de Implementação
1. **Criar helper para agendamento**
   - Em `NotificationScheduling`, adicionar método default (extensão) `syncReminders(for installment: Installment)` que decide entre agendar/cancelar.
2. **Lógica do helper**
   - Se `installment.status == .paid` ou `remainingAmount == 0`, chamar `cancelReminders(for: installment.agreement.id)` ou remover identificadores específicos.
   - Se status pendente/parcial: verificar `dueDate >= Date()` antes de agendar; caso contrário, não reagendar.
3. **Atualizar ViewModels**
   - Substituir chamadas diretas a `scheduleReminder`/`Task { try? await ... }` pelo helper.
4. **Evitar triggers no passado**
   - Modificar `LocalNotificationScheduler.trigger(for:)` para retornar `nil` quando `target < Date()`.
5. **Testes**
   - Criar testes unitários simulando parcela paga parcial/completa e verificar se `scheduleReminder` não é invocado (usar mock `NotificationScheduling`).

## Riscos e Mitigações
- **Cancelamento amplo**: avaliar se `cancelReminders` remove demais; caso necessário, cancelar apenas identificadores específicos (due/warn) para o número da parcela.

## Validação
- Teste manual: marcar parcela como paga e garantir ausência de notificações futuras no painel de notificações do iOS (via Xcode). Rodar suíte de testes.
