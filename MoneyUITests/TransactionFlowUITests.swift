import XCTest

final class TransactionFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddVariableExpenseFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Navegar para Transações
        let transactionsTab = app.tabBars.buttons[LocalizedKey("tab.transactions").stringValue]
        XCTAssertTrue(transactionsTab.waitForExistence(timeout: 5))
        transactionsTab.tap()

        // Alternar para modo variável se necessário
        let variableModeButton = app.buttons[LocalizedKey("transactions.mode.variable").stringValue]
        if variableModeButton.waitForExistence(timeout: 2) {
            variableModeButton.tap()
        }

        // Adicionar despesa
        let addButton = app.navigationBars.buttons[LocalizedKey("transactions.add").stringValue]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        // Preencher formulário
        let amountField = app.textFields[LocalizedKey("transaction.form.amount").stringValue]
        XCTAssertTrue(amountField.waitForExistence(timeout: 2))
        amountField.tap()
        amountField.typeText("150")

        let categoryField = app.textFields[LocalizedKey("transaction.form.category").stringValue]
        if categoryField.exists {
            categoryField.tap()
            categoryField.typeText("Mercado")
        }

        let noteField = app.textFields[LocalizedKey("transaction.form.note").stringValue]
        if noteField.exists {
            noteField.tap()
            noteField.typeText("Compras semanais")
        }

        app.buttons[LocalizedKey("common.save").stringValue].tap()

        // Verificar que transação aparece na lista
        XCTAssertTrue(app.staticTexts["Mercado"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'R$ 150'")).firstMatch.exists)
    }

    @MainActor
    func testAddVariableIncomeFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let transactionsTab = app.tabBars.buttons[LocalizedKey("tab.transactions").stringValue]
        transactionsTab.tap()

        let variableModeButton = app.buttons[LocalizedKey("transactions.mode.variable").stringValue]
        if variableModeButton.waitForExistence(timeout: 2) {
            variableModeButton.tap()
        }

        let addButton = app.navigationBars.buttons[LocalizedKey("transactions.add").stringValue]
        addButton.tap()

        // Selecionar tipo receita
        let incomeTypeButton = app.buttons[LocalizedKey("transaction.type.income").stringValue]
        if incomeTypeButton.waitForExistence(timeout: 2) {
            incomeTypeButton.tap()
        }

        let amountField = app.textFields[LocalizedKey("transaction.form.amount").stringValue]
        amountField.tap()
        amountField.typeText("500")

        let categoryField = app.textFields[LocalizedKey("transaction.form.category").stringValue]
        if categoryField.exists {
            categoryField.tap()
            categoryField.typeText("Freelancer")
        }

        app.buttons[LocalizedKey("common.save").stringValue].tap()

        XCTAssertTrue(app.staticTexts["Freelancer"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testFilterTransactionsByTypeFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let transactionsTab = app.tabBars.buttons[LocalizedKey("tab.transactions").stringValue]
        transactionsTab.tap()

        let variableModeButton = app.buttons[LocalizedKey("transactions.mode.variable").stringValue]
        if variableModeButton.waitForExistence(timeout: 2) {
            variableModeButton.tap()
        }

        // Criar uma despesa
        let addButton = app.navigationBars.buttons[LocalizedKey("transactions.add").stringValue]
        addButton.tap()

        let amountField = app.textFields[LocalizedKey("transaction.form.amount").stringValue]
        amountField.tap()
        amountField.typeText("200")

        let categoryField = app.textFields[LocalizedKey("transaction.form.category").stringValue]
        if categoryField.exists {
            categoryField.tap()
            categoryField.typeText("Despesa Teste")
        }

        app.buttons[LocalizedKey("common.save").stringValue].tap()
        XCTAssertTrue(app.staticTexts["Despesa Teste"].waitForExistence(timeout: 2))

        // Criar uma receita
        addButton.tap()

        let incomeTypeButton = app.buttons[LocalizedKey("transaction.type.income").stringValue]
        if incomeTypeButton.waitForExistence(timeout: 2) {
            incomeTypeButton.tap()
        }

        let amountField2 = app.textFields[LocalizedKey("transaction.form.amount").stringValue]
        amountField2.tap()
        amountField2.typeText("300")

        let categoryField2 = app.textFields[LocalizedKey("transaction.form.category").stringValue]
        if categoryField2.exists {
            categoryField2.tap()
            categoryField2.typeText("Receita Teste")
        }

        app.buttons[LocalizedKey("common.save").stringValue].tap()
        XCTAssertTrue(app.staticTexts["Receita Teste"].waitForExistence(timeout: 2))

        // Filtrar por despesas apenas
        let expenseFilterButton = app.buttons[LocalizedKey("transaction.filter.expenses").stringValue]
        if expenseFilterButton.waitForExistence(timeout: 2) {
            expenseFilterButton.tap()

            // Verificar que apenas despesas aparecem
            XCTAssertTrue(app.staticTexts["Despesa Teste"].exists, "Despesa deve aparecer no filtro de despesas")
            XCTAssertFalse(app.staticTexts["Receita Teste"].exists, "Receita não deve aparecer no filtro de despesas")
        }

        // Filtrar por receitas apenas
        let incomeFilterButton = app.buttons[LocalizedKey("transaction.filter.income").stringValue]
        if incomeFilterButton.exists {
            incomeFilterButton.tap()

            // Verificar que apenas receitas aparecem
            XCTAssertTrue(app.staticTexts["Receita Teste"].exists, "Receita deve aparecer no filtro de receitas")
            XCTAssertFalse(app.staticTexts["Despesa Teste"].exists, "Despesa não deve aparecer no filtro de receitas")
        }

        // Filtrar por todas
        let allFilterButton = app.buttons[LocalizedKey("transaction.filter.all").stringValue]
        if allFilterButton.exists {
            allFilterButton.tap()

            // Verificar que ambas aparecem
            XCTAssertTrue(app.staticTexts["Despesa Teste"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.staticTexts["Receita Teste"].exists)
        }
    }

    @MainActor
    func testSearchTransactionsFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let transactionsTab = app.tabBars.buttons[LocalizedKey("tab.transactions").stringValue]
        transactionsTab.tap()

        let variableModeButton = app.buttons[LocalizedKey("transactions.mode.variable").stringValue]
        if variableModeButton.waitForExistence(timeout: 2) {
            variableModeButton.tap()
        }

        // Criar múltiplas transações
        let categories = ["Mercado", "Transporte", "Restaurante"]
        for category in categories {
            let addButton = app.navigationBars.buttons[LocalizedKey("transactions.add").stringValue]
            addButton.tap()

            let amountField = app.textFields[LocalizedKey("transaction.form.amount").stringValue]
            amountField.tap()
            amountField.typeText("100")

            let categoryField = app.textFields[LocalizedKey("transaction.form.category").stringValue]
            if categoryField.exists {
                categoryField.tap()
                categoryField.typeText(category)
            }

            app.buttons[LocalizedKey("common.save").stringValue].tap()

            XCTAssertTrue(app.staticTexts[category].waitForExistence(timeout: 2))
        }

        // Buscar por categoria
        let searchField = app.textFields[LocalizedKey("transactions.search").stringValue]
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("Mercado")

            XCTAssertTrue(app.staticTexts["Mercado"].exists)
            XCTAssertFalse(app.staticTexts["Transporte"].exists)
        }
    }

    @MainActor
    func testDeleteTransactionFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let transactionsTab = app.tabBars.buttons[LocalizedKey("tab.transactions").stringValue]
        transactionsTab.tap()

        let variableModeButton = app.buttons[LocalizedKey("transactions.mode.variable").stringValue]
        if variableModeButton.waitForExistence(timeout: 2) {
            variableModeButton.tap()
        }

        // Criar transação
        let addButton = app.navigationBars.buttons[LocalizedKey("transactions.add").stringValue]
        addButton.tap()

        let amountField = app.textFields[LocalizedKey("transaction.form.amount").stringValue]
        amountField.tap()
        amountField.typeText("75")

        let categoryField = app.textFields[LocalizedKey("transaction.form.category").stringValue]
        if categoryField.exists {
            categoryField.tap()
            categoryField.typeText("Deletar")
        }

        app.buttons[LocalizedKey("common.save").stringValue].tap()

        // Deletar via swipe
        let transactionCell = app.staticTexts["Deletar"]
        XCTAssertTrue(transactionCell.waitForExistence(timeout: 2))
        transactionCell.swipeLeft()

        let deleteButton = app.buttons[LocalizedKey("common.delete").stringValue]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()

            XCTAssertFalse(app.staticTexts["Deletar"].exists)
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
