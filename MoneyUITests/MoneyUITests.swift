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
