# Product Guidelines - Money (iOS)

## Comunicação e Tom de Voz
- **Amigável e Casual:** As mensagens e notificações devem ser leves e descontraídas. O objetivo é reduzir a fricção social e o desconforto inerente à cobrança de dívidas entre amigos e familiares.
- **Transparência:** Informar claramente ao usuário o status de suas finanças sem usar jargões bancários complexos.

## Design e Experiência do Usuário (UX)
- **Nativo iOS 26 (Liquid Glass):** Priorizar o uso de componentes padrão do SDK da Apple para o iOS 26. O efeito "Liquid Glass" deve vir das propriedades nativas do sistema, garantindo que o app pareça uma extensão natural do SO.
- **Acessibilidade:** Seguir as diretrizes de Human Interface Guidelines (HIG) para garantir que o app seja utilizável por todos.

## Privacidade e Dados
- **Local-First:** A privacidade é um pilar fundamental. Todos os dados financeiros são armazenados localmente no dispositivo via SwiftData. A sincronização externa deve ser opcional e via iCloud (CloudKit), garantindo que o usuário tenha controle total sobre seus dados.

## Inteligência e Insights
- **Visualização Passiva:** Insights de inteligência, como o Score de Crédito, devem ser apresentados de forma discreta no perfil do devedor, sem interromper o fluxo de uso principal.
- **Relatórios Periódicos:** Fornecer resumos contextuais (semanais/mensais) para dar ao usuário uma visão macro de sua saúde financeira e progresso nos recebimentos.

## Engenharia e Arquitetura
- **Modularidade MVVM:** Manter uma separação rigorosa entre a lógica de apresentação (Views) e a lógica de negócio (ViewModels/Services). Cada componente deve ser testável e independente.
- **Swift 6 e Concorrência:** Utilizar as capacidades modernas do Swift 6 para garantir um app performático e livre de data races.
