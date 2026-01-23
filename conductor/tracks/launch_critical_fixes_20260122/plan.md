# Plano de Implementação

## Fase 1: Precisão Financeira (Decimal Migration)
- [x] Criar teste unitário em `FinanceCalculatorTests` que falhe com `Double` (ex: simulação de 60 meses com juros compostos) 💡 Skill: code-refactor-master
- [x] Refatorar `FinanceCalculator` substituindo `Double` por `Decimal` e `NSDecimalNumber` 💡 Skill: code-refactor-master
- [x] Verificar se testes de precisão passam
- [x] Tarefa: Conductor - Verificação Manual do Usuário 'Precisão Financeira' (Protocolo em workflow.md)

## Fase 2: Lógica de Vencimento
- [x] Criar teste unitário em `InstallmentTests` para o cenário "Vencimento Hoje" (deve ser false para `isOverdue`) 💡 Skill: code-refactor-master
- [x] Atualizar lógica `isOverdue` em `Installment.swift` usando `Calendar` para comparar dias 💡 Skill: code-refactor-master
- [x] Verificar testes de vencimento
- [x] Tarefa: Conductor - Verificação Manual do Usuário 'Lógica de Vencimento' (Protocolo em workflow.md)

## Fase 3: Integridade de Dados (SwiftData)
- [x] Analisar `SharedContainer.swift` e listar todos os modelos do App vs Widget 💡 Skill: component-architect
- [x] Unificar lista de Schemas em uma variável estática compartilhada (ex: `FinanceModels.fullSchema`) 💡 Skill: component-architect
- [x] Atualizar `SharedContainer` para usar o schema unificado em ambos targets 💡 Skill: component-architect
- [x] Rodar app e widget para verificar ausência de erros de carregamento
- [x] Tarefa: Conductor - Verificação Manual do Usuário 'Integridade de Dados' (Protocolo em workflow.md)
