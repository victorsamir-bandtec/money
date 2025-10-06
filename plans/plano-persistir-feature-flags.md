# Plano: Persistir `FeatureFlags.enableNotifications`

## Contexto
- `FeatureFlags` é uma struct simples mantida in-memory (`Money/App/FeatureFlags.swift`).
- Ao reiniciar o app, o toggle de notificações em `SettingsScene` volta para `true`, ignorando escolha do usuário (`SettingsViewModel.toggleNotifications`).

## Objetivo
Persistir o valor de `enableNotifications` entre sessões e espelhar o valor persistido na UI.

## Passos de Implementação
1. **Definir armazenamento**
   - Criar `FeatureFlagsStore` em `Money/Support` usando `UserDefaults` (`AppStorage` é alternativa, mas preferir injeção manual para testes).
   - Expor métodos `load()` e `save(_:)`.
2. **Atualizar `AppEnvironment`**
   - Injetar `FeatureFlagsStore` (novo parâmetro opcional no init para facilitar testes).
   - Na inicialização, carregar `featureFlags = store.load()`.
   - Após instanciar `featureFlags`, continuar passando para componentes.
3. **Persistir alterações**
   - Em `SettingsViewModel.toggleNotifications`, além de atualizar `environment.featureFlags`, chamar `store.save(environment.featureFlags)` (store acessível via ambiente; avaliar expor através do `AppEnvironment`).
   - Garantir que `requestNotificationPermission` respeite o valor persistido.
4. **Atualizar testes**
   - Adicionar teste unitário que injeta store fake (memória) e verifica persistência no toggle.

## Riscos e Mitigações
- **Sincronização concorrente**: se mais de uma tela alterar flags simultaneamente (pouco provável); utilizar `@MainActor` ou `actor` em `FeatureFlagsStore`.
- **Migração**: valor anterior assume `true`; registrar no release notes.

## Validação
- Build de debug: alterar toggle, matar app, relançar e verificar que o estado foi mantido.
- Rodar testes unitários (`xcodebuild test`).
