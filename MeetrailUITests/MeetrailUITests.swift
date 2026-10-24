import XCTest

@MainActor final class MeetrailUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--sample"] + extra
        app.launch()
        let status = app.statusItems.firstMatch
        if status.waitForExistence(timeout: 5) { status.click() }
        else { print("SYNTHETIC_UI_TREE: " + app.debugDescription) }
        return app
    }
    func testDayNavigationSelectionAndFloatingEditor() throws {
        let app = launch()
        let next = app.buttons["Next day"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        next.click()
        app.buttons["Previous day"].click()
        app.buttons["Today"].click()
        let openNotes = app.buttons["Open notes for Product conversation"]
        XCTAssertTrue(openNotes.exists)
        XCTAssertTrue(app.buttons["Join Google Meet"].exists)
        openNotes.click()
        let editor = app.textViews["Meeting notes"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.click(); editor.typeText("Synthetic QA note. No decision made.")
        XCTAssertTrue(app.staticTexts["Saved locally"].exists)
        app.buttons["Float notes"].click()
        XCTAssertTrue(app.windows["Meetrail — Product conversation"].waitForExistence(timeout: 3))
    }
    func testKeyboardAndSavedNotesRecovery() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["Next day"].waitForExistence(timeout: 8))
        app.typeKey(.rightArrow, modifierFlags: .command)
        app.typeKey("t", modifierFlags: .command)
        app.buttons["Open notes for Weekly planning"].click()
        let editor = app.textViews["Meeting notes"]
        editor.click(); editor.typeText("Unresolved: review scope")
        app.buttons["Back"].click()
        app.buttons["Saved notes"].click()
        XCTAssertTrue(app.staticTexts["Saved notes"].exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Weekly planning")).firstMatch.exists)
    }
    func testEmptyStateAndStatusItemDismissal() throws {
        let app = launch(["--empty"])
        let empty = app.staticTexts["Room to focus"]
        XCTAssertTrue(empty.waitForExistence(timeout: 8))
        app.buttons["Close agenda"].click()
        XCTAssertFalse(empty.exists)
        app.statusItems.firstMatch.click()
        XCTAssertTrue(empty.waitForExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(empty.exists)
    }
    func testLightAndDarkAgenda() throws {
        for appearance in ["Aqua", "DarkAqua"] {
            let app = launch(["-NSAppearance", appearance])
            XCTAssertTrue(app.buttons["Next day"].waitForExistence(timeout: 8))
            XCTAssertTrue(app.buttons["Open notes for Design review"].exists)
            app.terminate()
        }
    }
}
