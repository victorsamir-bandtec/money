# Documentação do Money

Bem-vindo ao repositório do Money! Esta pasta concentra materiais de referência para acelerar a ambientação de novas pessoas na equipe e servir como guia vivo sobre como o app é organizado.

## Como navegar
- [Visão geral da estrutura](project-structure.md): detalha pastas, arquivos e responsabilidades.
- [Arquitetura e fluxos](architecture.md): explica como as camadas se comunicam, uso de SwiftData e serviços auxiliares.
- [Guia de desenvolvimento](development-guide.md): comandos essenciais, estilo de código e práticas de testes.

## Checklist rápido para novos devs
1. Leia a [visão geral](project-structure.md) para entender onde cada feature vive.
2. Abra o projeto com `open Money.xcodeproj` e rode no simulador (`iPhone 15`).
3. Execute `xcodebuild test -scheme Money -destination 'platform=iOS Simulator,name=iPhone 15'` para validar o ambiente.
4. Configure o simulador com região Brasil para validar formatos monetários.

## Mantendo esta documentação atualizada
- Atualize a seção de estrutura sempre que criar novas pastas ou mover arquivos.
- Adicione snippets de código somente quando necessários para ilustrar um fluxo.
- Registre decisões arquiteturais relevantes em [`architecture.md`](architecture.md) para preservar o contexto histórico.

Sugestões ou correções? Abra um PR ajustando os arquivos desta pasta.
