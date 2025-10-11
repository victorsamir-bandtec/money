import SwiftUI
import WidgetKit

/// Medium widget view - displays key metrics in balanced layout
struct MediumWidgetView: View {
    @Environment(\.widgetFamily) var family
    let summary: WidgetSummary
    let nextInstallment: WidgetInstallment?

    private var availableIcon: String {
        summary.availableToSpend >= .zero ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis"
    }

    private var totalIncome: Decimal {
        summary.salary + summary.received + summary.variableIncome
    }

    private var totalExpenses: Decimal {
        summary.fixedExpenses + summary.variableExpenses
    }

    private var expenseRatio: Double {
        guard totalIncome > .zero else { return 0 }
        let ratio = totalExpenses / totalIncome
        return Double(truncating: ratio as NSDecimalNumber)
    }

    var body: some View {
        if summary.isEmpty {
            EmptyWidgetView(size: family)
        } else {
            contentView
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with main balance
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(summary.availableTint)
                        Text("Money")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(summary.availableTint)
                    }

                    Text("Saldo disponível")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(WidgetSummary.formatter.string(from: summary.availableToSpend))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(summary.availableTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Divider()

            // Comprehensive metrics grid (3x2)
            VStack(spacing: 5) {
                // Row 1: Income metrics
                HStack(spacing: 6) {
                    miniMetric(
                        title: "Recebido",
                        value: WidgetSummary.formatter.string(from: summary.received),
                        icon: "checkmark.circle.fill",
                        tint: Color(red: 46/255, green: 139/255, blue: 87/255)
                    )

                    Divider()

                    miniMetric(
                        title: "A Receber",
                        value: WidgetSummary.formatter.string(from: summary.remainingToReceive),
                        icon: "clock.fill",
                        tint: .blue
                    )

                    Divider()

                    miniMetric(
                        title: "Salário",
                        value: WidgetSummary.formatter.string(from: summary.salary),
                        icon: "banknote.fill",
                        tint: .cyan
                    )
                }

                Divider()

                // Row 2: Expense metrics
                HStack(spacing: 6) {
                    miniMetric(
                        title: "Fixas",
                        value: WidgetSummary.formatter.string(from: summary.fixedExpenses),
                        icon: "rectangle.stack.fill",
                        tint: Color(red: 220/255, green: 38/255, blue: 38/255)
                    )

                    Divider()

                    miniMetric(
                        title: "Variáveis",
                        value: WidgetSummary.formatter.string(from: summary.variableExpenses),
                        icon: "chart.bar.fill",
                        tint: .red
                    )

                    Divider()

                    if summary.overdue > .zero {
                        miniMetric(
                            title: "Atraso",
                            value: WidgetSummary.formatter.string(from: summary.overdue),
                            icon: "exclamationmark.triangle.fill",
                            tint: Color(red: 255/255, green: 59/255, blue: 48/255)
                        )
                    } else {
                        miniMetric(
                            title: "Extras",
                            value: WidgetSummary.formatter.string(from: summary.variableIncome),
                            icon: "plus.circle.fill",
                            tint: Color(red: 46/255, green: 139/255, blue: 87/255)
                        )
                    }
                }
            }

            // Expense ratio progress bar
            if totalIncome > .zero {
                Divider()

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Despesas do mês")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(expenseRatio * 100))%")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(expenseRatio > 0.8 ? .red : expenseRatio > 0.6 ? Color(red: 255/255, green: 149/255, blue: 0/255) : Color(red: 46/255, green: 139/255, blue: 87/255))
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color.secondary.opacity(0.15))

                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(expenseRatio > 0.8 ? .red : expenseRatio > 0.6 ? Color(red: 255/255, green: 149/255, blue: 0/255) : Color(red: 46/255, green: 139/255, blue: 87/255))
                                .frame(width: geometry.size.width * min(CGFloat(expenseRatio), 1.0))
                        }
                    }
                    .frame(height: 5)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "money://dashboard"))
    }

    @ViewBuilder
    private func miniMetric(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
