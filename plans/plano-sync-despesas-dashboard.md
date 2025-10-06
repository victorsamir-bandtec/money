# Plano: Sincronizar Dashboard após alterações de despesas fixas

## Contexto
- `ExpensesViewModel.persistChanges` (Money/Presentation/Expenses/ExpensesViewModel.swift:106-115) salva, recarrega dados locais, mas não emite `Notification.Name.financialDataDidChange`.
- Dashboard e outras telas dependentes ficam desatualizados até que o usuário force refresh.

## Objetivo
Emitir notificações consistentes sempre que uma despesa é criada, editada, duplicada, arquivada ou removida, garantindo atualização imediata do dashboard e demais consumidores.

## Passos de Implementação
1. **Criar helper de notificação**
   - Adicionar função `notifyFinancialChange()` em `ExpensesViewModel` ou reutilizar extensão em `ModelContextNotifications.swift` se desejado.
2. **Atualizar `persistChanges`**
   - Após `try context.save()`, emitir `NotificationCenter.default.post(name: .financialDataDidChange, object: nil)`.
   - Em caso de sucesso, considerar também `paymentDataDidChange` se métricas dependem de parcelas (avaliar necessidade; provavelmente não).
3. **Cobrir pontos de entrada**
   - Garantir que `addExpense`, `updateExpense`, `duplicate`, `toggleArchive`, `removeExpense` utilizam `persistChanges` (já fazem) e portanto herdam nova notificação.
4. **Atualizar testes**
   - Criar `ExpensesViewModelNotificationTests` em `MoneyTests` verificando, com `NotificationCenter` de teste, que ao chamar `addExpense` a notificação é postada.

## Riscos e Mitigações
- **Postagens redundantes**: caso `load()` também poste, garantir que não haja loops (dashboard só reage a eventos). Validar que `ExpensesViewModel.load` não depende da notificação para evitar cascata.

## Validação
- Rodar testes automáticos.
- Passo manual: abrir app, alterar despesa e confirmar atualização imediata do card "Despesas fixas" no dashboard sem refresh manual.
