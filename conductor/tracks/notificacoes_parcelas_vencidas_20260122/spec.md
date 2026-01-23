# Notificacoes: lembretes semanais para parcelas vencidas com saldo restante

## Contexto
O app ja agenda notificacoes locais para parcelas a vencer (vencimento e aviso antecipado). Hoje, parcelas vencidas (inclusive com pagamento parcial) deixam de ter lembretes ativos.

## Objetivo
Garantir que parcelas vencidas e ainda nao quitadas continuem sendo lembradas, com informacao clara do saldo restante, sem gerar excesso de notificacoes.

## User Stories
- Como usuario, quero receber lembretes semanais quando uma parcela estiver vencida e ainda tiver saldo restante, para nao esquecer de cobrar/receber.
- Como usuario, quero ver o valor restante na notificacao, para entender rapidamente o quanto falta.
- Como usuario, quero receber lembretes apenas da proxima parcela em aberto por acordo, para evitar notificacoes em excesso.

## Requisitos funcionais
- Para cada acordo, considerar apenas 1 parcela ativa para notificacoes (a "proxima parcela em aberto").
- A proxima parcela em aberto deve ser determinada por ordem de vencimento:
  - Se existir parcela vencida com `remainingAmount > 0`, escolher a mais antiga.
  - Caso contrario, escolher a parcela futura mais proxima com `remainingAmount > 0`.
- Para parcela futura (dueDate >= hoje):
  - Agendar notificacao de vencimento (09:00 do dia do vencimento).
  - Agendar notificacao de aviso antecipado com 2 dias de antecedencia (09:00), se a data nao estiver no passado.
- Para parcela vencida (dueDate < hoje) e ainda nao quitada:
  - Agendar notificacao recorrente semanal (09:00) ate a parcela ser quitada.
- Conteudo da notificacao:
  - Deve incluir o numero da parcela e o valor restante (formatado como moeda).
  - Deve manter pt-BR e en-US.
- Cancelamento/atualizacao:
  - Ao registrar pagamento parcial, atualizar lembretes para refletir o novo saldo restante.
  - Ao quitar a parcela (remainingAmount == 0 / status == .paid), cancelar lembretes.
  - Ao fechar ou remover o acordo, cancelar todos os lembretes associados.

## Fora de escopo
- Preferencias configuraveis de antecedencia/frequencia no app.
- Notificacoes push (backend) ou login.

## Criterios de aceite
- Em um acordo com varias parcelas, existe no maximo 2 notificacoes pendentes (warn+due) para a proxima parcela futura, ou 1 notificacao pendente (overdue) para a parcela vencida.
- Parcelas vencidas com saldo restante disparam lembrete semanal (trigger recorrente) ate quitacao.
- O corpo da notificacao inclui saldo restante.
- Testes automatizados cobrindo: selecao da parcela alvo, agendamento/cancelamento, e conteudo/identificadores.

## Notas tecnicas
- Atualizar a geracao de notificacoes em `Money/Core/Services/NotificationScheduler.swift`.
- Ajustar a estrategia de sincronizacao (hoje feita nos ViewModels) para agendar apenas 1 parcela por acordo.
- Adicionar/atualizar chaves de localizacao para corpo/titulo (incluindo caso de vencida).
