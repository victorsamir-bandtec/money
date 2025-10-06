# Plano: Unificar apresentação de erros (`LocalizedErrorWrapper`)

## Contexto
- Estrutura `LocalizedErrorWrapper` duplicada em várias cenas (`DebtorsScene`, `DebtorDetailScene`, `AgreementDetailScene`, `SettingsScene`).
- Difícil manter consistência em mensagens e estilo de alertas.

## Objetivo
Criar um tipo único reutilizável para exibição de `AppError` em alerts SwiftUI.

## Passos de Implementação
1. **Criar tipo compartilhado**
   - Adicionar `Support/AppErrorAlertItem.swift` contendo `struct AppErrorAlertItem: Identifiable` com init a partir de `AppError` e propriedade `message`.
2. **Extensões auxiliares**
   - Fornecer `extension View` com helper `func alert(item: Binding<AppError?>, ...)` ou `Binding<AppErrorAlertItem?>` para reduzir boilerplate.
3. **Refatorar cenas**
   - Substituir structs locais por `AppErrorAlertItem` em:
     - `Money/Presentation/Debtors/DebtorsScene.swift`
     - `Money/Presentation/Debtors/DebtorDetailScene.swift`
     - `Money/Presentation/Debtors/AgreementDetailScene.swift`
     - `Money/Presentation/Settings/SettingsScene.swift`
   - Garantir que binding limpa o erro (`viewModel.error = nil`) ao fechar o alerta.
4. **Atualizar testes/compilação**
   - Verificar que previews e testes compilam sem os tipos locais.

## Riscos e Mitigações
- **Importações cruzadas**: Manter o tipo no módulo principal (`Money`) para evitar dependências em testes.

## Validação
- Build do app e teste manual rápido em cada tela garantindo que alertas continuam funcionando.
