# Plano de Implementação

## Fase 1: Análise e Auditoria
- [x] Analisar `Core/Models` (SwiftData) para verificar integridade e relacionamentos 💡 Skill: critical-thinking
- [x] Auditar `Core/Services/FinanceCalculator.swift` e `CurrencyFormatter.swift` para precisão financeira 💡 Skill: critical-thinking
- [x] Revisar conformidade MVVM e "Local-first" nos ViewModels principais 💡 Skill: critical-thinking
- [x] Compilar relatório de falhas em `audit_findings.md`

## Fase 2: Correção e Refatoração
- [x] Corrigir erros críticos de cálculo ou persistência identificados
- [x] Refatorar trechos de código com alto acoplamento ou baixa coesão
- [x] Padronizar tratamento de erros com `AppError`

## Fase 3: Verificação
- [x] Criar/Atualizar testes unitários para regras de negócio corrigidas
- [x] Executar bateria completa de testes (`xcodebuild test`)
- [x] Tarefa: Conductor - Verificação Manual do Usuário 'Auditoria' (Protocolo em workflow.md)
