import XCTest

final class MoneyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNavigateAndCreateDebtorFlow() throws {
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
        nameField.typeText("Teste UI")

        app.buttons[LocalizedKey("common.save").stringValue].tap()

        XCTAssertTrue(app.staticTexts["Teste UI"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testExpenseFiltersFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let expensesTab = app.tabBars.buttons[LocalizedKey("tab.expenses").stringValue]
        XCTAssertTrue(expensesTab.waitForExistence(timeout: 5))
        expensesTab.tap()

        addExpense(in: app, name: "Internet", amount: "120", category: "Casa")
        addExpense(in: app, name: "Academia", amount: "90", category: "Saúde")

        let searchField = app.textFields[LocalizedKey("expenses.search").stringValue]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("Inter")

        XCTAssertTrue(app.staticTexts["Internet"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Academia"].exists)

        let clearSearch = app.buttons[LocalizedKey("expenses.search.clear").stringValue]
        if clearSearch.exists {
            clearSearch.tap()
        }

        let academiaCell = app.staticTexts["Academia"]
        XCTAssertTrue(academiaCell.waitForExistence(timeout: 2))
        academiaCell.swipeLeft()
        let archiveButton = app.buttons[LocalizedKey("expenses.archive").stringValue]
        XCTAssertTrue(archiveButton.waitForExistence(timeout: 2))
        archiveButton.tap()

        let archivedFilter = app.buttons[LocalizedKey("expenses.filter.archived").stringValue]
        XCTAssertTrue(archivedFilter.exists)
        archivedFilter.tap()
        XCTAssertTrue(app.staticTexts["Academia"].waitForExistence(timeout: 2))

        let activeFilter = app.buttons[LocalizedKey("expenses.filter.active").stringValue]
        XCTAssertTrue(activeFilter.exists)
        activeFilter.tap()
        XCTAssertFalse(app.staticTexts["Academia"].exists)
        XCTAssertTrue(app.staticTexts["Internet"].exists)
    }

    @MainActor
    private func addExpense(in app: XCUIApplication, name: String, amount: String, category: String) {
        let addButton = app.navigationBars.buttons[LocalizedKey("expenses.add").stringValue]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        let nameField = app.textFields[LocalizedKey("expenses.form.name").stringValue]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText(name)

        let amountField = app.textFields[LocalizedKey("expenses.form.amount").stringValue]
        XCTAssertTrue(amountField.waitForExistence(timeout: 2))
        amountField.tap()
        amountField.typeText(amount)

        let categoryField = app.textFields[LocalizedKey("expenses.form.category.placeholder").stringValue]
        if categoryField.waitForExistence(timeout: 1) {
            categoryField.tap()
            categoryField.typeText(category)
        }

        app.buttons[LocalizedKey("common.save").stringValue].tap()
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
