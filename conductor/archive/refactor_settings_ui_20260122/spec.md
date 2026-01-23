# Specification: Refatoração Visual da Tela de Ajustes

## Contexto
A tela de Ajustes (`SettingsScene`) atual utiliza um layout funcional básico (`Form` padrão). O objetivo é elevar a qualidade visual e a organização para um nível "Profissional / Apple Native Polished", alinhando-se com as melhores práticas de design do iOS (Human Interface Guidelines), além de expandir as opções disponíveis para o usuário.

## Objetivos
1.  **Refinamento Visual:** Melhorar tipografia, ícones e hierarquia visual mantendo a natividade do iOS.
2.  **Reorganização:** Melhorar o agrupamento das configurações existentes.
3.  **Novas Funcionalidades:** Adicionar seções de "Aparência" e "Ajuda & Feedback".

## Requisitos Funcionais

### 1. Estrutura da Tela (Seções)
A nova tela de configurações deve ser organizada nas seguintes seções (na ordem sugerida):

1.  **Geral (Salário)**
    *   Manter a visualização e edição do Salário (Core Feature).
    *   Melhorar o card/celula de exibição do salário atual.

2.  **Preferências**
    *   **Notificações:** Toggle de notificações e botão de permissão (refinar visual).
    *   **Aparência (NOVO):**
        *   Seletor de Tema: Sistema / Claro / Escuro.
        *   (Opcional) Indicador visual do ícone do app ou cor de destaque atual.

3.  **Dados**
    *   Exportar Relatório (CSV).
    *   Gerenciar Dados (Popular Demo / Limpar Tudo).
    *   *Nota:* Usar ações destrutivas com confirmação clara (já existente, manter fluxo seguro).

4.  **Suporte (NOVO)**
    *   **Ajuda / FAQ:** Link ou tela de texto simples.
    *   **Avaliar o App:** Link para abrir a App Store (review).
    *   **Contato:** Link para email ou site.

5.  **Sobre**
    *   Versão do App.
    *   Créditos / Desenvolvedor.

### 2. Design & UX
*   **Estilo:** Apple Native Polished. Usar `List` com `insetGrouped` style, mas com ícones de seção coloridos (padrão Settings do iOS) para cada item.
*   **Iconografia:** Usar SF Symbols consistentes com cores de fundo nos ícones (ex: Ícone de Notificação branco com fundo vermelho, Salário com fundo verde, etc.).
*   **Tipografia:** Usar Dynamic Type corretamente.
*   **Navegação:** Título "Ajustes" grande (Large Title).

## Requisitos Técnicos
*   **Componentes:** Refatorar `SettingsScene.swift`. Quebrar seções em sub-views se necessário para manutenibilidade.
*   **ViewModel:** Atualizar `SettingsViewModel` para suportar a lógica de troca de tema (se não existir no `AppTheme/AppEnvironment`) e links de suporte.
*   **Assets:** Garantir que SF Symbols usados existam no iOS 17+.

## Critérios de Aceite
1.  A tela deve ter visual polido, similar aos Ajustes nativos do iOS.
2.  Todas as funcionalidades originais (Salário, Exportar, Notificações) devem continuar funcionando.
3.  Novas seções (Aparência, Suporte) devem estar visíveis e funcionais (mesmo que com links placeholders inicialmente se não houver URL real).
4.  O seletor de tema deve alterar o `colorScheme` do app ou da view.
