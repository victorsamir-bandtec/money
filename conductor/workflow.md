# Money - Workflow

Este documento define o fluxo de desenvolvimento recomendado para manter qualidade, previsibilidade e velocidade.

## Principios
- Qualidade primeiro: preferir pequenas mudancas, verificaveis e com boa cobertura.
- Local-first e confiabilidade: dados consistentes e calculos corretos valem mais que features novas.
- TDD quando fizer sentido: principalmente em Services, regras financeiras e ViewModels.
- UI fina: Views com pouca logica; ViewModels e Services concentram regras.

## Regras gerais
- Cobertura recomendada: 80% para logica de negocio (Services/ViewModels) e utilitarios.
- Commits atomicos por tarefa (ou por sub-tarefa quando o escopo ficar grande).
- Padrao de commit do repo: `type: short summary` (ex.: `fix: correct overdue calculation`).
- Nao introduzir force unwrap (`!`) e evitar estado global.

## Ciclo por tarefa (Track-driven)
1. Definir objetivo e criterio de aceite (spec/plan da track do Conductor).
2. Preparar terreno:
   - Criar/atualizar fixtures e dados de exemplo (quando necessario).
   - Garantir identificadores de acessibilidade em fluxos que vao para UI test.
3. Testes primeiro (quando aplicavel):
   - Preferir Swift Testing (`import Testing`) para novos testes.
   - Usar XCTest lado a lado apenas quando fizer sentido (migracao incremental).
   - Para SwiftData: usar `ModelConfiguration(isStoredInMemoryOnly: true)` nos testes.
   - Para Swift Testing: usar nomes descritivos e, quando util, tags/traits para organizar e rodar em CI.
4. Implementar o minimo para passar.
5. Refatorar: remover duplicacao, melhorar nomes, reduzir complexidade, manter testes verdes.
6. Rodar formatacao:
   - `swiftformat Money/ MoneyTests/ MoneyUITests/ --config .swiftformat`
7. Rodar testes:
   - Suite completa: `xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15'`
   - Foco (quando aplicavel): usar `-only-testing:` para acelerar iteracoes.
8. Verificacao manual rapida (quando houver UI):
   - Checar Dynamic Type (tamanho grande), navegacao basica e estados vazios/erro.
9. Atualizar documentacao quando necessario (README, docs/, Conductor).
10. Commit e abrir PR quando for o caso.

## Estrategia de testes
- Services: testes deterministicos (sem depender de tempo, locale global ou estado do dispositivo).
- ViewModels: testar estado publicado e orquestracao; mockar Services quando necessario.
- SwiftUI: preferir logica em ViewModel; validar fluxo com UI tests e acessibilidade.
- UI tests: usar `--uitesting` para resetar estado e tornar execucoes idempotentes.

## Concorrencia e Swift 6 strict
- Tipos de UI devem ser `@MainActor` (Views/ViewModels).
- Preferir `Sendable` em DTOs/value types.
- Evitar capturas nao-`Sendable` em tarefas concorrentes; manter boundaries claros.

## Definition of Done
- Testes relevantes passam localmente.
- Codigo formatado (SwiftFormat) e sem warnings novos relevantes.
- Sem regressao em fluxos principais; UI validada quando aplicavel.
- Acessibilidade basica preservada (labels + Dynamic Type).
