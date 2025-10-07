import WidgetKit
import SwiftUI

struct WidgetSummary {
    var salary: Decimal
    var received: Decimal
    var overdue: Decimal
    var fixedExpenses: Decimal
    var planned: Decimal
    var variableExpenses: Decimal
    var variableIncome: Decimal
    var remainingToReceive: Decimal
    var availableToSpend: Decimal

    init(
        salary: Decimal,
        received: Decimal,
        overdue: Decimal,
        fixedExpenses: Decimal,
        planned: Decimal,
        variableExpenses: Decimal = .zero,
        variableIncome: Decimal = .zero
    ) {
        self.salary = salary
        self.received = received
        self.overdue = overdue
        self.fixedExpenses = fixedExpenses
        self.planned = planned
        self.variableExpenses = variableExpenses
        self.variableIncome = variableIncome
        self.remainingToReceive = planned + overdue
        self.availableToSpend = salary + received + planned + variableIncome - (fixedExpenses + overdue + variableExpenses)
    }

    static let empty = WidgetSummary(salary: .zero, received: .zero, overdue: .zero, fixedExpenses: .zero, planned: .zero)
}

struct MoneyWidgetEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary
}

struct MoneyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoneyWidgetEntry {
        MoneyWidgetEntry(date: Date(), summary: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (MoneyWidgetEntry) -> Void) {
        completion(MoneyWidgetEntry(date: Date(), summary: sampleSummary))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoneyWidgetEntry>) -> Void) {
        let entry = MoneyWidgetEntry(date: Date(), summary: sampleSummary)
        let next = Date().addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private var sampleSummary: WidgetSummary {
        WidgetSummary(salary: 4200, received: 320, overdue: 450, fixedExpenses: 820, planned: 1500, variableExpenses: 200, variableIncome: 150)
    }
}

struct MoneyWidgetEntryView: View {
    var entry: MoneyWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Money")
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Saldo: \(entry.summary.availableToSpend, format: .currency(code: \"BRL\"))")
                    .font(.caption)
                Text("Previsto: \(entry.summary.planned, format: .currency(code: \"BRL\"))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.black.opacity(0.08))
        }
    }
}

@main
struct MoneyWidget: Widget {
    let kind: String = "MoneyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoneyWidgetProvider()) { entry in
            MoneyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Resumo do Money")
        .description("Veja rapidamente o saldo mensal e os próximos recebimentos.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    MoneyWidget()
} timeline: {
    MoneyWidgetEntry(date: Date(), summary: .empty)
}
