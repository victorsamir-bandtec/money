import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct MoneyWidgetEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary
    let installments: [WidgetInstallment]

    static let placeholder = MoneyWidgetEntry(
        date: Date(),
        summary: .empty,
        installments: []
    )

    static let sample = MoneyWidgetEntry(
        date: Date(),
        summary: WidgetSummary(
            salary: 4200,
            received: 320,
            overdue: 450,
            fixedExpenses: 820,
            planned: 1500,
            variableExpenses: 200,
            variableIncome: 150
        ),
        installments: [
            WidgetInstallment(
                id: UUID(),
                agreementID: UUID(),
                debtorName: "João Silva",
                agreementTitle: "Empréstimo Pessoal",
                dueDate: Calendar.current.date(byAdding: .day, value: 2, to: .now)!,
                amount: 350.00,
                statusRaw: InstallmentStatus.pending.rawValue,
                isOverdue: false
            ),
            WidgetInstallment(
                id: UUID(),
                agreementID: UUID(),
                debtorName: "Maria Santos",
                agreementTitle: nil,
                dueDate: Calendar.current.date(byAdding: .day, value: -3, to: .now)!,
                amount: 150.00,
                statusRaw: InstallmentStatus.overdue.rawValue,
                isOverdue: true
            )
        ]
    )
}

// MARK: - Timeline Provider

struct MoneyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoneyWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (MoneyWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
        } else {
            Task {
                let entry = await fetchEntry()
                completion(entry)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoneyWidgetEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            let nextUpdate = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchEntry() async -> MoneyWidgetEntry {
        do {
            let provider = try WidgetDataProvider.shared()
            let summary = try await provider.fetchWidgetSummary()
            let installments = try await provider.fetchUpcomingInstallments(limit: WidgetConstants.maxInstallmentsToDisplay)
            return MoneyWidgetEntry(
                date: Date(),
                summary: summary,
                installments: installments
            )
        } catch {
            // Log structured error for debugging - avoid exposing to user
            print("⚠️ Widget data fetch failed: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("  Domain: \(nsError.domain), Code: \(nsError.code)")
            }
            return MoneyWidgetEntry(
                date: Date(),
                summary: .empty,
                installments: []
            )
        }
    }
}

// MARK: - Widget Entry View

struct MoneyWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: MoneyWidgetProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(summary: entry.summary)
        case .systemMedium:
            MediumWidgetView(
                summary: entry.summary,
                nextInstallment: entry.installments.first
            )
        case .systemLarge:
            LargeWidgetView(
                summary: entry.summary,
                installments: entry.installments
            )
        default:
            SmallWidgetView(summary: entry.summary)
        }
    }
}

// MARK: - Widget Configuration

@main
struct MoneyWidget: Widget {
    let kind: String = "MoneyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoneyWidgetProvider()) { entry in
            MoneyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.title"))
        .description(String(localized: "widget.description"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    MoneyWidget()
} timeline: {
    MoneyWidgetEntry.placeholder
    MoneyWidgetEntry.sample
}

#Preview("Medium", as: .systemMedium) {
    MoneyWidget()
} timeline: {
    MoneyWidgetEntry.placeholder
    MoneyWidgetEntry.sample
}

#Preview("Large", as: .systemLarge) {
    MoneyWidget()
} timeline: {
    MoneyWidgetEntry.placeholder
    MoneyWidgetEntry.sample
}
