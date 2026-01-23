# Plan: Refatoração Visual da Tela de Ajustes

## Phase 1: Preparação e ViewModel
- [x] Criar/Atualizar Assets de Cores e Ícones necessários 💡 Skill: ios-ui-crafter
- [x] Atualizar `SettingsViewModel` com lógica de tema e links de suporte 💡 Skill: component-architect
- [x] Escrever testes unitários para novas lógicas do ViewModel 💡 Skill: ios-quality-engineer
- [x] Tarefa: Conductor - Verificação Manual do Usuário 'Preparação e ViewModel' (Protocolo em workflow.md)

## Phase 2: Componentização UI
- [x] Criar componente `SettingsRow` (Ícone colorido + Texto) 💡 Skill: ios-ui-crafter
- [x] Criar componente `SettingsSection` (Header customizado se necessário) 💡 Skill: ios-ui-crafter
- [x] Tarefa: Conductor - Verificação Manual do Usuário 'Componentização UI' (Protocolo em workflow.md)

## Phase 3: Remontagem da Tela (SettingsScene)
- [x] Refatorar estrutura principal para `List` com estilo `insetGrouped` 💡 Skill: ios-ui-crafter
- [x] Implementar Seção Geral (Salário) com novo visual 💡 Skill: ios-ui-crafter
- [x] Implementar Seção Preferências (Notificações + Aparência) 💡 Skill: ios-ui-crafter
- [x] Implementar Seção Dados (Exportar/Limpar) com novo visual 💡 Skill: ios-ui-crafter
- [x] Implementar Seção Suporte e Sobre 💡 Skill: ios-ui-crafter
- [x] Tarefa: Conductor - Verificação Manual do Usuário 'Remontagem da Tela' (Protocolo em workflow.md)

## Phase 4: Finalização e Polimento
- [x] Verificar Acessibilidade (Dynamic Type) e Dark Mode 💡 Skill: ios-ui-crafter
- [x] Rodar SwiftFormat e Linter 💡 Skill: ios-quality-engineer
- [x] Executar todos os testes (Unit + UI) 💡 Skill: ios-quality-engineer
- [x] Tarefa: Conductor - Verificação Manual do Usuário 'Finalização e Polimento' (Protocolo em workflow.md)
