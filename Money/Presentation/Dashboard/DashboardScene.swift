import SwiftUI
import SwiftData

struct DashboardScene: View {
    @StateObject private var viewModel: DashboardViewModel
    
    init(environment: AppEnvironment, context: ModelContext) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(context: context, currencyFormatter: environment.currencyFormatter))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Available Balance
                    BalanceHeroView(
                        availableAmount: viewModel.summary.availableToSpend,
                        formatter: viewModel.formatted
                    )
                    
                    // 2. Metrics Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        SummaryCardView(
                            title: "Despesas Fixas",
                            value: viewModel.formatted(viewModel.summary.fixedExpenses),
                            icon: "house.fill",
                            color: .orange
                        )
                        
                        SummaryCardView(
                            title: "Variáveis",
                            value: viewModel.formatted(viewModel.summary.variableExpenses),
                            icon: "cart.fill",
                            color: .pink
                        )
                        
                        SummaryCardView(
                            title: "Renda Extra",
                            value: viewModel.formatted(viewModel.summary.variableIncome),
                            icon: "banknote.fill",
                            color: .green
                        )
                        
                        SummaryCardView(
                            title: "Recebidos",
                            value: viewModel.formatted(viewModel.summary.received),
                            icon: "arrow.down.circle.fill",
                            color: .blue
                        )
                    }
                    
                    // 3. Budget Progress
                    BudgetProgressView(
                        title: "Balanço Mensal",
                        current: viewModel.summary.totalExpenses,
                        total: viewModel.summary.totalIncome,
                        color: viewModel.summary.totalExpenses > viewModel.summary.totalIncome ? .red : .blue,
                        formatter: viewModel.formatted
                    )
                    
                    // 4. Upcoming Payments
                    UpcomingPaymentsView(
                        items: viewModel.upcoming.map { item in
                            UpcomingPaymentItem(
                                id: item.id,
                                title: item.displayTitle,
                                subtitle: item.agreementTitle ?? "Empréstimo",
                                amount: item.amount,
                                date: item.dueDate,
                                type: .receivable
                            )
                        },
                        formatter: viewModel.formatted
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .animation(.snappy, value: viewModel.summary)
                .animation(.snappy, value: viewModel.upcoming)
            }
            .background(AppBackground(variant: .dashboard))
            .navigationTitle("Resumo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { try? await viewModel.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            try? await viewModel.load()
        }
        .refreshable {
            try? await viewModel.load()
        }
    }
}

// MARK: - Components

fileprivate struct BalanceHeroView: View {
    let availableAmount: Decimal
    let formatter: (Decimal) -> String
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Saldo disponível")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Text(formatter(availableAmount))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .glassBackground(cornerRadius: 28, material: .thickMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saldo disponível: \(formatter(availableAmount))")
        .accessibilityAddTraits(.isHeader)
    }
}

fileprivate struct SummaryCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: icon)
                            .foregroundStyle(color)
                            .font(.system(size: 14, weight: .semibold))
                    }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .glassBackground(cornerRadius: 20, material: .regularMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}

fileprivate struct BudgetProgressView: View {
    let title: String
    let current: Decimal
    let total: Decimal
    let color: Color
    let formatter: (Decimal) -> String
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        let value = Double(truncating: current as NSNumber) / Double(truncating: total as NSNumber)
        return min(max(value, 0), 1)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }
            
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 12)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * CGFloat(progress), height: 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
                }
            }
            .frame(height: 12)
            
            HStack {
                Text(formatter(current))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(formatter(total))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .glassBackground(cornerRadius: 20, material: .regularMaterial)
    }
}

fileprivate struct UpcomingPaymentItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let amount: Decimal
    let date: Date
    let type: PaymentType
    
    enum PaymentType {
        case receivable
        case payable
    }
}

fileprivate struct UpcomingPaymentsView: View {
    let items: [UpcomingPaymentItem]
    let formatter: (Decimal) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Próximos Vencimentos")
                .font(.headline)
                .padding(.horizontal, 4)
            
            if items.isEmpty {
                ContentUnavailableView(
                    "Tudo em dia!",
                    systemImage: "checkmark.circle",
                    description: Text("Nenhum pagamento ou recebimento próximo.")
                )
                .frame(maxWidth: .infinity)
                .padding()
                .glassBackground(cornerRadius: 20, material: .regularMaterial)
            } else {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(formatter(item.amount))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(item.type == .receivable ? .green : .primary)
                                
                                Text(item.date, format: .dateTime.day().month())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .glassBackground(cornerRadius: 16, material: .thinMaterial)
                    }
                }
            }
        }
    }
}


