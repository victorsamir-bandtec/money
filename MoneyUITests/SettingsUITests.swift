import XCTest

final class SettingsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testUpdateSalaryFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Navegar para Settings
        let settingsTab = app.tabBars.buttons[LocalizedKey("tab.settings").stringValue]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        // Buscar seção de salário
        let salarySection = app.staticTexts[LocalizedKey("settings.salary.title").stringValue]
        XCTAssertTrue(salarySection.waitForExistence(timeout: 2), "Seção de salário deve existir")

        // Buscar campo de salário ou botão de editar
        let salaryField = app.textFields[LocalizedKey("settings.salary.amount").stringValue]
        let editButton = app.buttons[LocalizedKey("settings.salary.edit").stringValue]

        if salaryField.waitForExistence(timeout: 2) {
            salaryField.tap()

            // Limpar e digitar novo valor
            if let currentValue = salaryField.value as? String, !currentValue.isEmpty {
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
                salaryField.typeText(deleteString)
            }

            salaryField.typeText("5500")
        } else if editButton.waitForExistence(timeout: 2) {
            editButton.tap()

            let amountField = app.textFields[LocalizedKey("settings.salary.form.amount").stringValue]
            if amountField.waitForExistence(timeout: 2) {
                amountField.tap()
                amountField.typeText("5500")
            }
        }

        // Salvar
        let saveButton = app.buttons[LocalizedKey("common.save").stringValue]
        if saveButton.exists {
            saveButton.tap()
        }

        // Verificar que valor foi salvo
        let salaryValue = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'R$ 5.500'")).firstMatch
        XCTAssertTrue(salaryValue.waitForExistence(timeout: 2), "Novo salário deve ser exibido")
    }

    @MainActor
    func testToggleNotificationsFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Navegar para Settings
        let settingsTab = app.tabBars.buttons[LocalizedKey("tab.settings").stringValue]
        settingsTab.tap()

        // Buscar toggle de notificações
        let notificationsToggle = app.switches[LocalizedKey("settings.notifications.toggle").stringValue]
        XCTAssertTrue(notificationsToggle.waitForExistence(timeout: 3), "Toggle de notificações deve existir")

        // Guardar estado inicial
        let initialState = notificationsToggle.value as? String == "1"

        // Alternar toggle
        notificationsToggle.tap()

        // Verificar que mudou de estado
        let newState = notificationsToggle.value as? String == "1"
        XCTAssertNotEqual(initialState, newState, "Estado do toggle deve ter mudado")

        // Alternar de volta
        notificationsToggle.tap()

        // Verificar que voltou ao estado original
        let finalState = notificationsToggle.value as? String == "1"
        XCTAssertEqual(initialState, finalState, "Deve voltar ao estado original")
    }

    @MainActor
    func testExportCSVFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Navegar para Settings
        let settingsTab = app.tabBars.buttons[LocalizedKey("tab.settings").stringValue]
        settingsTab.tap()

        // Buscar botão de exportar
        let exportButton = app.buttons[LocalizedKey("settings.export.csv").stringValue]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 3), "Botão de exportar deve existir")

        // Tocar no botão
        exportButton.tap()

        // Verificar que aparece sheet de compartilhamento ou confirmação
        let shareSheet = app.otherElements["ActivityListView"]
        let confirmationAlert = app.alerts.firstMatch
        let successMessage = app.staticTexts[LocalizedKey("settings.export.success").stringValue]

        let hasShareSheet = shareSheet.waitForExistence(timeout: 3)
        let hasConfirmation = confirmationAlert.exists
        let hasSuccessMessage = successMessage.exists

        XCTAssertTrue(hasShareSheet || hasConfirmation || hasSuccessMessage,
                     "Deve mostrar sheet de compartilhamento, confirmação ou mensagem de sucesso")

        // Se houver sheet de compartilhamento, fechar
        if hasShareSheet {
            // Tocar fora para fechar (pode não funcionar em todos os casos)
            app.tap()
        }

        // Se houver alerta, fechar
        if hasConfirmation {
            let okButton = confirmationAlert.buttons[LocalizedKey("common.ok").stringValue]
            if okButton.exists {
                okButton.tap()
            }
        }
    }

    @MainActor
    func testNavigateBetweenAllTabs() throws {
        let app = XCUIApplication()
        app.launch()

        // Tab 1: Dashboard (Resumo)
        let dashboardTab = app.tabBars.buttons[LocalizedKey("tab.dashboard").stringValue]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 5))
        dashboardTab.tap()

        let dashboardTitle = app.navigationBars[LocalizedKey("tab.dashboard").stringValue]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 2), "Deve estar no Dashboard")

        // Tab 2: Devedores
        let debtorsTab = app.tabBars.buttons[LocalizedKey("tab.debtors").stringValue]
        debtorsTab.tap()

        let debtorsTitle = app.navigationBars[LocalizedKey("tab.debtors").stringValue]
        XCTAssertTrue(debtorsTitle.waitForExistence(timeout: 2), "Deve estar em Devedores")

        // Tab 3: Transações
        let transactionsTab = app.tabBars.buttons[LocalizedKey("tab.transactions").stringValue]
        transactionsTab.tap()

        let transactionsTitle = app.navigationBars[LocalizedKey("tab.transactions").stringValue]
        XCTAssertTrue(transactionsTitle.waitForExistence(timeout: 2), "Deve estar em Transações")

        // Tab 4: Settings (Ajustes)
        let settingsTab = app.tabBars.buttons[LocalizedKey("tab.settings").stringValue]
        settingsTab.tap()

        let settingsTitle = app.navigationBars[LocalizedKey("tab.settings").stringValue]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 2), "Deve estar em Ajustes")

        // Voltar ao Dashboard
        dashboardTab.tap()
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 2), "Deve voltar ao Dashboard")
    }

    @MainActor
    func testSalaryHistoryDisplay() throws {
        let app = XCUIApplication()
        app.launch()

        // Navegar para Settings
        let settingsTab = app.tabBars.buttons[LocalizedKey("tab.settings").stringValue]
        settingsTab.tap()

        // Criar primeiro salário
        let salaryField = app.textFields[LocalizedKey("settings.salary.amount").stringValue]
        let editButton = app.buttons[LocalizedKey("settings.salary.edit").stringValue]

        if salaryField.waitForExistence(timeout: 2) {
            salaryField.tap()
            salaryField.typeText("4000")
        } else if editButton.waitForExistence(timeout: 2) {
            editButton.tap()
            let amountField = app.textFields[LocalizedKey("settings.salary.form.amount").stringValue]
            if amountField.waitForExistence(timeout: 2) {
                amountField.tap()
                amountField.typeText("4000")
            }
        }

        let saveButton = app.buttons[LocalizedKey("common.save").stringValue]
        if saveButton.exists {
            saveButton.tap()
        }

        // Verificar seção de histórico
        let historySection = app.staticTexts[LocalizedKey("settings.salary.history").stringValue]
        if historySection.waitForExistence(timeout: 2) {
            // Verificar que há pelo menos um item no histórico
            let historyValue = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'R$ 4.000'")).firstMatch
            XCTAssertTrue(historyValue.exists, "Histórico deve mostrar o salário salvo")
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
