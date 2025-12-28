# Technology Stack - Money (iOS)

## Core
- **Linguagem:** Swift 6
- **Plataforma Mínima:** iOS 26 (com fallback para iOS 17+)
- **IDE:** Xcode 16+

## Interface de Usuário (UI)
- **Framework:** SwiftUI
- **Estilo:** iOS 26 Native Liquid Glass (utilizando componentes e materiais do sistema)
- **Arquitetura de UI:** MVVM (Model-View-ViewModel)

## Dados e Persistência
- **Armazenamento Local:** SwiftData (Framework primário de persistência)
- **Sincronização:** CloudKit (via SwiftData, planejado)
- **Formatos de Intercâmbio:** CSV (para exportação/importação de dados)

## Testes e Qualidade
- **Testes Unitários:** XCTest & Swift Testing
- **Testes de Interface:** XCTest (UI Tests)
- **Linting/Formatação:** SwiftFormat

## Ferramentas de Build e CI
- **Gerenciador de Pacotes:** Swift Package Manager (SPM) - nativo do projeto Xcode
- **Scripts:** Shell scripts (para integração com Xcode)
