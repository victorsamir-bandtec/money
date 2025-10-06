#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 17.0, *)
struct QuickAddDebtorIntent: AppIntent {
    static var title: LocalizedStringResource = "Adicionar devedor"
    static var description = IntentDescription("Abre o Money direto na aba de devedores para um novo cadastro.")
    static var openAppWhenRun = true

    @Parameter(title: "Nome") var name: String

    func perform() async throws -> some IntentResult {
        .result()
    }
}

@available(iOS 17.0, *)
struct LogInstallmentPaymentIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar pagamento"
    static var description = IntentDescription("Atalho para registrar pagamento de parcela diretamente da Siri ou Spotlight.")
    static var openAppWhenRun = true

    @Parameter(title: "Devedor") var debtor: String
    @Parameter(title: "Número da parcela") var installment: Int

    func perform() async throws -> some IntentResult {
        .result()
    }
}

@available(iOS 17.0, *)
struct MoneyAppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickAddDebtorIntent(),
            phrases: ["Novo devedor no \(.applicationName)"],
            shortTitle: "Novo Devedor",
            systemImageName: "person.badge.plus"
        )
        AppShortcut(
            intent: LogInstallmentPaymentIntent(),
            phrases: ["Registrar parcela no \(.applicationName)"],
            shortTitle: "Registrar Pagamento",
            systemImageName: "dollarsign.circle"
        )
    }
}
#endif
