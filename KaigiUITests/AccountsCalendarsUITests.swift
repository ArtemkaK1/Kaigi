import XCTest
import AppKit

@MainActor final class AccountsCalendarsUITests: XCTestCase {
    func testAccountsCalendarGeometryAndScreenshots() throws {
        continueAfterFailure = false
        for appearance in ["Aqua", "DarkAqua"] {
            let app = openAccounts(appearance: appearance)
            let window = app.windows["Accounts & Calendars"]
            let connections = window.buttons["Connections"]
            let calendars = window.buttons["Visible calendars"]
            XCTAssertEqual(connections.frame.height, 24, accuracy: 0.5)
            XCTAssertEqual(calendars.frame.height, 24, accuracy: 0.5)
            XCTAssertEqual(connections.frame.maxX, calendars.frame.minX, accuracy: 0.5)
            XCTAssertEqual(connections.frame.minY, calendars.frame.minY, accuracy: 0.5)
            XCTAssertTrue(connections.isSelected)
            XCTAssertEqual(window.popUpButtons.count, 0)
            capture(window, "Connections \(appearance)")
            calendars.click()
            XCTAssertTrue(calendars.isSelected)
            let search = window.textFields["Search calendars"]
            XCTAssertTrue(search.waitForExistence(timeout: 3))
            let heading = window.staticTexts["Visible calendars"]
            let first = window.staticTexts["Sample account 1"]
            let second = window.staticTexts["Sample account 2"]
            // Baseline AX bounds include native optical outsets: 7 pt becomes 15 pt.
            XCTAssertEqual(search.frame.minY - heading.frame.maxY, 15, accuracy: 0.5)
            XCTAssertEqual(window.scrollViews.firstMatch.frame.minY - search.frame.maxY, 15, accuracy: 0.5)
            XCTAssertEqual(search.frame.height, 26, accuracy: 0.5)
            // A collapsed header's native 24 pt + two 8 pt card insets + 8 pt card gap.
            XCTAssertEqual(second.frame.minY - first.frame.minY, 48, accuracy: 0.5)
            XCTAssertEqual(first.frame.minY - window.scrollViews.firstMatch.frame.minY, 12, accuracy: 0.5)
            capture(window, "Collapsed \(appearance)")
            first.click()
            let checkbox = window.checkBoxes["Sample calendar"]
            XCTAssertTrue(checkbox.waitForExistence(timeout: 3))
            let select = window.buttons["Select all calendars in Sample account 1"]
            let deselect = window.buttons["Deselect all calendars in Sample account 1"]
            XCTAssertEqual(select.frame.height, 32, accuracy: 0.5)
            XCTAssertEqual(deselect.frame.height, 32, accuracy: 0.5)
            XCTAssertEqual(select.frame.minX, first.frame.minX, accuracy: 0.5)
            XCTAssertEqual(checkbox.frame.minX, first.frame.minX, accuracy: 0.5)
            XCTAssertEqual(select.frame.minY - first.frame.maxY, 12, accuracy: 0.5)
            XCTAssertEqual(checkbox.frame.minY - select.frame.maxY, 8, accuracy: 0.5)
            XCTAssertEqual(window.checkBoxes["Calendar 2"].frame.minY - checkbox.frame.maxY, 8, accuracy: 0.5)
            capture(window, "Expanded \(appearance)")
            let resting = try colorInside(select)
            select.hover()
            let hovered = try colorInside(select)
            XCTAssertGreaterThan(abs(resting - hovered), 0.03)
            capture(window, "Tertiary hover \(appearance)")
            deselect.click()
            XCTAssertTrue(window.staticTexts["40 selected"].exists)
            XCTAssertTrue(checkbox.exists, "Content actions must not collapse the account")
            select.click()
            XCTAssertTrue(window.staticTexts["50 selected"].exists)
            checkbox.click()
            XCTAssertTrue(window.staticTexts["49 selected"].exists)
            checkbox.click()
            // Header count and empty horizontal space must each toggle exactly once.
            window.disclosureTriangles.firstMatch.staticTexts["10 selected"].click()
            XCTAssertFalse(checkbox.exists)
            window.disclosureTriangles.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            XCTAssertTrue(checkbox.waitForExistence(timeout: 3))
            first.click()
            XCTAssertFalse(checkbox.exists)
            // Keep the native chevron interactive independently of the label gesture.
            first.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: -8, dy: 0)).click()
            XCTAssertTrue(checkbox.waitForExistence(timeout: 3))
            search.click()
            search.typeText("Calendar 2")
            XCTAssertTrue(window.checkBoxes["Calendar 2"].exists)
            XCTAssertFalse(checkbox.exists)
            deselect.click()
            XCTAssertTrue(window.staticTexts["40 selected"].exists, "Search must not narrow the account action")
            select.click()
            XCTAssertTrue(window.staticTexts["50 selected"].exists)
            search.click()
            search.typeKey("a", modifierFlags: .command)
            search.typeKey(.delete, modifierFlags: [])
            XCTAssertTrue(checkbox.exists, "Expansion state survives filtering")
            connections.click()
            XCTAssertTrue(connections.isSelected)
            XCTAssertFalse(search.exists)
            // Native button focus and arrow-key navigation, with keyboard navigation enabled locally.
            connections.typeKey(.rightArrow, modifierFlags: [])
            XCTAssertTrue(calendars.isSelected)
            calendars.typeKey(.leftArrow, modifierFlags: [])
            XCTAssertTrue(connections.isSelected)
            app.terminate()
        }
    }

    func testAccountsSelectorTabAndSpaceActivation() throws {
        let app = openAccounts(appearance: "Aqua")
        let window = app.windows["Accounts & Calendars"]
        let connections = window.buttons["Connections"]
        let calendars = window.buttons["Visible calendars"]
        connections.click()
        window.typeKey(.tab, modifierFlags: [])
        window.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(calendars.isSelected)
        window.typeKey(.tab, modifierFlags: .shift)
        window.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(connections.isSelected)
        app.terminate()
    }

    func testAccountsSelectorWithAccessibilityTextSize() throws {
        let app = openAccounts(appearance: "DarkAqua", extra: ["--large-text"])
        let window = app.windows["Accounts & Calendars"]
        let connections = window.buttons["Connections"]
        let calendars = window.buttons["Visible calendars"]
        XCTAssertGreaterThan(connections.frame.height, 24)
        XCTAssertLessThanOrEqual(calendars.frame.maxX, window.frame.maxX - 16)
        capture(window, "Connections accessibility text DarkAqua")
        calendars.click()
        window.staticTexts["Sample account 1"].click()
        let row = window.checkBoxes["Sample calendar"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertLessThanOrEqual(row.frame.maxX, window.frame.maxX - 16)
        capture(window, "Expanded accessibility text DarkAqua")
        app.terminate()
    }

    private func openAccounts(appearance: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--sample", "--show-agenda", "--fifty-calendars", "-NSAppearance", appearance, "-AppleKeyboardUIMode", "3"] + extra
        app.launch()
        app.activate()
        if !app.buttons["Next day"].waitForExistence(timeout: 2) {
            app.statusItems.firstMatch.click()
            app.activate()
        }
        XCTAssertTrue(app.buttons["Next day"].waitForExistence(timeout: 8))
        app.statusItems.firstMatch.rightClick()
        app.menuItems["showSettings"].click()
        XCTAssertTrue(app.buttons["Accounts & Calendars"].waitForExistence(timeout: 5))
        app.buttons["Accounts & Calendars"].click()
        XCTAssertTrue(app.windows["Accounts & Calendars"].waitForExistence(timeout: 5))
        return app
    }

    private func colorInside(_ button: XCUIElement) throws -> CGFloat {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: button.screenshot().pngRepresentation))
        let color = try XCTUnwrap(bitmap.colorAt(x: 8, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB))
        return (color.redComponent + color.greenComponent + color.blueComponent) / 3
    }

    private func capture(_ element: XCUIElement, _ name: String) {
        let attachment = XCTAttachment(screenshot: element.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
