# Visão Geral da Estrutura

A seguir está um panorama das principais pastas e arquivos do projeto. Estruturas auxiliares, como derivados do Xcode (`DerivedData`) ou artefatos de build, não estão listadas.

```
Money/
├── App/
├── Assets.xcassets
├── Core/
├── MoneyApp.swift
├── Presentation/
├── Support/
├── MoneyTests/
├── MoneyUITests/
└── MoneyWidgets/
```

## Money/
Pasta raiz do aplicativo iOS. Cada subconjunto é organizado por responsabilidade.

### App/
- `AppEnvironment.swift`: ponto central para dependências compartilhadas (SwiftData container, formatadores, serviços).
- `AppError.swift`: define erros de domínio traduzíveis e facilita apresentação em alertas.
- `FeatureFlags.swift`: toggles de funcionalidades experimentais (ligadas via `UserDefaults`).

### Assets.xcassets
Recursos visuais (ícones, cores, imagens). Alterações aqui afetam todas as plataformas; mantenha nomes consistentes com os símbolos SF usados no código.

### MoneyApp.swift
Ponto de entrada (`@main`). Injeta o `AppEnvironment` como `environment` e configura o `modelContainer` do SwiftData para toda a árvore de views.

### Core/
Camada de domínio e serviços compartilhados.
- `Models/FinanceModels.swift`: modelos SwiftData (`Debtor`, `DebtAgreement`, `Installment`, `Payment`, `FixedExpense`, `SalarySnapshot`). Contém validações básicas e computed properties úteis (`remainingAmount`, `isOverdue`).
- `Services/CSVExporter.swift`: gera relatórios em CSV para exportação.
- `Services/CurrencyFormatter.swift`: encapsula `NumberFormatter` padronizado para BRL.
- `Services/FinanceCalculator.swift`: regras de negócio para cálculos de parcelas, saldo e juros.
- `Services/NotificationScheduler.swift`: agenda notificações locais com base nas datas de vencimento.
- `Services/SampleDataService.swift`: popula dados de exemplo na primeira execução.
- `Localization/`: strings localizadas (`pt-BR`, `en`). Mantenha chaves únicas e traduções sincronizadas.

### Presentation/
Camada de UI dividida por fluxo principal, seguindo MVVM (Scene + ViewModel).
- `Shared/RootView.swift`: TabView raiz com cenas de Resumo, Devedores, Despesas e Ajustes. Responsável por acionar o `SampleDataService` na inicialização.
- `Shared/MetricCard.swift`: componente de UI reutilizável com variação `prominent`.

#### Dashboard/
- `DashboardScene.swift`: implementa a tela "Resumo" com cards de métricas e lista de próximas parcelas.
- `DashboardViewModel.swift`: agrega dados financeiros e formata valores exibidos.

#### Debtors/
- `DebtorsScene.swift`: lista de devedores com busca e filtros.
- `DebtorsListViewModel.swift`: coordena leitura de devedores ativos/arquivados.
- `DebtorDetailScene.swift`: detalha um devedor e seus acordos.
- `DebtorDetailViewModel.swift`: operações sobre acordos, parcelas e status.

#### Expenses/
- `ExpensesScene.swift` & `ExpensesViewModel.swift`: gerenciamento de despesas fixas e snapshots de salário.

#### Settings/
- `SettingsScene.swift` & `SettingsViewModel.swift`: preferências do app, exportação, preenchimento com dados exemplo.

### Support/
Extensões e helpers de infraestrutura.
- `Bundle+Module.swift`: facilita acesso a recursos compartilhados entre targets.
- `Environment+Injection.swift`: fornece propriedade `appEnvironment` para injeção via `Environment`.
- `GlassBackgroundStyle.swift`: estilo de fundo usado em vários cards.
- `LocalizationHelpers.swift`: abstrações para carregar strings.
- `MoneyShortcuts.swift`: integrações com Siri/Atalhos.

### MoneyTests/
Pacote de testes unitários. Estruture arquivos por feature (ex.: `DashboardViewModelTests`). Atualmente contém `MoneyTests.swift` como placeholder; expanda aqui conforme novas lógicas de domínio sejam adicionadas.

### MoneyUITests/
Automação com XCUITest. `MoneyUITests.swift` abriga cenários de navegação, enquanto `MoneyUITestsLaunchTests.swift` valida o tempo de lançamento. Adicione arquivos separados por fluxo conforme o escopo crescer.

### MoneyWidgets/
Target de widgets do iOS.
- `MoneyWidget.swift`: configura `Widget` com `StaticConfiguration` e timeline.
- `MoneyWidgetEntry.swift`, `MoneyWidgetBundle.swift`: definem entradas de timeline e agrupamento de widgets.
- `PreviewContent/`: dados fake para SwiftUI previews (separado do app principal).

## Outras pastas relevantes
- `docs/`: esta documentação e guias adicionais.
- `build.log`, `test.log`: artefatos opcionais usados durante debugging local (não essenciais).

Mantenha esta visão geral atualizada sempre que novas camadas ou módulos forem introduzidos.
