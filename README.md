# Money (iOS)

Money é um aplicativo SwiftUI (Swift 6) que ajuda a acompanhar devedores, acordos parcelados, pagamentos, despesas fixas e salário. O projeto segue arquitetura MVVM, usa SwiftData para persistência local e prepara sincronização via iCloud através dos _feature flags_, entregando visual "Liquid Glass" do iOS 26 com degradê controlado para iOS 17+.

## Requisitos
- Xcode 16 beta ou superior com SDK iOS 26 (fallback automático para iOS 17+).
- SwiftFormat instalado (`brew install swiftformat`) para padronização de código.

## Como rodar
1. Abra `Money.xcodeproj` no Xcode.
2. Selecione o esquema `Money` e um simulador iOS 17+.
3. Rode `Product > Run` ou, via linha de comando, execute:
   ```sh
   xcodebuild -scheme Money -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' clean test
   ```
4. A primeira execução populará dados de exemplo (devedor “Marlon”) caso o banco esteja vazio. Essa ação também pode ser disparada manualmente na aba Ajustes.

## Estrutura de pastas
- `Money/App` – ambiente global, erros, _feature flags_.
- `Money/Core` – modelos SwiftData, serviços (cálculos financeiros, exportação CSV, notificações, formatação).
- `Money/Presentation` – telas organizadas em features (Dashboard, Devedores, Despesas, Ajustes) com seus ViewModels.
- `MoneyWidgets` – widget de resumo mensal.
- `MoneyTests`, `MoneyUITests` – testes unitários e de interface com XCTest/Swift Testing.

## Funcionalidades-chave
- **Dashboard** com métricas do mês, próximos vencimentos e alertas.
- **Gestão de devedores** com acordos, geração automática de parcelas e agendamento de lembretes locais.
- **Despesas fixas e salário** com cálculo de saldo mensal.
- **Exportação CSV** seguindo especificação (`devedores.csv`, `acordos.csv`, `parcelas.csv`, `pagamentos.csv`, `despesas.csv`).
- **Widgets**, **App Shortcuts (Siri/Spotlight)** e suporte inicial a notificações locais.
- **Localização** pronta em pt-BR (padrão) e en-US.

## Configuração de iCloud
O app expõe o _feature flag_ `Sincronizar com iCloud` em Ajustes. Ao habilitar, a lógica de sincronização deve ser conectada a um container CloudKit; para testes, habilite iCloud Documents no Signing & Capabilities e ajuste o identificador conforme necessário.

## Estilo de código
- Indentação de 4 espaços, nomes `UpperCamelCase` para tipos e `lowerCamelCase` para valores.
- Valores monetários usam `Decimal` e arredondamento com duas casas.
- Execute `swiftformat .` antes de abrir PRs.

## Testes
- Plano unitário: `xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15'`.
- O diretório `MoneyTests` cobre regras financeiras e utilitários; `MoneyUITests` valida fluxo crítico de cadastro de devedor.
- Ajuste (ou crie) planos `.xctestplan` conforme necessário para CI (`UnitOnly`, `UnitAndUI`).

## Acessibilidade e design
- Componentes utilizam materiais translúcidos com fallback automático para `.regularMaterial`/`.ultraThinMaterial`.
- Elementos críticos têm etiquetas de acessibilidade e suportam dinamic type.

## Roadmap breve
- Implementar sincronização real com CloudKit quando o flag for ativado.
- Completar automação de notificações para cenários de pagamentos parciais.
- Adicionar testes de widgets e intents assim que alvos dedicados forem configurados no projeto.
