import XCTest

final class DashboardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDashboardMetricsDisplay() throws {
        let app = XCUIApplication()
        app.launch()

        // Dashboard deve ser a primeira tela (tab Resumo)
        let dashboardTitle = app.navigationBars[LocalizedKey("tab.dashboard").stringValue]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Verificar que cards de métricas existem
        let salaryLabel = app.staticTexts[LocalizedKey("dashboard.metrics.salary").stringValue]
        let expensesLabel = app.staticTexts[LocalizedKey("dashboard.metrics.expenses").stringValue]
        let receivedLabel = app.staticTexts[LocalizedKey("dashboard.metrics.received").stringValue]
        let availableLabel = app.staticTexts[LocalizedKey("dashboard.metrics.available").stringValue]

        XCTAssertTrue(salaryLabel.waitForExistence(timeout: 2), "Card de salário deve existir")
        XCTAssertTrue(expensesLabel.exists, "Card de despesas deve existir")
        XCTAssertTrue(receivedLabel.exists, "Card de recebido deve existir")
        XCTAssertTrue(availableLabel.exists, "Card de disponível deve existir")

        // Verificar que valores monetários são exibidos (formato BRL)
        let currencyValues = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'R$'"))
        XCTAssertTrue(currencyValues.count > 0, "Deve haver valores monetários exibidos")
    }

    @MainActor
    func testDashboardUpcomingInstallments() throws {
        let app = XCUIApplication()
        app.launch()

        // Criar um devedor e acordo para ter parcelas próximas
        let debtorsTab = app.tabBars.buttons[LocalizedKey("tab.debtors").stringValue]
        debtorsTab.tap()

        let addButton = app.navigationBars.buttons[LocalizedKey("debtors.add").stringValue]
        addButton.tap()

        let nameField = app.textFields[LocalizedKey("debtors.form.name").stringValue]
        nameField.tap()
        nameField.typeText("Dashboard Teste")

        app.buttons[LocalizedKey("common.save").stringValue].tap()

        let debtorCell = app.staticTexts["Dashboard Teste"]
        XCTAssertTrue(debtorCell.waitForExistence(timeout: 2))
        debtorCell.tap()

        // Criar acordo
        let addAgreementButton = app.buttons[LocalizedKey("debtor.detail.add.agreement").stringValue]
        if addAgreementButton.waitForExistence(timeout: 2) {
            addAgreementButton.tap()

            let principalField = app.textFields[LocalizedKey("agreement.form.principal").stringValue]
            if principalField.waitForExistence(timeout: 2) {
                principalField.tap()
                principalField.typeText("3000")
            }

            let installmentsField = app.textFields[LocalizedKey("agreement.form.installments").stringValue]
            if installmentsField.exists {
                installmentsField.tap()
                installmentsField.typeText("3")
            }

            app.buttons[LocalizedKey("common.save").stringValue].tap()
        }

        // Voltar ao Dashboard
        let dashboardTab = app.tabBars.buttons[LocalizedKey("tab.dashboard").stringValue]
        dashboardTab.tap()

        // Verificar seção de próximas parcelas
        let upcomingSection = app.staticTexts[LocalizedKey("dashboard.upcoming.title").stringValue]
        XCTAssertTrue(upcomingSection.waitForExistence(timeout: 3), "Seção de próximas parcelas deve aparecer")

        // Verificar que a parcela criada aparece
        let installmentWithDebtorName = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Dashboard Teste'")).firstMatch
        XCTAssertTrue(installmentWithDebtorName.waitForExistence(timeout: 2), "Parcela do devedor deve aparecer")

        // Verificar que há valor monetário na parcela
        let installmentValue = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'R$ 1.000'")).firstMatch
        XCTAssertTrue(installmentValue.exists, "Valor da parcela deve ser exibido (R$ 1.000 = 3000/3)")
    }

    @MainActor
    func testNavigateFromDashboardToInstallmentDetail() throws {
        let app = XCUIApplication()
        app.launch()

        // Criar dados de teste primeiro
        let debtorsTab = app.tabBars.buttons[LocalizedKey("tab.debtors").stringValue]
        debtorsTab.tap()

        let addButton = app.navigationBars.buttons[LocalizedKey("debtors.add").stringValue]
        addButton.tap()

        let nameField = app.textFields[LocalizedKey("debtors.form.name").stringValue]
        nameField.tap()
        nameField.typeText("Navegação Teste")

        app.buttons[LocalizedKey("common.save").stringValue].tap()

        let debtorCell = app.staticTexts["Navegação Teste"]
        XCTAssertTrue(debtorCell.waitForExistence(timeout: 2))
        debtorCell.tap()

        // Criar acordo
        let addAgreementButton = app.buttons[LocalizedKey("debtor.detail.add.agreement").stringValue]
        if addAgreementButton.waitForExistence(timeout: 2) {
            addAgreementButton.tap()

            let principalField = app.textFields[LocalizedKey("agreement.form.principal").stringValue]
            if principalField.waitForExistence(timeout: 2) {
                principalField.tap()
                principalField.typeText("1000")
            }

            app.buttons[LocalizedKey("common.save").stringValue].tap()
        }

        // Voltar ao Dashboard
        let dashboardTab = app.tabBars.buttons[LocalizedKey("tab.dashboard").stringValue]
        dashboardTab.tap()

        // Esperar a parcela aparecer
        let installmentCell = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Navegação Teste'")).firstMatch
        XCTAssertTrue(installmentCell.waitForExistence(timeout: 3))

        // Tocar na parcela
        installmentCell.tap()

        // Verificar que navegou para detalhes da parcela ou acordo
        let detailView = app.navigationBars.firstMatch
        XCTAssertTrue(detailView.waitForExistence(timeout: 2), "Deve navegar para tela de detalhes")

        // Verificar que há informações da parcela
        let installmentInfo = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'R$'")).firstMatch
        XCTAssertTrue(installmentInfo.exists, "Deve exibir informações da parcela")
    }

    @MainActor
    func testDashboardAlerts() throws {
        let app = XCUIApplication()
        app.launch()

        // Verificar que seção de alertas existe (pode estar vazia se não houver parcelas vencidas)
        let dashboardTitle = app.navigationBars[LocalizedKey("tab.dashboard").stringValue]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Buscar por alertas ou mensagem de nenhum alerta
        let alertsSection = app.staticTexts[LocalizedKey("dashboard.alerts.title").stringValue]
        let noAlertsMessage = app.staticTexts[LocalizedKey("dashboard.alerts.empty").stringValue]

        // Pelo menos um deve existir
        let hasAlerts = alertsSection.waitForExistence(timeout: 2)
        let hasNoAlertsMessage = noAlertsMessage.exists

        XCTAssertTrue(hasAlerts || hasNoAlertsMessage, "Deve ter seção de alertas ou mensagem de nenhum alerta")
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
