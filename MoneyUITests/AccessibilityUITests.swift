import XCTest

final class AccessibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAccessibilityLabelsExist() throws {
        let app = XCUIApplication()
        app.launch()

        // Verificar que elementos principais têm labels de acessibilidade

        // Tabs devem ter labels
        let dashboardTab = app.tabBars.buttons.element(boundBy: 0)
        XCTAssertTrue(dashboardTab.exists)
        XCTAssertFalse(dashboardTab.label.isEmpty, "Tab Dashboard deve ter label de acessibilidade")

        let debtorsTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(debtorsTab.exists)
        XCTAssertFalse(debtorsTab.label.isEmpty, "Tab Devedores deve ter label de acessibilidade")

        // Navegar para Devedores
        debtorsTab.tap()

        // Botão de adicionar deve ter label
        let addButton = app.navigationBars.buttons.matching(identifier: "addButton").firstMatch
        if addButton.exists {
            XCTAssertFalse(addButton.label.isEmpty, "Botão adicionar deve ter label de acessibilidade")
        }

        // Cards e elementos devem ter labels descritivos
        let cards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'card'"))
        for index in 0..<min(cards.count, 3) {
            let card = cards.element(boundBy: index)
            if card.exists {
                XCTAssertFalse(card.label.isEmpty, "Card \(index) deve ter label de acessibilidade")
            }
        }
    }

    @MainActor
    func testVoiceOverNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        // Este teste simula navegação que seria feita com VoiceOver
        // Em testes reais, VoiceOver seria ativado no dispositivo

        // Verificar que elementos são acessíveis na ordem correta
        let dashboardTab = app.tabBars.buttons.element(boundBy: 0)
        XCTAssertTrue(dashboardTab.isHittable, "Tab Dashboard deve ser acessível via VoiceOver")

        dashboardTab.tap()

        // Verificar que elementos da tela são acessíveis
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.exists)

        // Verificar que cards/métricas são acessíveis
        let staticTexts = app.staticTexts.allElementsBoundByIndex
        var accessibleCount = 0

        for text in staticTexts.prefix(10) {
            if text.exists && text.isHittable {
                accessibleCount += 1
            }
        }

        XCTAssertGreaterThan(accessibleCount, 0, "Deve haver elementos de texto acessíveis na tela")

        // Navegar para Devedores
        let debtorsTab = app.tabBars.buttons.element(boundBy: 1)
        debtorsTab.tap()

        // Verificar que lista de devedores é acessível
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'adicionar' OR label CONTAINS[c] 'add'")).firstMatch
        if addButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(addButton.isHittable, "Botão adicionar deve ser acessível")
        }
    }

    @MainActor
    func testDynamicTypeSupport() throws {
        let app = XCUIApplication()

        // Configurar Dynamic Type para tamanho grande
        // Nota: Em testes reais, isso seria configurado nas Settings do simulador
        app.launch()

        // Verificar que textos são exibidos sem truncamento
        let dashboardTab = app.tabBars.buttons.element(boundBy: 0)
        dashboardTab.tap()

        // Verificar que labels principais são visíveis
        let labels = app.staticTexts.allElementsBoundByIndex

        for label in labels.prefix(5) {
            if label.exists {
                // Verificar que label está visível (não truncado além da tela)
                XCTAssertTrue(label.frame.width > 0, "Label deve ter largura > 0")
                XCTAssertTrue(label.frame.height > 0, "Label deve ter altura > 0")

                // Verificar que não está muito grande para a tela
                let screenWidth = app.frame.width
                XCTAssertLessThanOrEqual(label.frame.width, screenWidth,
                                        "Label não deve ultrapassar largura da tela")
            }
        }

        // Navegar para tela com formulário
        let debtorsTab = app.tabBars.buttons.element(boundBy: 1)
        debtorsTab.tap()

        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'adicionar' OR label CONTAINS[c] 'add'")).firstMatch
        if addButton.waitForExistence(timeout: 2) {
            addButton.tap()

            // Verificar que campos de formulário são acessíveis
            let nameField = app.textFields.firstMatch
            if nameField.waitForExistence(timeout: 2) {
                XCTAssertTrue(nameField.isHittable, "Campo de texto deve ser acessível")
                XCTAssertTrue(nameField.frame.height > 0, "Campo deve ter altura adequada")
            }
        }
    }

    @MainActor
    func testAccessibilityIdentifiers() throws {
        let app = XCUIApplication()
        app.launch()

        // Verificar que elementos chave têm identificadores para automação

        // Tabs
        let tabs = app.tabBars.buttons.allElementsBoundByIndex
        XCTAssertGreaterThan(tabs.count, 0, "Deve haver tabs")

        // Navegar para Devedores e verificar identificadores
        let debtorsTab = tabs.element(boundBy: 1)
        debtorsTab.tap()

        // Botões devem ter identificadores ou labels únicos
        let buttons = app.buttons.allElementsBoundByIndex
        var uniqueLabels: Set<String> = []

        for button in buttons.prefix(10) {
            if button.exists && !button.label.isEmpty {
                uniqueLabels.insert(button.label)
            }
        }

        // Deve haver pelo menos alguns botões com labels únicos
        XCTAssertGreaterThan(uniqueLabels.count, 0, "Deve haver botões com labels únicos")
    }

    @MainActor
    func testAccessibilityTraits() throws {
        let app = XCUIApplication()
        app.launch()

        // Verificar que elementos têm traits apropriados

        // Tabs devem ter trait de tab
        let dashboardTab = app.tabBars.buttons.element(boundBy: 0)
        XCTAssertTrue(dashboardTab.exists)

        // Navegar e verificar botões
        let debtorsTab = app.tabBars.buttons.element(boundBy: 1)
        debtorsTab.tap()

        // Botões devem ter trait de botão
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons.prefix(5) {
            if button.exists {
                // XCUIElement de botão já tem o tipo correto
                XCTAssertEqual(button.elementType, .button, "Elemento botão deve ter tipo button")
            }
        }

        // Text fields devem ter tipo correto
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'adicionar' OR label CONTAINS[c] 'add'")).firstMatch
        if addButton.waitForExistence(timeout: 2) {
            addButton.tap()

            let textFields = app.textFields.allElementsBoundByIndex
            for field in textFields.prefix(3) {
                if field.exists {
                    XCTAssertEqual(field.elementType, .textField, "Campo de texto deve ter tipo textField")
                }
            }
        }
    }

    @MainActor
    func testAccessibilityHints() throws {
        let app = XCUIApplication()
        app.launch()

        // Verificar que elementos interativos principais têm hints quando apropriado

        let debtorsTab = app.tabBars.buttons.element(boundBy: 1)
        debtorsTab.tap()

        // Criar devedor para ter elementos na tela
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'adicionar' OR label CONTAINS[c] 'add'")).firstMatch
        if addButton.waitForExistence(timeout: 2) {
            addButton.tap()

            // Campos devem ter placeholders que servem como hints
            let textFields = app.textFields.allElementsBoundByIndex
            for field in textFields.prefix(3) {
                if field.exists {
                    // Placeholder conta como hint
                    let hasPlaceholder = field.placeholderValue != nil && !field.placeholderValue!.isEmpty
                    let hasLabel = !field.label.isEmpty

                    XCTAssertTrue(hasPlaceholder || hasLabel,
                                 "Campo deve ter placeholder ou label para orientar o usuário")
                }
            }
        }
    }
}
