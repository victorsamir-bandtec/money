import XCTest

final class PaymentFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRegisterFullPaymentFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Navegar para Devedores
        let debtorsTab = app.tabBars.buttons[LocalizedKey("tab.debtors").stringValue]
        XCTAssertTrue(debtorsTab.waitForExistence(timeout: 5))
        debtorsTab.tap()

        // Criar devedor
        let addButton = app.navigationBars.buttons[LocalizedKey("debtors.add").stringValue]
        XCTAssertTrue(addButton.exists)
        addButton.tap()

        let nameField = app.textFields[LocalizedKey("debtors.form.name").stringValue]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Cliente Pagamento")

        app.buttons[LocalizedKey("common.save").stringValue].tap()

        // Aguardar devedor aparecer e tocar
        let debtorCell = app.staticTexts["Cliente Pagamento"]
        XCTAssertTrue(debtorCell.waitForExistence(timeout: 3))
        debtorCell.tap()

        // Criar acordo
        let addAgreementButton = app.buttons[LocalizedKey("debtor.detail.add.agreement").stringValue]
        if addAgreementButton.waitForExistence(timeout: 2) {
            addAgreementButton.tap()

            // Preencher dados do acordo
            let principalField = app.textFields[LocalizedKey("agreement.form.principal").stringValue]
            if principalField.waitForExistence(timeout: 2) {
                principalField.tap()
                principalField.typeText("1000")
            }

            app.buttons[LocalizedKey("common.save").stringValue].tap()
        }

        // Aguardar parcela aparecer
        let installmentCell = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'R$'")).firstMatch
        XCTAssertTrue(installmentCell.waitForExistence(timeout: 3))
        installmentCell.tap()

        // Registrar pagamento
        let paymentButton = app.buttons[LocalizedKey("installment.pay").stringValue]
        if paymentButton.waitForExistence(timeout: 2) {
            paymentButton.tap()

            let amountField = app.textFields[LocalizedKey("payment.form.amount").stringValue]
            if amountField.waitForExistence(timeout: 2) {
                amountField.tap()
                amountField.typeText("500")
            }

            app.buttons[LocalizedKey("common.save").stringValue].tap()

            // Verificar que pagamento foi registrado
            let partialStatus = app.staticTexts[LocalizedKey("installment.status.partial").stringValue]
            XCTAssertTrue(partialStatus.waitForExistence(timeout: 2))
        }
    }

    @MainActor
    func testRegisterPartialPaymentFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Navegar para Devedores
        let debtorsTab = app.tabBars.buttons[LocalizedKey("tab.debtors").stringValue]
        XCTAssertTrue(debtorsTab.waitForExistence(timeout: 5))
        debtorsTab.tap()

        // Criar devedor
        let addButton = app.navigationBars.buttons[LocalizedKey("debtors.add").stringValue]
        XCTAssertTrue(addButton.exists)
        addButton.tap()

        let nameField = app.textFields[LocalizedKey("debtors.form.name").stringValue]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Cliente Parcial")

        app.buttons[LocalizedKey("common.save").stringValue].tap()

        // Aguardar devedor aparecer e tocar
        let debtorCell = app.staticTexts["Cliente Parcial"]
        XCTAssertTrue(debtorCell.waitForExistence(timeout: 3))
        debtorCell.tap()

        // Criar acordo
        let addAgreementButton = app.buttons[LocalizedKey("debtor.detail.add.agreement").stringValue]
        if addAgreementButton.waitForExistence(timeout: 2) {
            addAgreementButton.tap()

            // Preencher dados do acordo com valor de R$ 1000
            let principalField = app.textFields[LocalizedKey("agreement.form.principal").stringValue]
            if principalField.waitForExistence(timeout: 2) {
                principalField.tap()
                principalField.typeText("1000")
            }

            app.buttons[LocalizedKey("common.save").stringValue].tap()
        }

        // Aguardar parcela aparecer
        let installmentCell = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'R$'")).firstMatch
        XCTAssertTrue(installmentCell.waitForExistence(timeout: 3))
        installmentCell.tap()

        // Registrar primeiro pagamento parcial de R$ 300
        let paymentButton = app.buttons[LocalizedKey("installment.pay").stringValue]
        if paymentButton.waitForExistence(timeout: 2) {
            paymentButton.tap()

            let amountField = app.textFields[LocalizedKey("payment.form.amount").stringValue]
            if amountField.waitForExistence(timeout: 2) {
                amountField.tap()
                amountField.typeText("300")
            }

            app.buttons[LocalizedKey("common.save").stringValue].tap()

            // Verificar que status mudou para parcial
            let partialStatus = app.staticTexts[LocalizedKey("installment.status.partial").stringValue]
            XCTAssertTrue(partialStatus.waitForExistence(timeout: 2))
        }

        // Registrar segundo pagamento parcial de R$ 400
        if paymentButton.waitForExistence(timeout: 2) {
            paymentButton.tap()

            let amountField = app.textFields[LocalizedKey("payment.form.amount").stringValue]
            if amountField.waitForExistence(timeout: 2) {
                amountField.tap()
                amountField.typeText("400")
            }

            app.buttons[LocalizedKey("common.save").stringValue].tap()

            // Verificar que status ainda é parcial (R$ 700 pago de R$ 1000)
            let partialStatus = app.staticTexts[LocalizedKey("installment.status.partial").stringValue]
            XCTAssertTrue(partialStatus.waitForExistence(timeout: 2))
        }

        // Registrar pagamento final de R$ 300
        if paymentButton.waitForExistence(timeout: 2) {
            paymentButton.tap()

            let amountField = app.textFields[LocalizedKey("payment.form.amount").stringValue]
            if amountField.waitForExistence(timeout: 2) {
                amountField.tap()
                amountField.typeText("300")
            }

            app.buttons[LocalizedKey("common.save").stringValue].tap()

            // Verificar que status mudou para pago
            let paidStatus = app.staticTexts[LocalizedKey("installment.status.paid").stringValue]
            XCTAssertTrue(paidStatus.waitForExistence(timeout: 2))
        }
    }

    @MainActor
    func testPaymentValidation() throws {
        let app = XCUIApplication()
        app.launch()

        // Navegar para Devedores
        let debtorsTab = app.tabBars.buttons[LocalizedKey("tab.debtors").stringValue]
        XCTAssertTrue(debtorsTab.waitForExistence(timeout: 5))
        debtorsTab.tap()

        // Criar devedor
        let addButton = app.navigationBars.buttons[LocalizedKey("debtors.add").stringValue]
        XCTAssertTrue(addButton.exists)
        addButton.tap()

        let nameField = app.textFields[LocalizedKey("debtors.form.name").stringValue]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Cliente Validação")

        app.buttons[LocalizedKey("common.save").stringValue].tap()

        // Aguardar devedor aparecer e tocar
        let debtorCell = app.staticTexts["Cliente Validação"]
        XCTAssertTrue(debtorCell.waitForExistence(timeout: 3))
        debtorCell.tap()

        // Criar acordo com valor de R$ 500
        let addAgreementButton = app.buttons[LocalizedKey("debtor.detail.add.agreement").stringValue]
        if addAgreementButton.waitForExistence(timeout: 2) {
            addAgreementButton.tap()

            let principalField = app.textFields[LocalizedKey("agreement.form.principal").stringValue]
            if principalField.waitForExistence(timeout: 2) {
                principalField.tap()
                principalField.typeText("500")
            }

            app.buttons[LocalizedKey("common.save").stringValue].tap()
        }

        // Aguardar parcela aparecer
        let installmentCell = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'R$'")).firstMatch
        XCTAssertTrue(installmentCell.waitForExistence(timeout: 3))
        installmentCell.tap()

        // Tentar registrar pagamento maior que o valor da parcela (R$ 600 > R$ 500)
        let paymentButton = app.buttons[LocalizedKey("installment.pay").stringValue]
        if paymentButton.waitForExistence(timeout: 2) {
            paymentButton.tap()

            let amountField = app.textFields[LocalizedKey("payment.form.amount").stringValue]
            if amountField.waitForExistence(timeout: 2) {
                amountField.tap()
                amountField.typeText("600")
            }

            // O botão de salvar deve estar desabilitado ou mostrar erro
            let saveButton = app.buttons[LocalizedKey("common.save").stringValue]

            // Se o botão estiver habilitado, verificar que aparece mensagem de erro
            if saveButton.isEnabled {
                saveButton.tap()

                // Verificar que aparece mensagem de validação
                let errorMessage = app.staticTexts[LocalizedKey("payment.form.amount.invalid").stringValue]
                XCTAssertTrue(errorMessage.waitForExistence(timeout: 2), "Mensagem de erro de validação deve aparecer")
            } else {
                // Botão desabilitado é o comportamento correto
                XCTAssertFalse(saveButton.isEnabled, "Botão deve estar desabilitado para valor inválido")
            }

            // Cancelar
            app.buttons[LocalizedKey("common.cancel").stringValue].tap()
        }

        // Tentar registrar pagamento com valor zero ou negativo
        if paymentButton.waitForExistence(timeout: 2) {
            paymentButton.tap()

            let amountField = app.textFields[LocalizedKey("payment.form.amount").stringValue]
            if amountField.waitForExistence(timeout: 2) {
                amountField.tap()
                amountField.typeText("0")
            }

            // O botão de salvar deve estar desabilitado
            let saveButton = app.buttons[LocalizedKey("common.save").stringValue]
            XCTAssertFalse(saveButton.isEnabled, "Botão deve estar desabilitado para valor zero")

            // Cancelar
            app.buttons[LocalizedKey("common.cancel").stringValue].tap()
        }

        // Registrar pagamento válido
        if paymentButton.waitForExistence(timeout: 2) {
            paymentButton.tap()

            let amountField = app.textFields[LocalizedKey("payment.form.amount").stringValue]
            if amountField.waitForExistence(timeout: 2) {
                amountField.tap()
                amountField.typeText("500")
            }

            let saveButton = app.buttons[LocalizedKey("common.save").stringValue]
            XCTAssertTrue(saveButton.isEnabled, "Botão deve estar habilitado para valor válido")
            saveButton.tap()

            // Verificar que pagamento foi registrado com sucesso
            let paidStatus = app.staticTexts[LocalizedKey("installment.status.paid").stringValue]
            XCTAssertTrue(paidStatus.waitForExistence(timeout: 2))
        }
    }
}

private struct LocalizedKey {
    private let key: String

    init(_ key: String) {
        self.key = key
    }

    var stringValue: String {
        NSLocalizedString(key, comment: "")
    }
}
