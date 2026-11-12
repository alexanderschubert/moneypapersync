import XCTest

/// Rauchtests für Onboarding, Dashboard und Einstellungen.
/// Der Zustand wird über Launch-Argumente gesetzt (überschreiben UserDefaults nur für diesen Lauf).
final class MoneyPaperSyncUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(onboardingCompleted: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-onboardingCompleted", onboardingCompleted ? "YES" : "NO",
            "-sidebarCollapsed", "NO",
            "-folderBookmark", "none",
        ]
        app.launch()
        return app
    }

    func testOnboardingWalksThroughSteps() {
        let app = launch(onboardingCompleted: false)
        XCTAssertTrue(app.hasText("Willkommen bei MoneyPaperSync", timeout: 10))

        let next = app.buttons["Weiter"]
        XCTAssertTrue(next.isEnabled)
        next.click()

        XCTAssertTrue(app.hasText("MoneyMoney-Ordner", timeout: 5))
        XCTAssertFalse(app.buttons["Weiter"].isEnabled, "Ohne Ordner darf es nicht weitergehen")
        XCTAssertTrue(app.buttons["Ordner auswählen …"].exists)

        app.buttons["Zurück"].click()
        XCTAssertTrue(app.hasText("Willkommen bei MoneyPaperSync", timeout: 5))
    }

    func testDashboardShowsKPIsAndSystemStatus() {
        let app = launch(onboardingCompleted: true)
        XCTAssertTrue(app.hasText("Dashboard", timeout: 10))
        for title in ["Importierte Dokumente", "Wartende Dokumente", "Fehlerhafte Dokumente", "Erkannte Konten"] {
            let card = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", title + ":")).firstMatch
            XCTAssertTrue(card.exists, "KPI-Karte \(title) fehlt im Dashboard")
        }
        for title in ["Systemstatus", "Letzte Importe", "Importstatistik", "Verteilung nach Banken"] {
            XCTAssertTrue(app.hasText(title, timeout: 0), "\(title) fehlt im Dashboard")
        }
        XCTAssertTrue(app.buttons["Jetzt synchronisieren"].exists)
    }

    func testSidebarNavigatesToAllSections() {
        let app = launch(onboardingCompleted: true)
        XCTAssertTrue(app.buttons["Dokumente"].waitForExistence(timeout: 10))
        for title in ["Dokumente", "Warteschlange", "Konten", "Banken", "Protokoll", "Dashboard"] {
            let item = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
            XCTAssertTrue(item.exists, "Sidebar-Eintrag \(title) fehlt")
            item.click()
            XCTAssertTrue(app.hasText(title, timeout: 5), "\(title) wurde nicht geöffnet")
        }
    }

    func testMenuBarItemShowsStatusMenu() {
        let app = launch(onboardingCompleted: true)
        let item = app.statusItems.firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10), "Menüleisten-Symbol fehlt")
        item.click()
        XCTAssertTrue(app.menuItems["Jetzt synchronisieren"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.menuItems["MoneyPaperSync öffnen"].exists)
        XCTAssertTrue(app.menuItems["MoneyPaperSync beenden"].exists)
        app.typeKey(.escape, modifierFlags: [])
    }

    func testSettingsSectionsSwitch() {
        let app = launch(onboardingCompleted: true)
        let settings = app.buttons["Einstellungen"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.click()
        XCTAssertTrue(app.hasText("Einstellungen", timeout: 5))
        for section in ["MoneyMoney", "Paperless-ngx", "Import", "Benachrichtigungen", "Datenschutz", "Allgemein"] {
            let button = app.buttons[section].firstMatch
            XCTAssertTrue(button.exists, "Einstellungsbereich \(section) fehlt")
            button.click()
        }
    }
}

private extension XCUIApplication {
    /// Prüft statischen Text nach Label, mit Wartezeit. Der Subscript-Zugriff `staticTexts["…"]` und
    /// `.firstMatch` sind hier unzuverlässig (SwiftUI setzt nur das Label, keinen Identifier).
    func hasText(_ string: String, timeout: TimeInterval) -> Bool {
        let query = staticTexts.matching(NSPredicate(format: "label == %@", string))
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if query.count > 0 { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return false
    }
}
