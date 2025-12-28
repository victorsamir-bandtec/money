# Swift 6 Style Guide (2025/2026 Edition)

Este guia define os padrões de codificação para o projeto **Money (iOS)**, alinhado com as práticas modernas de Swift 6, SwiftUI e SwiftData.

## 1. Concorrência e Threading (Strict Concurrency)

O Swift 6 impõe verificação rigorosa de concorrência. Todo código novo deve ser *thread-safe* por design.

- **Async/Await:** Use `async/await` para todo código assíncrono. Evite `completion handlers` e `DispatchQueue` (exceto para interoperabilidade legada).
- **MainActor:** Anote todas as classes de `ViewModel` e `View` com `@MainActor` para garantir que as atualizações de UI ocorram na thread principal.
  ```swift
  @MainActor
  class DashboardViewModel: Observable { ... }
  ```
- **Sendable:** Garanta que dados passados entre contextos de concorrência conformem com `Sendable`. Prefira `structs` imutáveis para modelos de transferência de dados (DTOs).
- **Task Management:** Use `.task` modifier em SwiftUI para iniciar trabalhos assíncronos ligados ao ciclo de vida da view. Evite `Task { }` soltos dentro de métodos síncronos, a menos que seja uma ação de usuário explícita (ex: botão).

## 2. SwiftUI e Arquitetura UI

- **Framework de Observabilidade:** Use o macro `@Observable` para ViewModels e modelos de estado, abandonando o antigo protocolo `ObservableObject` e `@Published`.
  ```swift
  @Observable
  class UserSettings {
      var isDarkModeEnabled: Bool = false
  }
  ```
- **Injeção de Dependência:** Use `@Environment` para injetar serviços e dependências globais na hierarquia de views.
- **Estrutura de Views:**
  - Quebre Views complexas em sub-views menores e reutilizáveis.
  - Coloque lógica de apresentação complexa em `computed properties` ou métodos auxiliares, mas mantenha a lógica de negócio no ViewModel.
- **Modificadores:** Use a ordem padrão de modificadores (Conteúdo -> Layout -> Aparência).

## 3. SwiftData e Persistência

- **Modelagem:** Use classes anotadas com `@Model`. Mantenha os modelos focados em dados; evite lógica de negócio complexa diretamente neles.
- **Queries:** Use `@Query` dentro de Views para buscas simples e ordenadas. Para filtragens complexas ou operações em massa, delegue para um `Service` ou `ViewModel`.
- **Contexto:** Nunca force o `modelContext` em threads de fundo manualmente sem usar um `ModelActor` ou padrão seguro equivalente.

## 4. Nomenclatura e Formatação

- **Padrão Apple:** Siga rigorosamente as [API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).
- **Clareza > Brevidade:** Nomes devem ser descritivos. `fetchDebtor(id:)` é melhor que `get(id:)`.
- **Prefixos:** Não use prefixos em tipos (ex: nada de `kConstant` ou `MyView`).
- **Opcionais:** Evite *force unwrap* (`!`) a todo custo. Use `if let`, `guard let` ou coalescência (`??`).

## 5. Organização de Arquivos

- **Feature-Based:** Agrupe arquivos por funcionalidade (ex: `Debtors/List`, `Debtors/Detail`), não por tipo de arquivo.
- **Extensões:** Mantenha extensões em arquivos separados se crescerem muito, nomeados como `Tipo+Funcionalidade.swift`.

## 6. Testes

- **Swift Testing:** Prefira o novo framework `Testing` (`@Test`) para novos testes unitários.
- **Mocks:** Use protocolos para abstrair serviços e criar mocks testáveis.
