# Track Spec: Sistema de Score de Confiança e Dashboards Preditivos

## 1. Contexto e Objetivo
O **Money** precisa oferecer mais do que apenas um registro passivo de dívidas. O objetivo desta trilha é transformar os dados brutos (pagamentos, atrasos, montantes) em inteligência acionável.
Implementaremos dois pilares principais:
1.  **Score de Confiança do Devedor:** Uma métrica (0 a 100) que indica a confiabilidade de um devedor com base em seu histórico.
2.  **Dashboard Preditivo:** Uma visualização clara de quanto o usuário tem para receber nos próximos meses, permitindo planejamento financeiro.

## 2. Requisitos Funcionais

### 2.1. Score de Confiança (Credit Score)
- **Cálculo:** O sistema deve calcular um score de 0 a 100 para cada devedor.
- **Fatores de Influência (Sugestão Inicial):**
    -   *Pontualidade:* Pagamentos feitos em dia aumentam o score.
    -   *Atrasos:* Dias de atraso penalizam o score exponencialmente.
    -   *Volume:* Dívidas muito altas sem histórico prévio podem ter um "fator de risco" inicial.
    -   *Histórico:* Devedores antigos com histórico limpo têm bônus.
- **Visualização:**
    -   Exibir o score discretamente na tela de detalhes do devedor (`DebtorDetailView`).
    -   Usar indicadores visuais sutis (cores do semáforo: Verde/Amarelo/Vermelho) integrados ao design Liquid Glass.
- **Atualização:** O score deve ser recalculado sempre que um pagamento for registrado ou uma data de vencimento for ultrapassada (job diário ou on-access).

### 2.2. Dashboard Preditivo
- **Projeção de Fluxo de Caixa:** Exibir um gráfico (Barra ou Linha) no Dashboard principal.
- **Dados:** Mostrar o montante total a receber (parcelas a vencer) para os próximos 6 a 12 meses.
- **Interação:** Tocar em um mês deve mostrar uma lista resumida dos recebimentos esperados.
- **Design:** Manter a estética nativa e limpa.

## 3. Requisitos Técnicos

- **Core:** Implementar lógica de cálculo em um novo serviço `CreditScoreCalculator` ou extensão de `FinanceCalculator`.
- **Modelos:** Adicionar campos necessários ao modelo `Debtor` (se preciso, ou calcular on-the-fly para não duplicar estado).
- **Performance:** Cálculos devem ser assíncronos para não travar a UI, especialmente se houver muitos devedores.
- **Testes:** Cobertura alta para o algoritmo de score é crucial para garantir justiça na métrica.

## 4. Critérios de Aceite
- [ ] Algoritmo de score implementado e testado com diferentes cenários (bom pagador, pagador em atraso, novo devedor).
- [ ] Tela de Devedor exibe o score corretamente.
- [ ] Dashboard exibe gráfico de projeção condizente com as parcelas cadastradas.
- [ ] Navegação fluida e sem travamentos durante o cálculo.
