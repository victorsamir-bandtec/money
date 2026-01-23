# Money - Tech Stack

## Plataforma
- iOS (minimo 17+), com visual iOS 26 quando disponivel.
- Xcode 16 beta+ (SDK iOS 26) para desenvolvimento; fallback para iOS 17+.

## Linguagem e runtime
- Swift 6 (modo strict de concorrencia).
- async/await como padrao para codigo assincrono.

## UI
- SwiftUI.
- Acessibilidade: Dynamic Type e VoiceOver como requisitos de qualidade.

## Persistencia
- SwiftData (ModelContainer/ModelContext).
- Modelos com `@Model` e relacoes via `@Relationship`.

## Arquitetura
- MVVM.
- Servicos em `Money/Core/Services` com ViewModels coordenando estado e fluxo.
- DI via `AppEnvironment`.

## Features de plataforma
- Widgets: WidgetKit.
- App Shortcuts: App Intents (Siri/Spotlight).
- Notificacoes locais: UserNotifications (UNUserNotificationCenter).

## Testes
- Unit tests: Swift Testing (preferencial) + XCTest.
- UI tests: XCUITest.

## Tooling
- Build/test via `xcodebuild`.
- Formatacao via SwiftFormat.
