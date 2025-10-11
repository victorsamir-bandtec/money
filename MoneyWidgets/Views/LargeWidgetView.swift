import SwiftUI
import WidgetKit

/// Large widget view - displays complete dashboard with upcoming installments
struct LargeWidgetView: View {
    @Environment(\.widgetFamily) var family
    let summary: WidgetSummary
    let installments: [WidgetInstallment]

    private var overdueCount: Int {
        installments.filter { $0.isOverdue }.count
    }

    private var totalIncome: Decimal {
        summary.salary + summary.received + summary.variableIncome
    }

    private var totalExpenses: Decimal {
        summary.fixedExpenses + summary.variableExpenses
    }

    var body: some View {
        if summary.isEmpty && installments.isEmpty {
            EmptyWidgetView(size: family)
        } else {
            contentView
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Compact Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(summary.availableTint)
                    Text("Money")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(summary.availableTint)
                }

                Spacer()

                if overdueCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                        Text("\(overdueCount)")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.red, in: Capsule())
                }
            }

            // Main Balance
            VStack(alignment: .leading, spacing: 2) {
                Text("Saldo Disponível")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(WidgetSummary.formatter.string(from: summary.availableToSpend))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(summary.availableTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Divider()

            // Financial Summary Cards
            HStack(spacing: 8) {
                // Receitas Card
                financeCard(
                    title: "Receitas",
                    icon: "arrow.down.circle.fill",
                    iconColor: Color(red: 46/255, green: 139/255, blue: 87/255),
                    total: totalIncome,
                    items: [
                        ("Salário", summary.salary),
                        ("Recebido", summary.received),
                        ("Extras", summary.variableIncome)
                    ]
                )

                // Despesas Card
                financeCard(
                    title: "Despesas",
                    icon: "arrow.up.circle.fill",
                    iconColor: .red,
                    total: totalExpenses + summary.overdue,
                    items: [
                        ("Fixas", summary.fixedExpenses),
                        ("Variáveis", summary.variableExpenses),
                        ("Atraso", summary.overdue)
                    ]
                )
            }

            // Installments section
            if !installments.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 3) {
                    Text("Próximos Vencimentos")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    ForEach(installments.prefix(3)) { installment in
                        compactInstallmentRow(installment)

                        if installment.id != installments.prefix(3).last?.id {
                            Divider()
                                .padding(.leading, 24)
                        }
                    }
                }
            } else {
                Divider()

                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 46/255, green: 139/255, blue: 87/255))
                    Text("Sem parcelas nos próximos dias")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "money://dashboard"))
    }

    @ViewBuilder
    private func financeCard(title: String, icon: String, iconColor: Color, total: Decimal, items: [(String, Decimal)]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.primary)
            }

            // Items
            VStack(alignment: .leading, spacing: 3) {
                ForEach(items, id: \.0) { item in
                    if item.1 > .zero {
                        HStack(spacing: 0) {
                            Text(item.0)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(WidgetSummary.formatter.string(from: item.1))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(iconColor)
                        }
                    }
                }
            }

            // Total
            Divider()
                .padding(.vertical, 1)

            Text(WidgetSummary.formatter.string(from: total))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(iconColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func compactInstallmentRow(_ installment: WidgetInstallment) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(installment.isOverdue ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                .overlay {
                    Image(systemName: installment.isOverdue ? "exclamationmark.triangle.fill" : "clock.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(installment.isOverdue ? .red : .blue)
                }
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(installment.displayTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(installment.dueDate, format: .dateTime.day().month())
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(WidgetSummary.formatter.string(from: installment.amount))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(installment.isOverdue ? .red : .blue)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
