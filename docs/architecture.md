# Arquitetura e Fluxos

## Padrões principais
- **MVVM com SwiftUI**: Cada cena (`Scene`) possui um `ViewModel` que expõe estado derivado e comandos assíncronos. As views observam `@StateObject`/`@ObservedObject` e não acessam o SwiftData diretamente.
- **SwiftData como camada de persistência**: Os modelos em `Core/Models` são anotados com `@Model` e disponibilizados via `ModelContext`, injetado pelo `AppEnvironment`.
- **Injeção de dependências leve**: `AppEnvironment` concentra serviços reutilizáveis (formatadores, agendador de notificações, serviço de dados exemplo). Valores ficam acessíveis pela propriedade `Environment(\.appEnvironment)`.

```
MoneyApp → RootView → FeatureScene → FeatureViewModel → Serviços/Core
```

## Fluxo de inicialização
1. `MoneyApp` cria `AppEnvironment`, configurando o `ModelContainer` do SwiftData.
2. `RootView` recebe o ambiente via `Environment` e injeta o `modelContext` para as cenas.
3. `RootView` aciona `SampleDataService.populateIfNeeded()` para garantir dados mínimos em builds de preview/desenvolvimento.

## Comunicação com SwiftData
- Os `ViewModel`s usam `ModelContext` para `fetch`, `insert` e `delete`.
- Consultas são descritas com `FetchDescriptor` e `#Predicate`, garantindo tipagem forte.
- Atualizações de dados executam `try context.save()` (quando aplicável) e notificam a view via `@Published`.

## Serviços e utilitários
- `CurrencyFormatter`: centraliza formatação monetária. Evita repetição de configuração de `NumberFormatter` e torna fácil mudar o locale.
- `FinanceCalculator`: regras de negócio relacionadas a cálculo de parcelas, juros compostos e projeções.
- `NotificationScheduler`: encapsula APIs de `UNUserNotificationCenter`. `SettingsViewModel` usa para registrar descadastros.
- `CSVExporter`: produz relatórios para compartilhamento (utilizado a partir de Ajustes).

## Navegação e estados de UI
- Cada `Scene` é responsável pela sua navegação local (ex.: `NavigationStack` dentro de `DashboardScene` para cards detalhados futuramente).
- Diferentes tabs são isoladas dentro da `TabView` para evitar que um estado vaze para outra aba.
- Componentes compartilhados ficam em `Presentation/Shared` para manter consistência visual (ex.: `MetricCard`).

## Estilos e Temas
- `GlassBackgroundStyle` encapsula materiais translúcidos para manter visual consistente em dark/light mode.
- Cores específicas ficam nas assets; componentes preferem usar `Color` proveniente de assets ou variações do `tint`.

## Widgets
- O target `MoneyWidgets` compartilha modelos através de `Bundle+Module` e `SampleDataService` para gerar preview consistente.
- Widgets usam timeline estática hoje, mas a estrutura permite migrar para uma timeline baseada em `Intent`.

## Estratégia de testes
- **Unitários**: Focados em view models e serviços (`FinanceCalculator`, `DashboardViewModel`). Utilize `@MainActor` e `XCTExpectations` onde houver operações assíncronas.
- **UI Tests**: Validam fluxos principais (navegação entre abas, cadastro de devedor, registro de pagamento). Favor estruturar cenários por feature e utilizar `launchArguments` para limpar base antes de cada execução.

## Próximos passos sugeridos
- Documentar decisões arquiteturais relevantes no formato ADR quando mudanças significativas ocorrerem.
- Expandir cobertura de testes em `MoneyTests` e `MoneyUITests`, criando arquivos separados por módulo para manter clareza.
