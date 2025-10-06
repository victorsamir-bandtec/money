# Prompt para Codex CLI — App iOS **QuemMeDeve** (SwiftUI • MVVM • SwiftData • iOS 26 “Liquid Glass”)
Gere um app **iOS 26** em **Swift 6**, **SwiftUI**, **MVVM**, com **SwiftData** para persistência local e **sincronização iCloud opcional**. O app ajuda a controlar **devedores**, **parcelas**, **pagamentos**, **despesas fixas**, **salário** e mostra um **resumo mensal** com alertas de vencimento. Idioma padrão **pt-BR**. Moeda padrão **BRL**. O visual usa **menus e superfícies “liquid glass” nativos do iOS 26** com fallback automático para `.ultraThinMaterial` em versões anteriores.

> Resultado esperado: saber **quem me deve**, **quanto**, **quando vence**, **quem já pagou**, **quanto entra no mês**, e **como isso cruza com salário e despesas fixas**. Fluxos rápidos e auditáveis, sem ambiguidade.

---

## 0) Entregáveis obrigatórios
- Projeto Xcode “QuemMeDeve” (alvo iOS 26+; compila em iOS 17+ com fallbacks).
- **Arquitetura MVVM** clara. **SwiftData** para persistência. **Actors** para isolar regras críticas.
- **Widgets**, **App Shortcuts (AppIntents)**, **Notificações locais**.
- **Acessibilidade** completa. **Localização** pt-BR pronta, base en-US.
- **Testes**: Unit + UI (XCTest + XCTestPlan). Cobrir regras de cálculo e fluxos críticos.
- **README** com como rodar, dados de exemplo e como ativar iCloud.
- **Sem warnings** de build. **SPM only**. Lint/format (SwiftFormat) configurados.

---

## 1) Stack e padrões
- **Swift 6** com checagem de concorrência e `Sendable` onde aplicável.
- **SwiftUI** para UI. **MVVM** por feature. **SwiftData** para persistência. **Observation** para estados.
- **Injeção por inicializadores**. Nada de singletons opacos para domínio.
- **Erros tipados** (`AppError`) com mensagens localizadas.
- **Decimal** para dinheiro. Nada de `Double` em valores monetários.
- **Feature flags** simples (ex.: `FeatureFlags.enableNotifications`).

---

## 2) Assunção honesta sobre “Liquid Glass” do iOS 26
Caso a API “liquid glass” tenha nome/assinatura diferente ou não exista publicamente, implemente um **wrapper**:
- `GlassBackgroundStyle.current`: em iOS 26+, usa o material/estilo de “liquid glass” disponível. Caso não exista, escolha o **material de maior profundidade translúcida** oferecido pelo sistema (ex.: `.regularMaterial`/`.thinMaterial`) e **documente** no código.
- Fallback ≤ iOS 25: `.ultraThinMaterial`.
- **Menús**: use `Menu` de SwiftUI com `.background(GlassBackgroundStyle.current.material)` e borda/blur compatíveis. Encapsule em `GlassMenu`.

> Objetivo: permitir adoção imediata da estética nova sem travar o build se a API real divergir do nome esperado.

---

## 3) Domínio e modelos (SwiftData)
Use `@Model` e relacionamentos. Validações mínimas embutidas nos inicializadores estáticos.

```swift
import Foundation
import SwiftData

@Model final class Debtor {
    @Attribute(.unique) var id: UUID
    var name: String
    var phone: String?
    var note: String?
    @Relationship(deleteRule: .cascade) var agreements: [DebtAgreement]
    var createdAt: Date
    var archived: Bool
    init(id: UUID = UUID(), name: String, phone: String? = nil, note: String? = nil, createdAt: Date = .now, archived: Bool = false) {
        precondition(!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        self.id = id
        self.name = name
        self.phone = phone
        self.note = note
        self.agreements = []
        self.createdAt = createdAt
        self.archived = archived
    }
}

@Model final class DebtAgreement {
    @Attribute(.unique) var id: UUID
    @Relationship var debtor: Debtor
    var title: String?          // ex.: “Empréstimo Jan”
    var principal: Decimal      // valor total emprestado
    var startDate: Date         // referência da 1ª parcela
    var installmentCount: Int
    var currencyCode: String    // “BRL”
    var interestRateMonthly: Decimal? // 0..1 (ex.: 0.02 para 2% a.m.), nil = sem juros
    @Relationship(deleteRule: .cascade) var installments: [Installment]
    var closed: Bool
    init(id: UUID = UUID(), debtor: Debtor, title: String? = nil, principal: Decimal, startDate: Date, installmentCount: Int, currencyCode: String = "BRL", interestRateMonthly: Decimal? = nil, closed: Bool = false) {
        precondition(principal > 0)
        precondition(installmentCount >= 1)
        self.id = id
        self.debtor = debtor
        self.title = title
        self.principal = principal
        self.startDate = startDate
        self.installmentCount = installmentCount
        self.currencyCode = currencyCode
        self.interestRateMonthly = interestRateMonthly
        self.installments = []
        self.closed = closed
    }
}

enum InstallmentStatus: Int, Codable { case pending, partial, paid, overdue }

@Model final class Installment {
    @Attribute(.unique) var id: UUID
    @Relationship var agreement: DebtAgreement
    var number: Int             // 1..N
    var dueDate: Date
    var amount: Decimal         // valor devido desta parcela
    var paidAmount: Decimal     // acumulado pago
    var statusRaw: Int          // map p/ InstallmentStatus
    @Relationship(deleteRule: .cascade) var payments: [Payment]
    init(id: UUID = UUID(), agreement: DebtAgreement, number: Int, dueDate: Date, amount: Decimal, paidAmount: Decimal = .zero, status: InstallmentStatus = .pending) {
        precondition(number >= 1)
        precondition(amount > 0)
        self.id = id
        self.agreement = agreement
        self.number = number
        self.dueDate = dueDate
        self.amount = amount
        self.paidAmount = paidAmount
        self.statusRaw = status.rawValue
        self.payments = []
    }
    var status: InstallmentStatus {
        get { InstallmentStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}

enum PaymentMethod: String, Codable { case pix, cash, transfer, other }

@Model final class Payment {
    @Attribute(.unique) var id: UUID
    @Relationship var installment: Installment
    var date: Date
    var amount: Decimal
    var methodRaw: String
    var note: String?
    init(id: UUID = UUID(), installment: Installment, date: Date, amount: Decimal, method: PaymentMethod, note: String? = nil) {
        precondition(amount > 0)
        self.id = id
        self.installment = installment
        self.date = date
        self.amount = amount
        self.methodRaw = method.rawValue
        self.note = note
    }
    var method: PaymentMethod {
        get { PaymentMethod(rawValue: methodRaw) ?? .other }
        set { methodRaw = newValue.rawValue }
    }
}

@Model final class FixedExpense {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var category: String?
    var dueDay: Int      // 1..31
    var active: Bool
    init(id: UUID = UUID(), name: String, amount: Decimal, category: String? = nil, dueDay: Int, active: Bool = true) {
        precondition(!name.isEmpty && amount >= 0 && (1...31).contains(dueDay))
        self.id = id; self.name = name; self.amount = amount; self.category = category; self.dueDay = dueDay; self.active = active
    }
}

@Model final class MonthlyIncome {
    @Attribute(.unique) var id: UUID
    var name: String    // “Salário”
    var amount: Decimal
    var payDay: Int     // dia do mês
    var active: Bool
    init(id: UUID = UUID(), name: String, amount: Decimal, payDay: Int, active: Bool = true) {
        precondition(!name.isEmpty && amount >= 0 && (1...31).contains(payDay))
        self.id = id; self.name = name; self.amount = amount; self.payDay = payDay; self.active = active
    }
}

@Model final class AppSettings {
    @Attribute(.unique) var id: UUID
    var currencyCode: String  // “BRL” padrão
    var notifyDaysBefore: Int // ex.: 3
    var themeAuto: Bool
    var notificationsEnabled: Bool
    init(id: UUID = UUID(), currencyCode: String = "BRL", notifyDaysBefore: Int = 3, themeAuto: Bool = true, notificationsEnabled: Bool = true) {
        self.id = id; self.currencyCode = currencyCode; self.notifyDaysBefore = notifyDaysBefore; self.themeAuto = themeAuto; self.notificationsEnabled = notificationsEnabled
    }
}
```

---

## 4) Regras de negócio
### 4.1 Geração de cronograma
- **Sem juros**: `valorParcela = principal / nParcelas`, arredondado a 2 casas com “bankers rounding”. Ajustar última parcela para fechar centavos.
- **Com juros a.m.**: usar **Price** (parcelas iguais). Fórmula:
  - `pmt = principal * i / (1 - (1 + i)^(-n))` com `i = interestRateMonthly`.
  - Gerar `n` parcelas mensais a partir de `startDate`. Se dia não existir no mês, usar **último dia do mês**.
- Cada `Installment.amount` é a **parcela devida**. Não rastrear componente juros/principal no banco, apenas no cálculo exibido (opcional).

### 4.2 Alocação de pagamento
- Aplicar pagamento ao **primeiro** `Installment` com `status != .paid`, ordem crescente.
- Permitir **parcial**: somar a `paidAmount`. Se `paidAmount == amount` → `status = .paid`.
- **Carry-over**: se exceder a parcela atual, aplicar automaticamente ao próximo e assim por diante.
- Incluir **reversão**: apagar `Payment` reabre parcela, recalcula `paidAmount/status` em cadeia.

### 4.3 Atraso
- `overdue` se `dueDate < hoje` e `paidAmount < amount`.
- Listar “em atraso” no Dashboard e no detalhe do devedor.

### 4.4 Fechamento do acordo
- `closed = true` quando **todas** as parcelas estiverem `paid`.
- Bloquear criação de novos pagamentos se `closed` verdadeiro (permitir reabrir manualmente).

### 4.5 Moeda e arredondamento
- `Locale(identifier: "pt_BR")` com `currencyCode` do acordo.
- Formatar com `NumberFormatter` seguro para `Decimal`. Evitar `NSNumber` com `Double` intermediário.

---

## 5) Funcionalidades
1. **Cadastro de Devedores** com busca e arquivamento.
2. **Acordo de Dívida** com builder de parcelamento.
3. **Registrar Pagamento** com método, data e nota.
4. **Despesas Fixas** (CRUD, dia de vencimento, ativo).
5. **Salário/Receitas** (CRUD, dia de pagamento).
6. **Resumo Mensal**:
   - KPIs: **A receber no mês**, **Recebido**, **Em atraso**, **Saldo do mês** = Recebimentos + Salários − Despesas.
   - Lista “Vencendo esta semana”.
   - Gráfico barra `Esperado x Recebido`.
7. **Calendário** de vencimentos (parcelas e despesas).
8. **Notificações locais**: N dias antes e no dia do vencimento.
9. **Exportar/Importar CSV**: devedores, acordos, parcelas, pagamentos, despesas.
10. **Face ID** opcional para abrir o app.
11. **Widgets**: pequeno e médio com totais e próximos vencimentos.
12. **App Shortcuts**: “Adicionar devedor”, “Registrar pagamento”, “Adicionar despesa fixa”, “Ver recebíveis da semana”.

---

## 6) Navegação e UI
- `TabView` com 5 abas: **Resumo**, **Devedores**, **Despesas**, **Calendário**, **Configurações**.
- **Botão flutuante** “+” em **Resumo** abrindo `GlassMenu` com ações rápidas.
- **Cartões Glass** com métricas no Dashboard. `GlassCard` com canto arredondado, blur e stroke sutil.
- **Lista de Devedores** com badges: `pendente`, `parcial`, `atrasado`, `quitado` (cor e SF Symbols).
- **Detalhe do Devedor**:
  - Header com totais: devido, pago, em atraso.
  - Seções por acordo. Dentro, lista de parcelas com status e ação rápida “Registrar pagamento”.
- **Despesas**: lista, filtro por ativo.
- **Calendário**: visão mês + agenda diária. Filtros por status.
- **Configurações**: moeda, dias de aviso, Face ID, exportar/importar CSV, iCloud on/off.

---

## 7) Design System e Glass
Crie helpers reutilizáveis e autocontidos:
```swift
struct GlassBackgroundStyle {
    let material: Material
    static var current: GlassBackgroundStyle {
        if #available(iOS 26.0, *) {
            // Tente usar o estilo “liquid glass” do sistema.
            // Se não houver API pública, escolha o material translúcido mais próximo e documente.
            return .init(material: .regularMaterial)
        } else {
            return .init(material: .ultraThinMaterial)
        }
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding()
            .background(GlassBackgroundStyle.current.material, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.15)))
    }
}

struct GlassMenu<Label: View, Content: View>: View {
    let label: Label; let content: () -> Content
    init(@ViewBuilder label: () -> Label, @ViewBuilder content: @escaping () -> Content) {
        self.label = label(); self.content = content
    }
    var body: some View {
        Menu {
            content()
        } label: {
            label
                .padding(12)
                .background(GlassBackgroundStyle.current.material, in: Capsule(style: .continuous))
                .overlay(Capsule().stroke(.white.opacity(0.15)))
        }
    }
}
```

---

## 8) ViewModels e Serviços
### 8.1 VMs por feature
- `DashboardViewModel`, `DebtorListViewModel`, `DebtorDetailViewModel`, `AgreementBuilderViewModel`, `PaymentEntryViewModel`, `FixedExpensesViewModel`, `IncomesViewModel`, `CalendarViewModel`, `SettingsViewModel`.
- Publicam estados com `@Observable`/`@Published`. Formatação via **Formatters** injetados.

### 8.2 Protocolos de serviço
```swift
protocol CurrencyFormatting { func string(for amount: Decimal, currency: String) -> String }
protocol NotificationScheduler { func scheduleDueAlerts(for installments: [Installment], daysBefore: Int) async throws }
protocol CSVExporter { func exportAll() throws -> URL }
protocol CSVImporter { func `import`(from url: URL) throws }
protocol Repository {
    // Debtor, Agreement, Installment, Payment, FixedExpense, MonthlyIncome, AppSettings
    // CRUD assíncrono com predicados SwiftData e paginação quando fizer sentido.
}
```

### 8.3 Regras de cálculo em um **Domain Actor**
```swift
actor PaymentsAllocator {
    func applyPayment(_ amount: Decimal, date: Date, method: PaymentMethod, to agreement: DebtAgreement, context: ModelContext) throws {
        var remaining = amount
        let installments = agreement.installments.sorted { $0.number < $1.number }
        for inst in installments where inst.status != .paid {
            let needed = inst.amount - inst.paidAmount
            if remaining <= 0 { break }
            let paying = min(remaining, needed)
            let p = Payment(installment: inst, date: date, amount: paying, method: method)
            context.insert(p)
            inst.paidAmount += paying
            inst.status = inst.paidAmount >= inst.amount ? .paid : .partial
            remaining -= paying
        }
        agreement.closed = installments.allSatisfy { $0.status == .paid }
    }
}
```

---

## 9) Notificações, Widgets e Atalhos
- **Notificações**: agendar `notifyDaysBefore` e no dia do vencimento para parcelas e despesas.
- **Widgets**: `WidgetKit` com timeline diária. Mostrar “A receber hoje/semana” e lista de 3 próximos vencimentos.
- **App Intents**: atalhos para adicionar devedor, registrar pagamento, adicionar despesa e ver recebíveis da semana.

---

## 10) Persistência e Sync
- **SwiftData** com containers nomeados. Migração leve habilitada.
- **iCloud sync** planejada; integração manual quando necessário.
- Predicados eficientes para status, mês, atraso. Ex.:
```swift
// Parcelas que vencem no mês X
#Predicate<Installment> { inst in
    inst.dueDate >= startOfMonth && inst.dueDate < startOfNextMonth
}
```

---

## 11) Importação/Exportação CSV
- Separador `;`.
- Arquivos: `devedores.csv`, `acordos.csv`, `parcelas.csv`, `pagamentos.csv`, `despesas.csv`.
- **Cabeçalhos** e **tipos**:
  - `devedores.csv`: `id;name;phone;note;createdAt;archived`
  - `acordos.csv`: `id;debtorId;title;principal;startDate;installmentCount;currencyCode;interestRateMonthly;closed`
  - `parcelas.csv`: `id;agreementId;number;dueDate;amount;paidAmount;status`
  - `pagamentos.csv`: `id;installmentId;date;amount;method;note`
  - `despesas.csv`: `id;name;amount;category;dueDay;active`
- Datas em **ISO 8601**. Valores monetários com **ponto** decimal.

---

## 12) Acessibilidade e Localização
- **Dynamic Type** até Extra Extra Large. **VoiceOver** com `accessibilityLabel` por célula de parcela.
- Cores com contraste AA. Ícones **SF Symbols** consistentes.
- Tudo em `Localizable.strings` pt-BR. Evite hardcoded.

---

## 13) Segurança e Privacidade
- Bloqueio com **Face ID** opcional (LocalAuthentication).
- Dados locais protegidos por **NSFileProtectionComplete** por padrão.
- Sem coleta de analytics. Somente **logs locais** para auditoria (veja 15).

---

## 14) Performance
- Operações de cálculo e export rodando em **tarefas assíncronas**.
- Listas com **diffable** implícito do SwiftUI e virtualização.
- Orçamentos: abertura do app < 500ms em device recente; lista de 1k parcelas suave.

---

## 15) Observabilidade
- `AuditLog` em disco com eventos chaves: criação/edição de acordo, pagamento registrado/revertido, import/export.
- Toggle em “Configurações” para **exportar logs** em texto.

---

## 16) Testes
### 16.1 Unit
- **Cronograma sem juros**: soma das parcelas == principal (com ajuste de centavos na última).
- **Cronograma Price**: `n` parcelas iguais. Tolerância de 1 cent.
- **Alocação com carry-over** atravessando múltiplas parcelas.
- **Detecção de atraso**.
- **Saldo mensal** com despesas e receitas.

### 16.2 UI
- Fluxo **Adicionar devedor + acordo**.
- **Registrar pagamento parcial**.
- Filtro **“Atrasados”**.
- **Snapshot** dos cartões do Dashboard.

---

## 17) Estrutura de projeto
```
QuemMeDeve/
  Domain/
    Models/
    Actors/
    Services/
  Data/
    SwiftData/
    Repositories/
  Presentation/
    Features/
      Dashboard/
      Debtors/
      AgreementBuilder/
      Payments/
      Expenses/
      Incomes/
      Calendar/
      Settings/
    Components/
      Glass/
      Lists/
      Charts/
  Shared/
    Formatting/
    DesignSystem/
    Extensions/
  Resources/
    Localizations/
    Assets.xcassets
  Tests/
    Unit/
    UITests/
```

---

## 18) Fluxos críticos
### 18.1 “Adicionar Devedor + Acordo”
1. Menu → “Adicionar Devedor”.
2. Form 1: nome e contato.
3. Form 2: principal, nº parcelas, data da 1ª, juros opcional.
4. Preview do cronograma. Confirmar. Persistir.

### 18.2 “Registrar Pagamento”
1. A partir da parcela ou do menu global.
2. Preencher valor, data, método, nota. Salvar.
3. Recalcular cadeia e status.

---

## 19) Predicados e cálculos úteis
```swift
extension Collection where Element == Installment {
    func totals() -> (due: Decimal, paid: Decimal, overdue: Decimal) {
        var due: Decimal = .zero, paid: Decimal = .zero, overdue: Decimal = .zero
        for i in self {
            due += i.amount
            paid += i.paidAmount
            if i.status == .overdue { overdue += (i.amount - i.paidAmount) }
        }
        return (due, paid, overdue)
    }
}
```

---

## 20) Dados de exemplo (Previews/Seed)
- Devedor: **Marlon**. Acordo: **R$ 1.500**, **12x**, início no próximo mês. **3 parcelas pagas**.
- Despesas: Aluguel R$ 2.000 dia 5; Internet R$ 120 dia 10.
- Receita: “Salário” R$ 8.000 dia 5.

---

## 21) Critérios de aceitação (DoD)
- Consigo cadastrar “**Marlon pegou 1.500, 12x, já pagou 3x**”.
- Vejo **1..12** com status correto. Três marcadas como **pagas**.
- Pagamento **parcial** na **parcela 4** mantém `partial` e valor correto.
- Dashboard mostra: **A receber no mês**, **Recebido**, **Em atraso**, **Saldo do mês**.
- Notificações disparam **N dias antes** e **no dia**.
- Exporto **CSV** sem travar UI.
- App **compila sem warnings**.

---

## 22) README mínimo
- **Requisitos**: Xcode recente, iOS 26 SDK (build), iOS 17+ runtime (fallbacks), Swift 6.
- **Rodar**: abrir `QuemMeDeve.xcodeproj` → Run em device/simulator.
- **iCloud**: integração planejada (necessita ajuste manual no projeto).
- **Dados de exemplo**: carregados automaticamente na primeira execução.
- **CSV**: Exportar/Importar na mesma tela.

---

## 23) Limitações conhecidas e plano de compatibilidade
- “Liquid glass” pode ter nome/API diferente. Wrapper garante compilação e estilo próximo.
- Em iOS < 26, visuais se degradam de forma aceitável.

---

## 24) Especificação de CSV (Anexo)
### 24.1 `devedores.csv`
```
id;name;phone;note;createdAt;archived
UUID;String;String?;String?;ISO8601;Bool
```

### 24.2 `acordos.csv`
```
id;debtorId;title;principal;startDate;installmentCount;currencyCode;interestRateMonthly;closed
UUID;UUID;String?;Decimal;ISO8601;Int;String;Decimal?;Bool
```

### 24.3 `parcelas.csv`
```
id;agreementId;number;dueDate;amount;paidAmount;status
UUID;UUID;Int;ISO8601;Decimal;Decimal;pending|partial|paid|overdue
```

### 24.4 `pagamentos.csv`
```
id;installmentId;date;amount;method;note
UUID;UUID;ISO8601;Decimal;pix|cash|transfer|other;String?
```

### 24.5 `despesas.csv`
```
id;name;amount;category;dueDay;active
UUID;String;Decimal;String?;1..31;Bool
```

---

## 25) Qualidade e automação
- **SwiftFormat** com regras padrão + limite de linha 120.
- **Warnings-as-errors** ativos nas targets do app.
- **XCTestPlan** com 2 planos: `UnitOnly`, `UnitAndUI`.
- **Fastfail** nos testes de regras de cálculo.

---

## 26) Comandos úteis (opcional)
Se sua automação suportar, rode uma geração como:
```
# Exemplo genérico, adapte ao seu Codex CLI
codex generate --from ./PROMPT_QuemMeDeve.md --output ./QuemMeDeve
```
> O arquivo atual **é** o prompt.

---

## 27) Glossário curto
- **Acordo**: contrato de uma dívida parcelada com um devedor.
- **Parcela**: obrigação mensal daquele acordo.
- **Pagamento**: baixa total ou parcial de uma parcela.
- **Atraso**: parcela vencida e não quitada.

---

## 28) Pseudocódigo de geração de cronograma (Price)
```swift
func generateSchedule(principal: Decimal, n: Int, i: Decimal?, firstDate: Date) -> [InstallmentSpec] {
    precondition(n >= 1 && principal > 0)
    let useInterest = (i ?? .zero) > .zero
    var result: [InstallmentSpec] = []
    if !useInterest {
        let base = principal / Decimal(n)
        for k in 0..<n {
            let date = addMonthsKeepingEOM(firstDate, k)
            let value = k == n-1 ? (principal - base * Decimal(n-1)).rounded(2) : base.rounded(2)
            result.append(.init(number: k+1, dueDate: date, amount: value))
        }
    } else {
        let iDec = i!
        let pmt = pricePMT(P: principal, i: iDec, n: n).rounded(2)
        var balance = principal
        for k in 0..<n {
            let date = addMonthsKeepingEOM(firstDate, k)
            let interest = (balance * iDec).rounded(2)
            let amort = (pmt - interest).rounded(2)
            let newBalance = (balance - amort).max(.zero)
            result.append(.init(number: k+1, dueDate: date, amount: pmt))
            balance = newBalance
        }
        // Ajuste centavos finais no último item se necessário
    }
    return result
}
```

---

## 29) Caso real solicitado
- **“Marlon pegou R$ 1.500, parcelou em 12x e já pagou 3x”**.
  - Criar Devedor “Marlon”.
  - Acordo: principal 1500, 12x, primeira parcela mês seguinte.
  - Marcar parcelas 1..3 como pagas ou registrar três pagamentos.

---

**Implemente todo o projeto de acordo com este prompt.**
