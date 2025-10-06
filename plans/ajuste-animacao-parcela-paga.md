# Plano: Ajuste na animação de parcela paga

## Objetivo
Garantir que o cartão da parcela permaneça estável durante a transição para o estado pago, com animação suave e custo mínimo de layout, eliminando o "salto" percebido pelo usuário.

## Diagnóstico Atual
- `AgreementDetailScene` usa `List` com `.animation(UIAnim.listSnappy, value:)`, fazendo toda a lista reagir a mudanças de status (`AgreementDetailScene.swift:106-115`).
- Ao marcar como pago (`onMarkAsPaid`), há duas animações encadeadas: `withAnimation(UIAnim.primarySpring)` envolvendo `markAsPaidFull` e a animação implícita da `List`. A chamada a `viewModel.markAsPaidFull` recarrega toda a coleção via `load()` (`AgreementDetailViewModel.swift:59-99`), provocando realocação temporária de células.
- O overlay `CheckmarkAnimation` é disparado com outro `withAnimation` e utiliza `ZStack` com conteúdo maior que o card (`AgreementDetailScene.swift:457-525`). Isso força recalculagem de layout antes do `clipShape` agir.
- Resultado: o cartão “salta” para cima enquanto a `List` atualiza, congela até o fetch terminar e só então volta ao lugar.

## Plano de Ação Detalhado

1. **Eliminar recarregamentos completos desnecessários**
   - Ajustar `AgreementDetailViewModel.markAsPaidFull` e `undoLastPayment` para actualizar `installments` em memória sem chamar `load()` quando já temos referência direta ao modelo.
   - Garantir consistência disparando `objectWillChange` manualmente ou atualizando a coleção com `withObservationTracking` após `context.save()`.
   - Revisar notificações (`NotificationCenter.default.post`) para confirmar que continuam necessárias.

2. **Controlar animações da lista**
   - Remover `.animation(..., value:)` da `List` ou restringi-la a um `Transaction` customizado apenas para inclusões/remoções, evitando aplicar animação global em simples updates de estado.
   - Aplicar animação explícita apenas no `InstallmentCard` usando `transaction` local (`transaction { $0.animation = UIAnim.primarySpring }`).

3. **Reescrever fluxo de animação do cartão**
   - Criar um pequeno state machine (`enum PaymentAnimationPhase { case idle, triggering, completed }`) dentro de `InstallmentCard` para orquestrar checkmark + highlight.
   - Substituir o `DispatchQueue.main.asyncAfter` por `TimelineView`/`PhaseAnimator` ou `Task.sleep` async, garantindo ciclo determinístico e cancelável.
   - Atualizar `CheckmarkAnimation` para respeitar limites do cartão: usar `matchedGeometryEffect` ou simplesmente reduzir o frame e aplicar `allowsHitTesting(false)`.

4. **Adicionar feedback visual coerente**
   - Introduzir transição suave na cor de fundo/borda do cartão usando `transition(.opacity.combined(with: .scale))` ou `keyframeAnimator` para dar sensação de confirmação sem deslocar o layout.
   - Sincronizar highlight com o estado `showCheckAnimation`, garantindo que o conteúdo principal não re-renderize sem necessidade.

5. **Validar performance e UX**
   - Usar os previews existentes (`AgreementDetailScene` ou criar preview dedicado) para observar a transição após as alterações.
   - Rodar `xcodebuild -scheme Money -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' clean build` e `xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15'` para garantir que não houve regressões.
   - Fazer revisão visual em dispositivo/simulador para confirmar ausência de saltos e travamentos.

## Considerações
- As alterações precisam preservar acessibilidade do gesto de swipe; revisar `allowsFullSwipe` após refactor para evitar regressão.
- Testar cenários de parcela parcialmente paga e desmarcar pagamento (`onUndo`) para garantir consistência da animação.
- Manter `UIAnim` centralizado, ajustando ou adicionando constantes se necessário para novos keyframes.
