# Guia de Desenvolvimento

## Pré-requisitos
- Xcode 15.4+ (ou iOS 17 SDK) com suporte ao SwiftData.
- Simulador recomendado: iPhone 15 (iOS 17 ou superior).
- Conta Apple configurada caso precise testar notificações locais ou widgets.

## Comandos úteis
```bash
# Abrir o projeto no Xcode
open Money.xcodeproj

# Build automatizado
xcodebuild -scheme Money -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' clean build

# Executar toda a suíte de testes
xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Estilo de código
- Seguir Swift API Design Guidelines.
- Indentação de quatro espaços; trailing comma em coleções multilinha.
- Nomear tipos com `UpperCamelCase` e propriedades/funções com `lowerCamelCase`.
- View models ficam em arquivos separados dentro da mesma pasta da cena (`Scene` + `ViewModel`).
- Helpers específicos de uma view podem estar em extensões no mesmo arquivo; utilitários reutilizáveis devem ir para `Support/` ou `Core/Services`.

## Fluxo para implementar uma feature
1. **Modelagem**: defina ou ajuste modelos em `Core/Models` se houver mudança de dados persistentes.
2. **Serviços**: encapsule lógica de negócio em `Core/Services` ou crie um novo serviço.
3. **ViewModel**: exponha estado derivado (`@Published`) e comandos. Utilize `CurrencyFormatter` para exibir valores monetários.
4. **Scene/View**: monte a interface em `Presentation/<Feature>` usando componentes compartilhados quando possível.
5. **Testes**: adicione testes unitários para os view models e UI tests para fluxos com navegação.
6. **Documentação**: atualize estes arquivos em `docs/` se a estrutura ou decisões importantes mudarem.

## Boas práticas
- Utilize SwiftUI previews para validar rapidamente componentes (`⌥+Cmd+P`).
- Evite chamar `Task {}` desnecessários dentro de views; prefira `.task` ou `@MainActor` no view model.
- Para debug de SwiftData, habilite `com.apple.CoreData.SQLDebug 1` nas launch arguments do esquema de Debug.
- Notificações locais exigem permissão do usuário; use o fallback em `SettingsViewModel` para orientar o usuário quando o acesso for negado.

## Tests & QA
- Siga o naming `test_whenCondition_expectOutcome`.
- Adicione fixtures em `MoneyTests/Resources` (crie a pasta se necessário) para dados de CSV ou JSON.
- Para UI tests, utilize `XCUIApplication().launchArguments += ["--uitesting"]` para limpar o banco antes de cada cenário.

## Git e PRs
- Commits com formato `type: descrição curta` (`feat: adicionar filtro na lista de devedores`).
- Inclua no corpo do PR: resumo da mudança, evidência de testes (`xcodebuild test`), capturas de tela para mudanças visuais.
- Aguarde aprovação e CI verde antes de mergear.

Mantenha este guia atualizado com novos fluxos de build, scripts ou convenções adotadas pela equipe.
