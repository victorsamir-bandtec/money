# Plano: Atualizar status `closed` de acordos e sincronizar notificações

## Contexto
- `DebtAgreement.closed` nunca é atualizado após pagamentos (Money/Core/Models/FinanceModels.swift:33-68).
- Fluxos de pagamento (`DebtorDetailViewModel.mark`, `AgreementDetailViewModel.registerPayment`, etc.) não ajustam `closed`, nem cancelam lembretes.
- UI exibe acordos sempre como “abertos” e notificações continuam sendo agendadas após quitação.

## Objetivo
Manter `DebtAgreement.closed` coerente com o estado das parcelas, cancelar lembretes quando o acordo é quitado e reabrir se algum pagamento é revertido.

## Passos de Implementação
1. **Criar função utilitária**
   - Em `DebtAgreement` (extensão) adicionar método `updateClosedStatus()` que verifica `installments.allSatisfy { $0.status == .paid }`.
2. **Integrar nos fluxos de pagamento**
   - `DebtorDetailViewModel.mark(installment:as:)` (Money/Presentation/Debtors/DebtorDetailViewModel.swift:155-187).
   - `AgreementDetailViewModel.registerPayment`, `updateInstallmentStatus`, `markAsPaidFull`, `undoLastPayment` (Money/Presentation/Debtors/AgreementDetailViewModel.swift:63-193).
   - Após manipular parcelas, chamar `agreement.updateClosedStatus()` e persistir.
3. **Cancelar/reativar lembretes**
   - Se `agreement.closed == true`, chamar `notificationScheduler.cancelReminders(for:)` (já existe em `NotificationScheduling`).
   - Caso reabra (`closed` passa a `false`), reagendar lembretes apenas para parcelas pendentes futuras.
4. **Notificar interessados**
   - Emitir `NotificationCenter.default.post(name: .agreementDataDidChange, object: nil)` e `financialDataDidChange` após alteração de status.
5. **Ajustar UI**
   - Confirmar que badges “Encerrado/Aberto” em `DebtorDetailScene` e `AgreementDetailScene` exibem estado correto.
6. **Testes**
   - Adicionar testes em `MoneyTests` criando acordo com parcelas pagas para validar `closed` e cancelamento.
   - Testar `undoLastPayment` para reabrir acordo.

## Riscos e Mitigações
- **Condicionais concorrentes**: múltiplas chamadas assincronas podem emitir notificações duplicadas; mitigar usando `Task` principais (já `@MainActor`).
- **Performance**: iterar em `installments` (quantidade pequena). Aceitável.

## Validação
- Rodar testes unitários atualizados.
- Cenário manual: quitar todas as parcelas em `AgreementDetailScene` e verificar badge “Encerrado” + ausência de lembretes futuros.
