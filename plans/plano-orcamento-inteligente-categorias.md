# Plano: Sistema de Orçamento Inteligente com Categorias Estruturadas

## 📋 Contexto

Atualmente, o Money rastreia despesas fixas e transações variáveis, mas:
- ✅ Categorias são strings opcionais livres (`category: String?`)
- ✅ Não há validação ou sugestões de categorias
- ✅ Dashboard mostra totais, mas não quebra por categoria
- ✅ Sem controle de quanto pode gastar em cada área

### Limitações Identificadas
❌ Usuário não sabe para onde vai o dinheiro (sem agrupamento visual)
❌ Sem limites/orçamentos por categoria (gasta sem controle)
❌ Sem alertas proativos ("você está perto do limite de Lazer")
❌ Categorias inconsistentes ("alimentação" vs "Alimentacao" vs "comida")
❌ Sem comparações categoria a categoria (mês atual vs anterior)
❌ Difícil identificar onde pode economizar

### Problema de Negócio
Usuário gasta mais do que deveria em categorias não essenciais:
- Não percebe que gastou R$ 800 em delivery no mês
- Não identifica que assinaturas cresceram 40% vs ano anterior
- Não tem meta de gastos por categoria
- Descobre estouros só no final do mês

### Solução Proposta
Sistema de orçamento estruturado com:
1. **Categorias Pré-definidas** - Enum com ícones e cores consistentes
2. **Orçamento Mensal por Categoria** - Definir limites de gastos
3. **Alertas Proativos** - Notificar quando atingir 80%, 90%, 100% do orçamento
4. **Análise Visual** - Gráfico pizza mostrando distribuição de gastos
5. **Comparações Temporais** - Categoria vs mês anterior

---

## 🎯 Objetivos

### Principais
1. **Consciência de Gastos** - Ver claramente para onde vai cada real
2. **Disciplina Financeira** - Criar accountability com metas por categoria
3. **Economia** - Reduzir gastos desnecessários (lazer, delivery, assinaturas)
4. **Planejamento** - Facilitar poupança para objetivos específicos

### Secundários
- Sugestões automáticas de orçamento baseadas em histórico
- Comparação com benchmarks (sua categoria vs média do app)
- Identificação de categorias com maior crescimento
- Gamificação (badges por cumprir orçamentos)

---

## 🏗️ Arquitetura Técnica

### 1. Camada de Dados (Core/Models)

#### 1.1 Novo Enum: `ExpenseCategory`

**Arquivo:** `Money/Core/Models/ExpenseCategory.swift`

```swift
import SwiftUI

/// Categorias estruturadas para despesas fixas e transações variáveis.
enum ExpenseCategory: String, Codable, CaseIterable, Sendable {
    case housing        // Moradia (aluguel, condomínio, IPTU)
    case food           // Alimentação (mercado, delivery, restaurantes)
    case transportation // Transporte (combustível, uber, manutenção)
    case utilities      // Utilidades (luz, água, internet, telefone)
    case entertainment  // Lazer (streaming, jogos, viagens, cinema)
    case financial      // Financeiro (empréstimos, investimentos, taxas)
    case health         // Saúde (plano, farmácia, consultas)
    case education      // Educação (cursos, livros, mensalidade)
    case personal       // Pessoal (roupas, beleza, academia)
    case pets           // Pets (ração, veterinário)
    case subscriptions  // Assinaturas (Netflix, Spotify, etc.)
    case other          // Outras

    var icon: String {
        switch self {
        case .housing: return "house.fill"
        case .food: return "fork.knife"
        case .transportation: return "car.fill"
        case .utilities: return "bolt.fill"
        case .entertainment: return "gamecontroller.fill"
        case .financial: return "creditcard.fill"
        case .health: return "heart.fill"
        case .education: return "book.fill"
        case .personal: return "person.fill"
        case .pets: return "pawprint.fill"
        case .subscriptions: return "arrow.clockwise.circle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .housing: return .blue
        case .food: return .orange
        case .transportation: return .purple
        case .utilities: return .yellow
        case .entertainment: return .pink
        case .financial: return .red
        case .health: return .green
        case .education: return .indigo
        case .personal: return .teal
        case .pets: return .brown
        case .subscriptions: return .cyan
        case .other: return .gray
        }
    }

    var titleKey: String.LocalizationValue {
        switch self {
        case .housing: return "category.housing"
        case .food: return "category.food"
        case .transportation: return "category.transportation"
        case .utilities: return "category.utilities"
        case .entertainment: return "category.entertainment"
        case .financial: return "category.financial"
        case .health: return "category.health"
        case .education: return "category.education"
        case .personal: return "category.personal"
        case .pets: return "category.pets"
        case .subscriptions: return "category.subscriptions"
        case .other: return "category.other"
        }
    }

    /// Mapeia strings livres antigas para categorias estruturadas.
    static func fromLegacyString(_ string: String?) -> ExpenseCategory {
        guard let string = string?.lowercased() else { return .other }

        // Mapeamento de strings comuns
        if string.contains("aluguel") || string.contains("condominio") || string.contains("iptu") {
            return .housing
        } else if string.contains("comida") || string.contains("alimentacao") || string.contains("mercado") || string.contains("delivery") {
            return .food
        } else if string.contains("combustivel") || string.contains("uber") || string.contains("transporte") {
            return .transportation
        } else if string.contains("luz") || string.contains("agua") || string.contains("internet") || string.contains("telefone") {
            return .utilities
        } else if string.contains("lazer") || string.contains("viagem") || string.contains("cinema") {
            return .entertainment
        } else if string.contains("saude") || string.contains("farmacia") || string.contains("medico") {
            return .health
        } else if string.contains("educacao") || string.contains("curso") || string.contains("livro") {
            return .education
        } else if string.contains("roupa") || string.contains("beleza") || string.contains("academia") {
            return .personal
        } else if string.contains("pet") || string.contains("veterinario") {
            return .pets
        } else if string.contains("netflix") || string.contains("spotify") || string.contains("assinatura") {
            return .subscriptions
        } else {
            return .other
        }
    }
}

// MARK: - Protocolo para modelos com categoria

protocol Categorizable {
    var categoryRaw: String { get set }
}

extension Categorizable {
    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}
```

#### 1.2 Migração de Modelos Existentes

**Arquivo:** `Money/Core/Models/FinanceModels.swift` (modificar modelos existentes)

```swift
// ANTES:
// var category: String?

// DEPOIS (FixedExpense):
extension FixedExpense: Categorizable {
    // Propriedade calculada usando categoryRaw
    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

// Adicionar ao init de FixedExpense:
init(
    id: UUID = UUID(),
    name: String,
    amount: Decimal,
    category: ExpenseCategory = .other,  // MUDANÇA: aceita ExpenseCategory
    dueDay: Int,
    active: Bool = true,
    note: String? = nil
) {
    precondition(!name.trimmingCharacters(in: .whitespaces).isEmpty)
    precondition(amount >= 0)
    precondition((1...31).contains(dueDay))
    self.id = id
    self.name = name
    self.amount = amount
    self.categoryRaw = category.rawValue  // MUDANÇA: armazena rawValue
    self.dueDay = dueDay
    self.active = active
    self.note = note
}

// Mesmo para CashTransaction:
extension CashTransaction: Categorizable {}
```

#### 1.3 Novo Modelo: `CategoryBudget`

**Arquivo:** `Money/Core/Models/BudgetModels.swift`

```swift
import Foundation
import SwiftData

/// Orçamento mensal definido para uma categoria específica.
@Model final class CategoryBudget {
    @Attribute(.unique) var id: UUID
    var categoryRaw: String
    var monthlyLimit: Decimal               // Limite de gastos no mês
    var active: Bool                        // Se o orçamento está ativo
    var alertThresholds: [Double]           // [0.8, 0.9, 1.0] = 80%, 90%, 100%
    var createdAt: Date
    var updatedAt: Date

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        category: ExpenseCategory,
        monthlyLimit: Decimal,
        active: Bool = true,
        alertThresholds: [Double] = [0.8, 0.9, 1.0],
        createdAt: Date = .now
    ) {
        precondition(monthlyLimit >= 0)
        self.id = id
        self.categoryRaw = category.rawValue
        self.monthlyLimit = monthlyLimit
        self.active = active
        self.alertThresholds = alertThresholds.sorted()
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

/// Snapshot de gastos por categoria em um mês específico.
@Model final class CategorySpending {
    @Attribute(.unique) var id: UUID
    var categoryRaw: String
    var referenceMonth: Date
    var totalSpent: Decimal
    var budgetLimit: Decimal?
    var transactionCount: Int
    var calculatedAt: Date

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var percentageUsed: Double? {
        guard let limit = budgetLimit, limit > 0 else { return nil }
        let ratio = totalSpent / limit
        return Double(truncating: NSDecimalNumber(decimal: ratio))
    }

    var status: BudgetStatus {
        guard let percentage = percentageUsed else { return .noLimit }
        if percentage >= 1.0 { return .exceeded }
        if percentage >= 0.9 { return .critical }
        if percentage >= 0.8 { return .warning }
        return .healthy
    }

    init(
        id: UUID = UUID(),
        category: ExpenseCategory,
        referenceMonth: Date,
        totalSpent: Decimal = .zero,
        budgetLimit: Decimal? = nil,
        transactionCount: Int = 0,
        calculatedAt: Date = .now
    ) {
        self.id = id
        self.categoryRaw = category.rawValue
        self.referenceMonth = referenceMonth
        self.totalSpent = totalSpent
        self.budgetLimit = budgetLimit
        self.transactionCount = transactionCount
        self.calculatedAt = calculatedAt
    }
}

enum BudgetStatus {
    case healthy    // < 80%
    case warning    // 80-89%
    case critical   // 90-99%
    case exceeded   // >= 100%
    case noLimit    // Sem orçamento definido

    var color: Color {
        switch self {
        case .healthy: return .green
        case .warning: return .yellow
        case .critical: return .orange
        case .exceeded: return .red
        case .noLimit: return .gray
        }
    }

    var icon: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .critical: return "exclamationmark.triangle.fill"
        case .exceeded: return "xmark.circle.fill"
        case .noLimit: return "minus.circle.fill"
        }
    }
}
```

---

### 2. Camada de Serviço (Core/Services)

#### 2.1 Serviço: `BudgetAnalyzer`

**Arquivo:** `Money/Core/Services/BudgetAnalyzer.swift`

```swift
import Foundation
import SwiftData

/// Analisa gastos por categoria e compara com orçamentos.
struct BudgetAnalyzer: Sendable {

    /// Calcula gastos por categoria para um mês específico.
    func calculateSpending(
        for month: Date,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> [CategorySpending] {
        let monthInterval = calendar.dateInterval(of: .month, for: month)
            ?? DateInterval(start: month, end: month)

        // Buscar orçamentos ativos
        let budgetDescriptor = FetchDescriptor<CategoryBudget>(
            predicate: #Predicate { $0.active }
        )
        let budgets = try context.fetch(budgetDescriptor)
        let budgetMap = Dictionary(uniqueKeysWithValues: budgets.map { ($0.category, $0) })

        // Buscar despesas fixas
        let expensesDescriptor = FetchDescriptor<FixedExpense>(
            predicate: #Predicate { $0.active }
        )
        let fixedExpenses = try context.fetch(expensesDescriptor)

        // Buscar transações variáveis do mês
        let transactionsDescriptor = FetchDescriptor<CashTransaction>(
            predicate: #Predicate { tx in
                tx.date >= monthInterval.start &&
                tx.date < monthInterval.end &&
                tx.typeRaw == CashTransactionType.expense.rawValue
            }
        )
        let transactions = try context.fetch(transactionsDescriptor)

        // Agrupar gastos por categoria
        var categoryTotals: [ExpenseCategory: (spent: Decimal, count: Int)] = [:]

        // Adicionar despesas fixas
        for expense in fixedExpenses {
            let category = expense.category
            let current = categoryTotals[category] ?? (.zero, 0)
            categoryTotals[category] = (current.spent + expense.amount, current.count + 1)
        }

        // Adicionar transações variáveis
        for transaction in transactions {
            let category = transaction.category
            let current = categoryTotals[category] ?? (.zero, 0)
            categoryTotals[category] = (current.spent + transaction.amount, current.count + 1)
        }

        // Criar CategorySpending para cada categoria
        var spendings: [CategorySpending] = []
        for (category, data) in categoryTotals {
            let budget = budgetMap[category]
            let spending = CategorySpending(
                category: category,
                referenceMonth: monthInterval.start,
                totalSpent: data.spent,
                budgetLimit: budget?.monthlyLimit,
                transactionCount: data.count
            )
            context.insert(spending)
            spendings.append(spending)
        }

        try context.save()
        return spendings
    }

    /// Sugere orçamentos baseados em histórico (últimos 3 meses).
    func suggestBudgets(
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> [ExpenseCategory: Decimal] {
        let today = Date.now
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: today) ?? today

        let descriptor = FetchDescriptor<CategorySpending>(
            predicate: #Predicate { spending in
                spending.referenceMonth >= threeMonthsAgo &&
                spending.referenceMonth <= today
            }
        )
        let historicalSpending = try context.fetch(descriptor)

        // Calcular média por categoria
        var categoryAverages: [ExpenseCategory: Decimal] = [:]
        let groupedByCategory = Dictionary(grouping: historicalSpending, by: { $0.category })

        for (category, spendings) in groupedByCategory {
            let total = spendings.reduce(Decimal.zero) { $0 + $1.totalSpent }
            let average = total / Decimal(spendings.count)
            // Adicionar 10% de margem
            categoryAverages[category] = (average * 1.1).rounded(2)
        }

        return categoryAverages
    }

    /// Identifica categorias que excederam o orçamento.
    func findExceededBudgets(
        for month: Date,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> [CategorySpending] {
        let spendings = try calculateSpending(for: month, context: context, calendar: calendar)
        return spendings.filter { $0.status == .exceeded || $0.status == .critical }
    }

    /// Compara gastos do mês atual com mês anterior por categoria.
    func compareWithPreviousMonth(
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> [ExpenseCategory: Double] {
        let today = Date.now
        let currentMonth = calendar.startOfDay(for: today)
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) else {
            return [:]
        }

        let currentSpendings = try calculateSpending(for: currentMonth, context: context, calendar: calendar)
        let previousSpendings = try calculateSpending(for: previousMonth, context: context, calendar: calendar)

        let previousMap = Dictionary(uniqueKeysWithValues: previousSpendings.map { ($0.category, $0.totalSpent) })

        var comparisons: [ExpenseCategory: Double] = [:]
        for current in currentSpendings {
            if let previous = previousMap[current.category], previous > 0 {
                let growth = (current.totalSpent - previous) / previous
                comparisons[current.category] = Double(truncating: NSDecimalNumber(decimal: growth))
            }
        }

        return comparisons
    }
}
```

---

### 3. Camada de Apresentação (Presentation)

#### 3.1 ViewModel: `BudgetViewModel`

**Arquivo:** `Money/Presentation/Budget/BudgetViewModel.swift`

```swift
import Foundation
import SwiftData
import Combine

@MainActor
final class BudgetViewModel: ObservableObject {
    @Published private(set) var budgets: [CategoryBudget] = []
    @Published private(set) var currentSpending: [CategorySpending] = []
    @Published private(set) var isLoading = false
    @Published var error: AppError?
    @Published var selectedCategory: ExpenseCategory?

    private let context: ModelContext
    private let analyzer: BudgetAnalyzer
    private let currencyFormatter: CurrencyFormatter

    init(context: ModelContext, currencyFormatter: CurrencyFormatter) {
        self.context = context
        self.analyzer = BudgetAnalyzer()
        self.currencyFormatter = currencyFormatter
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Buscar orçamentos
            let budgetDescriptor = FetchDescriptor<CategoryBudget>(
                sortBy: [SortDescriptor(\.categoryRaw, order: .forward)]
            )
            budgets = try context.fetch(budgetDescriptor)

            // Calcular gastos do mês corrente
            currentSpending = try analyzer.calculateSpending(for: .now, context: context)

        } catch {
            self.error = .persistence("error.budget.load")
        }
    }

    func createOrUpdateBudget(category: ExpenseCategory, limit: Decimal) {
        do {
            // Verificar se já existe
            let descriptor = FetchDescriptor<CategoryBudget>(
                predicate: #Predicate { budget in
                    budget.categoryRaw == category.rawValue
                }
            )
            let existing = try context.fetch(descriptor).first

            if let existing {
                existing.monthlyLimit = limit
                existing.updatedAt = .now
            } else {
                let budget = CategoryBudget(category: category, monthlyLimit: limit)
                context.insert(budget)
            }

            try context.save()
            Task { await load() }

        } catch {
            self.error = .persistence("error.budget.save")
        }
    }

    func deleteBudget(_ budget: CategoryBudget) {
        context.delete(budget)
        do {
            try context.save()
            Task { await load() }
        } catch {
            self.error = .persistence("error.budget.delete")
        }
    }

    func applySuggestedBudgets() async {
        do {
            let suggestions = try analyzer.suggestBudgets(context: context)
            for (category, suggestedLimit) in suggestions {
                createOrUpdateBudget(category: category, limit: suggestedLimit)
            }
        } catch {
            self.error = .persistence("error.budget.suggest")
        }
    }

    // MARK: - Computed Properties

    func spending(for category: ExpenseCategory) -> CategorySpending? {
        currentSpending.first { $0.category == category }
    }

    func budget(for category: ExpenseCategory) -> CategoryBudget? {
        budgets.first { $0.category == category }
    }

    var totalBudgeted: Decimal {
        budgets.filter(\.active).reduce(.zero) { $0 + $1.monthlyLimit }
    }

    var totalSpent: Decimal {
        currentSpending.reduce(.zero) { $0 + $1.totalSpent }
    }

    var remainingBudget: Decimal {
        totalBudgeted - totalSpent
    }

    // MARK: - Formatters

    func formatted(_ value: Decimal) -> String {
        currencyFormatter.string(from: value)
    }
}
```

#### 3.2 Componente: `CategoryProgressBar`

**Arquivo:** `Money/Presentation/Budget/Components/CategoryProgressBar.swift`

```swift
import SwiftUI

/// Barra de progresso mostrando quanto foi gasto vs orçamento de uma categoria.
struct CategoryProgressBar: View {
    let category: ExpenseCategory
    let spent: Decimal
    let limit: Decimal?
    let currencyFormatter: CurrencyFormatter

    private var percentage: Double {
        guard let limit, limit > 0 else { return 0 }
        let ratio = spent / limit
        return min(1.0, Double(truncating: NSDecimalNumber(decimal: ratio)))
    }

    private var status: BudgetStatus {
        guard let limit, limit > 0 else { return .noLimit }
        if percentage >= 1.0 { return .exceeded }
        if percentage >= 0.9 { return .critical }
        if percentage >= 0.8 { return .warning }
        return .healthy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(category.color)
                    .frame(width: 32, height: 32)
                    .background(category.color.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.titleKey)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    if let limit {
                        Text("\(currencyFormatter.string(from: spent)) de \(currencyFormatter.string(from: limit))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Sem limite")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Badge de status
                HStack(spacing: 4) {
                    Image(systemName: status.icon)
                        .font(.caption2)
                    if let limit, limit > 0 {
                        Text("\(Int(percentage * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundStyle(status.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(status.color.opacity(0.15), in: Capsule())
            }

            // Progress bar
            if let limit, limit > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 10)

                        // Progress
                        RoundedRectangle(cornerRadius: 6)
                            .fill(status.color)
                            .frame(width: geometry.size.width * percentage, height: 10)
                            .animation(.easeInOut(duration: 0.3), value: percentage)
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(16)
        .moneyCard(
            tint: category.color,
            cornerRadius: 20,
            shadow: .compact,
            intensity: .standard
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        CategoryProgressBar(
            category: .food,
            spent: 650,
            limit: 800,
            currencyFormatter: CurrencyFormatter()
        )

        CategoryProgressBar(
            category: .entertainment,
            spent: 950,
            limit: 500,
            currencyFormatter: CurrencyFormatter()
        )

        CategoryProgressBar(
            category: .health,
            spent: 200,
            limit: nil,
            currencyFormatter: CurrencyFormatter()
        )
    }
    .padding()
}
```

#### 3.3 Scene Completa: `BudgetScene`

**Arquivo:** `Money/Presentation/Budget/BudgetScene.swift`

```swift
import SwiftUI
import SwiftData

/// Tela de gestão de orçamentos por categoria.
struct BudgetScene: View {
    @StateObject private var viewModel: BudgetViewModel
    @State private var showingBudgetForm = false
    @State private var editingCategory: ExpenseCategory?

    init(environment: AppEnvironment, context: ModelContext) {
        _viewModel = StateObject(
            wrappedValue: BudgetViewModel(
                context: context,
                currencyFormatter: environment.currencyFormatter
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Resumo geral
                    summarySection

                    // Lista de categorias com progresso
                    categoriesSection

                    // Botão de sugestão automática
                    suggestButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(AppBackground(variant: .dashboard))
            .navigationTitle("Orçamentos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingBudgetForm = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingBudgetForm) {
                BudgetFormView(
                    category: editingCategory,
                    viewModel: viewModel,
                    isPresented: $showingBudgetForm
                )
            }
        }
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        HStack(spacing: 16) {
            MetricCard(
                title: "Orçado",
                value: viewModel.formatted(viewModel.totalBudgeted),
                icon: "target",
                tint: .blue
            )

            MetricCard(
                title: "Gasto",
                value: viewModel.formatted(viewModel.totalSpent),
                icon: "arrow.up.circle.fill",
                tint: viewModel.totalSpent > viewModel.totalBudgeted ? .red : .green
            )
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categorias")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(ExpenseCategory.allCases, id: \.self) { category in
                let spending = viewModel.spending(for: category)
                let budget = viewModel.budget(for: category)

                if spending != nil || budget != nil {
                    CategoryProgressBar(
                        category: category,
                        spent: spending?.totalSpent ?? .zero,
                        limit: budget?.monthlyLimit,
                        currencyFormatter: viewModel.currencyFormatter
                    )
                    .onTapGesture {
                        editingCategory = category
                        showingBudgetForm = true
                    }
                }
            }
        }
    }

    private var suggestButton: some View {
        Button(action: {
            Task { await viewModel.applySuggestedBudgets() }
        }) {
            HStack {
                Image(systemName: "lightbulb.fill")
                Text("Sugerir Orçamentos Baseados no Histórico")
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.blue)
            .padding()
            .frame(maxWidth: .infinity)
            .moneyCard(
                tint: .blue,
                cornerRadius: 20,
                shadow: .compact,
                intensity: .subtle
            )
        }
    }
}
```

---

## 📝 Ordem de Implementação

### Fase 1: Fundação (Semana 1)
1. ✅ Criar `ExpenseCategory.swift` com enum estruturado
2. ✅ Criar `BudgetModels.swift` (`CategoryBudget`, `CategorySpending`)
3. ✅ Adicionar propriedade `categoryRaw: String` aos modelos existentes
4. ✅ Script de migração de dados (converter `category: String?` para `categoryRaw`)
5. ✅ Testes unitários para migração

### Fase 2: Serviços (Semana 2)
6. ✅ Criar `BudgetAnalyzer.swift` com cálculos de gastos
7. ✅ Implementar sugestão automática de orçamentos
8. ✅ Implementar comparação com mês anterior
9. ✅ Testes unitários para `BudgetAnalyzer`

### Fase 3: Interface (Semana 3)
10. ✅ Criar `CategoryProgressBar.swift`
11. ✅ Criar `BudgetViewModel.swift`
12. ✅ Criar `BudgetScene.swift` e `BudgetFormView.swift`
13. ✅ Adicionar filtro por categoria em listas de despesas
14. ✅ Atualizar formulários para usar `ExpenseCategory`

### Fase 4: Integração e Alertas (Semana 4)
15. ✅ Integrar com Dashboard (card de orçamentos)
16. ✅ Implementar alertas proativos (80%, 90%, 100%)
17. ✅ Adicionar gráfico pizza de distribuição no Dashboard
18. ✅ Atualizar exportação CSV com categorias
19. ✅ Testes de UI e validação final

---

## 🔄 Estratégia de Migração de Dados

### Script de Migração

**Arquivo:** `Money/Core/Services/CategoryMigrationService.swift`

```swift
import Foundation
import SwiftData

/// Migra dados legados (category: String?) para categorias estruturadas.
struct CategoryMigrationService {

    func migrateExistingData(context: ModelContext) throws {
        // 1. Migrar FixedExpense
        let expensesDescriptor = FetchDescriptor<FixedExpense>()
        let expenses = try context.fetch(expensesDescriptor)
        for expense in expenses {
            // Se categoryRaw estiver vazio, tentar converter da string antiga
            if expense.categoryRaw.isEmpty {
                // Assumir que existe uma propriedade temporária `legacyCategoryString`
                // ou buscar de backup
                expense.category = ExpenseCategory.fromLegacyString(expense.note)
            }
        }

        // 2. Migrar CashTransaction
        let transactionsDescriptor = FetchDescriptor<CashTransaction>()
        let transactions = try context.fetch(transactionsDescriptor)
        for transaction in transactions {
            if transaction.categoryRaw.isEmpty {
                transaction.category = ExpenseCategory.fromLegacyString(transaction.note)
            }
        }

        try context.save()
    }
}
```

---

## 🧪 Testes

### Testes Unitários

**Arquivo:** `MoneyTests/BudgetAnalyzerTests.swift`

```swift
import Testing
import SwiftData
@testable import Money

@Suite("BudgetAnalyzer Tests")
struct BudgetAnalyzerTests {

    @Test("Calcula gastos por categoria corretamente")
    func testCategorySpending() async throws {
        // ... criar despesas fixas e transações
        // ... validar que soma por categoria está correta
    }

    @Test("Identifica orçamentos excedidos")
    func testExceededBudgets() async throws {
        // ... criar orçamento de R$ 500 para Lazer
        // ... adicionar gastos de R$ 600
        // ... validar que está na lista de excedidos
    }

    @Test("Sugestão de orçamento usa média histórica + 10%")
    func testBudgetSuggestion() async throws {
        // ... criar 3 meses de gastos (R$ 500, R$ 600, R$ 700)
        // ... média = R$ 600
        // ... sugestão deve ser R$ 660 (600 * 1.1)
    }
}
```

---

## ⚠️ Riscos e Mitigações

| Risco | Impacto | Probabilidade | Mitigação |
|-------|---------|---------------|-----------|
| Migração de dados perde informação | Alto | Baixa | Backup antes de migrar, validação pós-migração |
| Usuários não entendem categorias | Médio | Média | Tooltips explicativos, sugestões automáticas |
| Orçamentos muito rígidos desmotivam | Baixo | Média | Permitir edição fácil, gamificação com badges |
| Performance ao calcular muitas categorias | Baixo | Baixa | Caching, agregação incremental |

---

## ✅ Validação Final

### Checklist de Conclusão
- [ ] Migração de dados executada com sucesso
- [ ] Todas as despesas têm categorias estruturadas
- [ ] Orçamentos podem ser criados e editados
- [ ] Alertas funcionam aos 80%, 90%, 100%
- [ ] Gráfico pizza de distribuição renderiza
- [ ] Comparação com mês anterior funciona
- [ ] Sugestão automática de orçamento funciona
- [ ] FilterChip reutilizado para seleção de categorias
- [ ] Exportação CSV inclui categorias estruturadas
- [ ] Testes > 80% cobertura

---

## 📊 Métricas de Sucesso

- **Adoção:** 85%+ dos usuários definem pelo menos 3 orçamentos
- **Impacto:** Redução de 20%+ em gastos não essenciais após 2 meses
- **Engajamento:** Usuários checam orçamentos 3+ vezes por semana
- **Satisfação:** NPS > 8 para a funcionalidade de orçamentos
