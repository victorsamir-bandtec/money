# Plano: Propagar notificações após criação de acordo

## Contexto
- `DebtorDetailViewModel.createAgreement` (Money/Presentation/Debtors/DebtorDetailViewModel.swift:103-152) salva dados e recarrega apenas a tela atual.
- Dashboard, lista de devedores e outras telas não recebem aviso e permanecem desatualizadas até troca de aba ou refresh manual.

## Objetivo
Emitir notificações padronizadas após criar um acordo e suas parcelas, garantindo sincronia imediata em todo o app.

## Passos de Implementação
1. **Definir pontos de notificação**
   - Após `try context.save()`, postar `NotificationCenter.default.post(name: .agreementDataDidChange, object: nil)`.
   - Postar também `.paymentDataDidChange` (parcelas criadas) e `.financialDataDidChange` (impacto no dashboard).
2. **Evitar duplicidade**
   - Verificar se outros fluxos similares (ex.: update) também precisam dos mesmos posts e unificar em helper privado para reuso.
3. **Atualizar testes**
   - Criar teste unitário no estilo `DebtorDetailViewModelTests` verificando emissão das notificações via `NotificationCenter` com expectation.

## Riscos e Mitigações
- **Eventos consecutivos**: Vários posts podem disparar recarregamentos múltiplos; se necessário, avaliar `NotificationQueue.default.enqueue` com coalescência ou agregar nomes.

## Validação
- Teste manual: criar acordo e confirmar que dashboard e lista de devedores atualizam sem refresh.
- Rodar `xcodebuild test` após inclusão dos novos testes.
