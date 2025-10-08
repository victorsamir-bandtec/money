import SwiftUI
import SwiftData

/// Tela dedicada para registrar pagamento de uma parcela.
/// Mantém o padrão do app (Form em NavigationStack) e evita tela em branco
/// ao apresentar em sheet, usando detents e validações claras.
struct RegisterPaymentScene: View {
    let installment: Installment
    @Binding var draft: PaymentDraft
    let formatter: CurrencyFormatter
    var completion: (ResultAction) -> Void

    // Estados auxiliares de UI
    @State private var isValidAmount: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "payment.form.details")) {
                    amountField
                    DatePicker(String(localized: "payment.form.date"), selection: $draft.date, displayedComponents: .date)
                    Picker(String(localized: "payment.form.method"), selection: $draft.method) {
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            Text(methodLabel(for: method)).tag(method)
                        }
                    }
                    TextField(String(localized: "payment.form.note"), text: $draft.note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    HStack {
                        Text(String(localized: "payment.form.remaining"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatter.string(from: installment.remainingAmount))
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle(String(localized: "payment.form.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { completion(.cancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) { completion(.save(draft)) }
                        .disabled(!canSave)
                }
            }
        }
        .onAppear { validate() }
    }

    // MARK: - Subviews

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CurrencyField("payment.form.amount", value: $draft.amount, currencyCode: installment.agreement.currencyCode)
                .onChange(of: draft.amount) { _ in validate() }
            if !isValidAmount {
                // Dica de validação discreta
                Text(String(localized: "payment.form.amount.invalid"))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        isValidAmount
            && draft.amount > 0
            && draft.amount <= installment.remainingAmount
    }

    private func validate() {
        // Garante que o valor é positivo e não excede o restante
        isValidAmount = draft.amount > 0 && draft.amount <= installment.remainingAmount
    }

    private func methodLabel(for method: PaymentMethod) -> LocalizedStringKey {
        switch method {
        case .pix: return "payment.method.pix"
        case .cash: return "payment.method.cash"
        case .transfer: return "payment.method.transfer"
        case .other: return "payment.method.other"
        }
    }

    enum ResultAction {
        case save(PaymentDraft)
        case cancel
    }
}

#Preview("RegisterPaymentScene") {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Schema([Debtor.self, DebtAgreement.self, Installment.self, Payment.self]), configurations: configuration)
    let context = container.mainContext

    let debtor = Debtor(name: "João da Silva")
    let agreement = DebtAgreement(debtor: debtor, principal: 1000, startDate: .now, installmentCount: 12)
    let installment = Installment(agreement: agreement, number: 1, dueDate: .now, amount: 125)
    context.insert(debtor)
    context.insert(agreement)
    context.insert(installment)

    return RegisterPaymentScene(
        installment: installment,
        draft: .constant(PaymentDraft(amount: 125)),
        formatter: CurrencyFormatter()
    ) { _ in }
}
