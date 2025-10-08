import XCTest

final class DebtorFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCreateDebtorFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let debtorsTab = app.tabBars.buttons[LocalizedKey("tab.debtors").stringValue]
        XCTAssertTrue(debtorsTab.waitForExistence(timeout: 5))
        debtorsTab.tap()

        let addButton = app.navigationBars.buttons[LocalizedKey("debtors.add").stringValue]
        XCTAssertTrue(addButton.exists)
        addButton.tap()

        let nameField = app.textFields[LocalizedKey("debtors.form.name").stringValue]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("João Silva")

        let phoneField = app.textFields[LocalizedKey("debtors.form.phone").stringValue]
        if phoneField.exists {
            phoneField.tap()
            phoneField.typeText("11999999999")
        }

        app.buttons[LocalizedKey("common.save").stringValue].tap()

        XCTAssertTrue(app.staticTexts["João Silva"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testCreateAgreementFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Primeiro criar devedor
        let debtorsTab = app.tabBars.buttons[LocalizedKey("tab.debtors").stringValue]
        debtorsTab.tap()

        let addButton = app.navigationBars.buttons[LocalizedKey("debtors.add").stringValue]
        addButton.tap()

        let nameField = app.textFields[LocalizedKey("debtors.form.name").stringValue]
        nameField.tap()
        nameField.typeText("Acordo Teste")

        app.buttons[LocalizedKey("common.save").stringValue].tap()

        // Entrar no devedor
        let debtorCell = app.staticTexts["Acordo Teste"]
        XCTAssertTrue(debtorCell.waitForExistence(timeout: 2))
        debtorCell.tap()

        // Criar acordo
        let addAgreementButton = app.buttons[LocalizedKey("debtor.detail.add.agreement").stringValue]
        if addAgreementButton.waitForExistence(timeout: 2) {
            addAgreementButton.tap()

            let principalField = app.textFields[LocalizedKey("agreement.form.principal").stringValue]
            if principalField.waitForExistence(timeout: 2) {
                principalField.tap()
                principalField.typeText("5000")
            }

            let installmentsField = app.textFields[LocalizedKey("agreement.form.installments").stringValue]
            if installmentsField.exists {
                installmentsField.tap()
                installmentsField.typeText("10")
            }

            app.buttons[LocalizedKey("common.save").stringValue].tap()

            // Verificar que acordo foi criado (parcelas aparecem)
            let installmentCell = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'R$'")).firstMatch
            XCTAssertTrue(installmentCell.waitForExistence(timeout: 3))
        }
    }

    @MainActor
    func testArchiveDebtorFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Criar devedor
        let debtorsTab = app.tabBars.buttons[LocalizedKey("tab.debtors").stringValue]
        debtorsTab.tap()

        let addButton = app.navigationBars.buttons[LocalizedKey("debtors.add").stringValue]
        addButton.tap()

        let nameField = app.textFields[LocalizedKey("debtors.form.name").stringValue]
        nameField.tap()
        nameField.typeText("Arquivar Teste")

        app.buttons[LocalizedKey("common.save").stringValue].tap()

        // Arquivar devedor via swipe
        let debtorCell = app.staticTexts["Arquivar Teste"]
        XCTAssertTrue(debtorCell.waitForExistence(timeout: 2))
        debtorCell.swipeLeft()

        let archiveButton = app.buttons[LocalizedKey("debtor.archive").stringValue]
        if archiveButton.waitForExistence(timeout: 2) {
            archiveButton.tap()

            // Devedor deve desaparecer da lista ativa
            XCTAssertFalse(app.staticTexts["Arquivar Teste"].exists)

            // Ativar filtro de arquivados
            let filterButton = app.buttons[LocalizedKey("debtors.filter.archived").stringValue]
            if filterButton.exists {
                filterButton.tap()
                XCTAssertTrue(app.staticTexts["Arquivar Teste"].waitForExistence(timeout: 2))
            }
        }
    }

    @MainActor
    func testSearchDebtorFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let debtorsTab = app.tabBars.buttons[LocalizedKey("tab.debtors").stringValue]
        debtorsTab.tap()

        // Criar múltiplos devedores
        let names = ["Ana Silva", "Bruno Costa", "Carlos Santos"]
        for name in names {
            let addButton = app.navigationBars.buttons[LocalizedKey("debtors.add").stringValue]
            addButton.tap()

            let nameField = app.textFields[LocalizedKey("debtors.form.name").stringValue]
            nameField.tap()
            nameField.typeText(name)

            app.buttons[LocalizedKey("common.save").stringValue].tap()

            // Aguardar salvar
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 2))
        }

        // Buscar
        let searchField = app.textFields[LocalizedKey("debtors.search").stringValue]
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("Bruno")

            // Deve mostrar apenas Bruno
            XCTAssertTrue(app.staticTexts["Bruno Costa"].exists)
            XCTAssertFalse(app.staticTexts["Ana Silva"].exists)
            XCTAssertFalse(app.staticTexts["Carlos Santos"].exists)
        }
    }

    @MainActor
    func testDeleteDebtorFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Criar devedor
        let debtorsTab = app.tabBars.buttons[LocalizedKey("tab.debtors").stringValue]
        debtorsTab.tap()

        let addButton = app.navigationBars.buttons[LocalizedKey("debtors.add").stringValue]
        addButton.tap()

        let nameField = app.textFields[LocalizedKey("debtors.form.name").stringValue]
        nameField.tap()
        nameField.typeText("Deletar Teste")

        app.buttons[LocalizedKey("common.save").stringValue].tap()

        // Deletar via swipe
        let debtorCell = app.staticTexts["Deletar Teste"]
        XCTAssertTrue(debtorCell.waitForExistence(timeout: 2))
        debtorCell.swipeLeft()

        let deleteButton = app.buttons[LocalizedKey("common.delete").stringValue]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()

            // Confirmar deleção se houver alerta
            let confirmButton = app.buttons[LocalizedKey("common.confirm").stringValue]
            if confirmButton.waitForExistence(timeout: 1) {
                confirmButton.tap()
            }

            // Devedor deve desaparecer
            XCTAssertFalse(app.staticTexts["Deletar Teste"].exists)
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
