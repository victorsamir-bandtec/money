# Plano - Notificacoes: parcelas vencidas com saldo restante

Este plano segue `conductor/workflow.md` (testes -> implementacao -> validacao).

## [x] 1) Especificar comportamento em testes
- Expandir `MoneyTests/Services/NotificationSchedulerTests.swift`:
  - Notificacao inclui saldo restante no `content.body`.
  - Para parcela vencida com saldo: criar trigger recorrente semanal (repeats = true) e identificador dedicado.
- Adicionar testes (unit) para selecao da "proxima parcela em aberto" por acordo:
  - Preferir a parcela vencida mais antiga quando houver.
  - Caso contrario, preferir a parcela futura mais proxima.

## [x] 2) Atualizar localizacao
- Atualizar `Money/Core/Localization/pt-BR.lproj/Localizable.strings` e `en.lproj/Localizable.strings`:
  - Novo titulo/corpo para parcela vencida.
  - Atualizar template do corpo para aceitar (numero da parcela, saldo restante).

## [x] 3) Implementar scheduler
- Atualizar `InstallmentReminderPayload` para carregar informacoes necessarias ao texto (ex.: saldo restante formatado).
- Implementar agendamento para parcela vencida com repeticao semanal (09:00) e identificadores estaveis.
- Manter comportamento atual para parcela futura (due + warn), com antecedencia de 2 dias.
- Garantir cancelamento correto quando parcela ficar quitada.

## [x] 4) Implementar selecao de parcela por acordo
- Atualizar a logica de sincronizacao (ViewModels) para:
  - Cancelar lembretes do acordo.
  - Selecionar apenas 1 parcela alvo (vencida mais antiga ou futura mais proxima).
  - Agendar lembretes apenas para ela.
- Remover duplicacao entre ViewModels (se fizer sentido) criando helper compartilhado.

## [x] 5) Validacao
- Rodar SwiftFormat.
- Rodar `xcodebuild test`.
- Validacao manual rapida:
  - Criar acordo com parcela vencida e registrar pagamento parcial; verificar que permanece agendada notificacao recorrente.
  - Quitar a parcela; verificar cancelamento.
