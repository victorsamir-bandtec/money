import WidgetKit
import SwiftUI
import SwiftData

struct WidgetSummary {
    var monthIncome: Decimal
    var received: Decimal
    var overdue: Decimal
    var fixedExpenses: Decimal
    var salary: Decimal

    var netBalance: Decimal { salary + received - fixedExpenses }

    static let empty = WidgetSummary(monthIncome: .zero, received: .zero, overdue: .zero, fixedExpenses: .zero, salary: .zero)
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
        WidgetSummary(monthIncome: 1500, received: 320, overdue: 450, fixedExpenses: 820, salary: 4200)
    }
}

struct MoneyWidgetEntryView: View {
    var entry: MoneyWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Money")
                .font(.headline)
            HStack {
                VStack(alignment: .leading) {
                    Text("Receber: \(entry.summary.monthIncome, format: .currency(code: \"BRL\"))")
                        .font(.caption)
                    Text("Saldo: \(entry.summary.netBalance, format: .currency(code: \"BRL\"))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chart.bar.xaxis")
            }
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
