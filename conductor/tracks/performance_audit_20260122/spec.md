# Especificação da Track: Otimização de Performance

## Contexto
O app apresenta gargalos de performance, especificamente "lags" na Dashboard e alto consumo de memória devido a fetchs excessivos (Eager Loading) no SwiftData.

## Objetivos
1. **Otimizar DashboardViewModel**: Refatorar `fetchUpcoming` para buscar `Installment` diretamente do banco (SQLite) usando `Predicate`, eliminando o carregamento de todos os `DebtAgreement` em memória.
2. **Otimizar Cálculos de Resumo**: Melhorar a performance de `fetchSummary` reduzindo alocações desnecessárias.
3. **Melhorar Células de Lista**: Otimizar propriedades computadas como `isOverdue` que instanciam `Calendar` repetidamente dentro de loops de renderização.

## Requisitos Técnicos
- **SwiftData**: Substituir lógica em memória por `FetchDescriptor` com `Predicate` otimizado.
- **ViewModel**: Remover loops aninhados na Main Thread.
- **Modelos**: Refatorar propriedades computadas pesadas para usar injeção de dependência ou valores pré-calculados.

## Critérios de Aceitação
- Navegação para Dashboard deve ser fluida (sem frames dropados).
- Unit Tests existentes devem passar sem alterações de lógica de negócio.
- O código deve estar compatível com Swift 6 Concurrency (MainActor).
