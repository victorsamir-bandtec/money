# Spec: Melhoria na Análise Histórica e Projeções

## 1. Visão Geral
Melhorar a precisão e a apresentação da tela de Análise Histórica, focando na diferenciação correta dos cenários de projeção (Otimista, Realista, Pessimista) e na modernização do design dos cards.

## 2. Requisitos Funcionais

### 2.1. Lógica de Cálculo de Projeção
- **Base de Dados:** Média dos últimos 6 meses.
    - Considerar apenas meses anteriores ao atual (fechados).
    - Considerar apenas despesas **pagas** (ignorar pendentes no passado).
    - Ignorar o mês atual (parcial) para o cálculo da média histórica.
- **Cenários:**
    - **Otimista:**
        - Receita Variável: +10% sobre a média.
        - Despesa Variável: -10% sobre a média.
    - **Realista:**
        - Mantém a média histórica exata.
    - **Pessimista:**
        - Receita Variável: -10% sobre a média.
        - Despesa Variável: +10% sobre a média.
- **Correção de Bug:** Garantir que os cards não exibam valores idênticos quando houver dados históricos.

### 2.2. Interface de Usuário (UI)
- **Cards de Projeção (`ProjectionCardView`):**
    - Adotar "Novo Padrão" visual, mais profissional e polido.
    - **Paleta de Cores Refinada:**
        - Otimista: Variação de Verde (ex: Emerald/Mint).
        - Realista: Variação de Azul (ex: Indigo/Teal).
        - Pessimista: Variação de Laranja/Marrom (ex: Amber/Orange).
    - **Conteúdo do Card:**
        - Título do Cenário (com ícone).
        - Valor Projetado (Saldo).
        - Indicador de Confiança (ex: "Confiança: 90%").
        - Visual selecionável (estado ativo/inativo claro).

## 3. Critérios de Aceite
- [ ] O cálculo da média ignora o mês atual e despesas não pagas.
- [ ] Os três cards mostram valores diferentes (se houver variação histórica).
- [ ] O Cenário Otimista reflete redução de despesas/aumento de receita.
- [ ] O Cenário Pessimista reflete aumento de despesas/redução de receita.
- [ ] O design dos cards segue o novo padrão visual proposto.
- [ ] Testes unitários cobrem as regras de cálculo dos 3 cenários.
