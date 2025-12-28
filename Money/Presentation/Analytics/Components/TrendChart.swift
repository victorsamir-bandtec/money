import SwiftUI
import Charts

/// Gráfico de linha mostrando tendências temporais.
/// Usa Swift Charts (iOS 16+) para renderizar gráficos nativos.
struct TrendChart: View {
    let data: [ChartDataPoint]
    let title: LocalizedStringKey
    var color: Color = .blue

    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            if data.isEmpty {
                emptyState
            } else {
                chart
            }
        }
        .padding(20)
        .moneyCard(
            tint: color,
            cornerRadius: 24,
            shadow: .compact,
            intensity: .standard
        )
    }

    private var chart: some View {
        Chart(data) { point in
            LineMark(
                x: .value("analytics.chart.month", point.date, unit: .month),
                y: .value("analytics.chart.value", point.value)
            )
            .foregroundStyle(color.gradient)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("analytics.chart.month", point.date, unit: .month),
                y: .value("analytics.chart.value", point.value)
            )
            .foregroundStyle(color.opacity(0.1).gradient)
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.month(.abbreviated))
                            .font(.caption2)
                    }
                }
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                AxisGridLine()
            }
        }
        .frame(height: 200)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 32))
                .foregroundStyle(color.opacity(0.4))
            Text("analytics.chart.empty")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            TrendChart(
                data: [
                    TrendChart.ChartDataPoint(date: Date().addingTimeInterval(-86400 * 150), value: 5000),
                    TrendChart.ChartDataPoint(date: Date().addingTimeInterval(-86400 * 120), value: 5500),
                    TrendChart.ChartDataPoint(date: Date().addingTimeInterval(-86400 * 90), value: 5200),
                    TrendChart.ChartDataPoint(date: Date().addingTimeInterval(-86400 * 60), value: 6000),
                    TrendChart.ChartDataPoint(date: Date().addingTimeInterval(-86400 * 30), value: 6200),
                    TrendChart.ChartDataPoint(date: Date(), value: 6500)
                ],
                title: "analytics.income.trend",
                color: .green
            )

            TrendChart(
                data: [],
                title: "analytics.expense.trend",
                color: .red
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
