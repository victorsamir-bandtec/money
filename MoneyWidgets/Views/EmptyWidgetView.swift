import SwiftUI
import WidgetKit

/// Reusable empty state view for all widget sizes
struct EmptyWidgetView: View {
    let size: WidgetFamily

    var body: some View {
        Group {
            switch size {
            case .systemSmall:
                smallEmpty
            case .systemMedium:
                mediumEmpty
            case .systemLarge:
                largeEmpty
            default:
                smallEmpty
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "money://dashboard"))
    }

    private var smallEmpty: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("Abra o app")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Adicione seus dados para ver o resumo")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
    }

    private var mediumEmpty: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary.opacity(0.5))

            VStack(alignment: .leading, spacing: 4) {
                Text("Money")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Abra o app e adicione seus dados financeiros para visualizar o resumo aqui")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
    }

    private var largeEmpty: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary.opacity(0.5))

            VStack(spacing: 4) {
                Text("Money")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Configure o app para visualizar seus dados")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                    Text("Devedores")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(red: 46/255, green: 139/255, blue: 87/255))
                    Text("Pagamentos")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16))
                        .foregroundStyle(.orange)
                    Text("Resumo")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
    }
}
