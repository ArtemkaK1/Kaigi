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
            let all = window.checkBoxes["All calendars in Sample account 1"]
            XCTAssertEqual(checkboxValue(all), 1)
            XCTAssertLessThanOrEqual(all.frame.height, 24)
            XCTAssertEqual(all.frame.minX, checkbox.frame.minX, accuracy: 1)
            XCTAssertEqual(checkbox.frame.minX, first.frame.minX, accuracy: 0.5)
            // The former 32 pt bulk row, card insets and individual row spacing stay fixed.
            XCTAssertEqual(checkbox.frame.minY - first.frame.maxY, 52, accuracy: 0.5)
            XCTAssertEqual(window.checkBoxes["Calendar 2"].frame.minY - checkbox.frame.maxY, 8, accuracy: 0.5)
            capture(window, "Expanded \(appearance)")
            all.click()
            XCTAssertEqual(checkboxValue(all), 0)
            XCTAssertTrue(window.staticTexts["40 selected"].exists)
            XCTAssertTrue(checkbox.exists, "Bulk selection must not collapse the account")
            all.click()
            XCTAssertTrue(window.staticTexts["50 selected"].exists)
            checkbox.click()
            XCTAssertTrue(window.staticTexts["49 selected"].exists)
            XCTAssertEqual(checkboxValue(all), 2)
            all.click()
            XCTAssertTrue(window.staticTexts["50 selected"].exists)
            XCTAssertEqual(checkboxValue(all), 1)
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
            all.click()
            XCTAssertTrue(window.staticTexts["40 selected"].exists, "Search must not narrow the account action")
            all.click()
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

    func testMarketingAccountsAllCheckboxAndScreenshots() throws {
        continueAfterFailure = false
        for appearance in ["Aqua", "DarkAqua"] {
            let session = UUID().uuidString
            let args = ["--marketing-fixtures", "--test-session", session]
            let app = openAccounts(appearance: appearance, extra: args, scale: false)
            let window = app.windows["Accounts & Calendars"]
            XCTAssertTrue(window.staticTexts["Connected through macOS"].exists)
            window.buttons["Visible calendars"].click()
            XCTAssertTrue(window.staticTexts["8 selected"].exists)
            for name in ["Work Account", "Personal Account", "Subscribed Calendars"] {
                XCTAssertTrue(window.staticTexts[name].exists)
            }
            XCTAssertFalse(window.staticTexts["Sample account 1"].exists)
            let work = window.staticTexts["Work Account"]
            work.click()
            let all = window.checkBoxes["All calendars in Work Account"]
            XCTAssertEqual(checkboxValue(all), 1)
            for name in ["Work", "Team Meetings", "Project Reviews"] {
                XCTAssertTrue(window.checkBoxes[name].exists)
            }
            XCTAssertFalse(window.checkBoxes["Sample calendar"].exists)
            XCTAssertFalse(window.checkBoxes["Calendar 2"].exists)
            capture(window, "Marketing fixture expanded \(appearance)")
            window.checkBoxes["Work"].click()
            XCTAssertEqual(checkboxValue(all), 2)
            capture(window, "Marketing fixture mixed \(appearance)")
            let search = window.textFields["Search calendars"]
            search.click()
            search.typeText("Team Meetings")
            XCTAssertFalse(window.checkBoxes["Work"].exists)
            XCTAssertEqual(checkboxValue(all), 2)
            all.click()
            XCTAssertTrue(window.staticTexts["8 selected"].exists)
            all.click()
            XCTAssertTrue(window.staticTexts["5 selected"].exists)
            XCTAssertEqual(checkboxValue(all), 0)
            all.click()
            XCTAssertTrue(window.staticTexts["8 selected"].exists)
            search.click()
            search.typeKey("a", modifierFlags: .command)
            search.typeKey(.delete, modifierFlags: [])
            all.click()
            XCTAssertEqual(checkboxValue(all), 0)
            all.typeKey(.space, modifierFlags: [])
            XCTAssertEqual(checkboxValue(all), 1)
            XCTAssertTrue(window.staticTexts["8 selected"].exists)
            work.click()
            for (account, names) in [("Personal Account", ["Personal", "Family", "Birthdays"]), ("Subscribed Calendars", ["Holidays", "Travel"])] {
                window.staticTexts[account].click()
                let bulk = window.checkBoxes["All calendars in \(account)"]
                for name in names { XCTAssertTrue(window.checkBoxes[name].exists) }
                bulk.click()
                XCTAssertEqual(checkboxValue(bulk), 0)
                XCTAssertTrue(window.staticTexts["\(8 - names.count) selected"].exists)
                window.checkBoxes[names[0]].click()
                XCTAssertEqual(checkboxValue(bulk), 2)
                bulk.click()
                XCTAssertEqual(checkboxValue(bulk), 1)
                window.staticTexts[account].click()
            }
            // Preserve an intentionally empty selection across the same isolated launch session.
            for account in ["Work Account", "Personal Account", "Subscribed Calendars"] {
                window.staticTexts[account].click()
                window.checkBoxes["All calendars in \(account)"].click()
                window.staticTexts[account].click()
            }
            XCTAssertTrue(window.staticTexts["0 selected"].exists)
            app.terminate()
            let restored = openAccounts(appearance: appearance, extra: args, scale: false)
            let restoredWindow = restored.windows["Accounts & Calendars"]
            restoredWindow.buttons["Visible calendars"].click()
            XCTAssertTrue(restoredWindow.staticTexts["0 selected"].exists)
            restoredWindow.staticTexts["Work Account"].click()
            XCTAssertEqual(checkboxValue(restoredWindow.checkBoxes["All calendars in Work Account"]), 0)
            restored.terminate()
        }
    }

    func testNormalSampleRetainsGenericNames() throws {
        let app = openAccounts(appearance: "Aqua", scale: false)
        let window = app.windows["Accounts & Calendars"]
        window.buttons["Visible calendars"].click()
        XCTAssertTrue(window.staticTexts["1 selected"].exists)
        window.staticTexts["Sample account 1"].click()
        XCTAssertTrue(window.checkBoxes["Sample calendar"].exists)
        XCTAssertFalse(window.staticTexts["Work Account"].exists)
        let all = window.checkBoxes["All calendars in Sample account 1"]
        all.click()
        XCTAssertEqual(checkboxValue(all), 0)
        all.click()
        XCTAssertEqual(checkboxValue(all), 1)
        app.terminate()
    }

    func testMarketingAgendaAndFreshSession() throws {
        for sessionArguments in [[], ["--test-session", UUID().uuidString]] {
            let app = XCUIApplication()
            app.launchArguments = ["--sample", "--show-agenda", "--marketing-fixtures"] + sessionArguments
            app.launch()
            app.activate()
            if !app.buttons["Next day"].waitForExistence(timeout: 2) {
                app.statusItems.firstMatch.click()
                app.activate()
            }
            XCTAssertTrue(app.buttons["Open notes for Product conversation"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["Join Google Meet"].isEnabled)
            app.buttons["Open notes for Product conversation"].click()
            XCTAssertTrue(app.textViews["Meeting notes"].waitForExistence(timeout: 3))
            XCTAssertEqual(app.textViews["Meeting notes"].value as? String, "")
            XCTAssertTrue(app.buttons["Export Markdown"].exists)
            XCTAssertFalse(app.buttons["Clean Up"].exists)
            XCTAssertFalse(app.buttons["History & Context"].exists)
            app.terminate()
        }
    }

    func testAllCheckboxMouseAndKeyboardFocusAcrossAppearances() throws {
        continueAfterFailure = false
        for appearance in ["Aqua", "DarkAqua"] {
            let app = openAccounts(appearance: appearance, extra: ["--marketing-fixtures", "--test-session", UUID().uuidString], scale: false)
            let window = app.windows["Accounts & Calendars"]
            window.buttons["Visible calendars"].click()
            window.staticTexts["Work Account"].click()
            let all = window.checkBoxes["All calendars in Work Account"]
            let work = window.checkBoxes["Work"]
            XCTAssertEqual(checkboxValue(all), 1)
            let originalFrame = all.frame
            work.click()
            XCTAssertEqual(checkboxValue(all), 2)
            all.click()
            XCTAssertEqual(checkboxValue(all), 1)
            XCTAssertEqual(all.label, "All calendars in Work Account")
            let mouse = try focusRingPixels(window: window, control: all)
            capture(window, "All checkbox mouse focus \(appearance)")

            // Keyboard use after a mouse click keeps first-responder access and reveals its ring.
            all.typeKey(.space, modifierFlags: [])
            XCTAssertEqual(checkboxValue(all), 0)
            let keyboard = try focusRingPixels(window: window, control: all)
            let keyboardDifference = differingFocusPixels(mouse, keyboard)
            capture(window, "All checkbox keyboard focus \(appearance)")
            XCTAssertGreaterThan(keyboardDifference, 20, "Keyboard focus must have a visible native ring")
            XCTAssertEqual(all.frame, originalFrame, "Focus feedback must not change layout geometry")

            all.click()
            XCTAssertEqual(checkboxValue(all), 1)
            let mouseAgain = try focusRingPixels(window: window, control: all)
            XCTAssertLessThan(differingFocusPixels(mouse, mouseAgain), max(10, keyboardDifference / 4), "Returning to mouse use removes the keyboard outline")
            capture(window, "All checkbox mouse focus restored \(appearance)")
            XCTAssertEqual(all.frame, originalFrame)

            // Tab away and back must restore native keyboard focus without changing selection.
            window.typeKey(.tab, modifierFlags: [])
            window.typeKey(.tab, modifierFlags: .shift)
            let tabbed = try focusRingPixels(window: window, control: all)
            capture(window, "All checkbox Tab focus \(appearance)")
            XCTAssertGreaterThan(differingFocusPixels(mouse, tabbed), 20)
            all.typeKey(.space, modifierFlags: [])
            XCTAssertEqual(checkboxValue(all), 0)
            all.typeKey(.space, modifierFlags: [])
            XCTAssertEqual(checkboxValue(all), 1)
            app.terminate()
        }
    }

    func testAllCheckboxUsesCalendarCheckboxFillAcrossAppearances() throws {
        continueAfterFailure = false
        for appearance in ["Aqua", "DarkAqua"] {
            let app = openAccounts(appearance: appearance, extra: ["--marketing-fixtures", "--test-session", UUID().uuidString], scale: false)
            let window = app.windows["Accounts & Calendars"]
            window.buttons["Visible calendars"].click()
            let heading = window.staticTexts["Work Account"]
            heading.click()
            let all = window.checkBoxes["All calendars in Work Account"]
            let work = window.checkBoxes["Work"]
            let expected = try checkboxFill(work)
            try assertCheckboxFill(all, matches: expected)
            all.click()
            all.click()
            try assertCheckboxFill(all, matches: expected)
            capture(window, "Matching All checkbox fill \(appearance)")
            work.click()
            XCTAssertEqual(checkboxValue(all), 2)
            try assertCheckboxFill(all, matches: expected)
            app.terminate()
        }
    }

    private func assertCheckboxFill(_ checkbox: XCUIElement, matches expected: Int, file: StaticString = #filePath, line: UInt = #line) throws {
        let actual = try checkboxFill(checkbox)
        // AppKit and SwiftUI can differ by a rounding level in their native bezel rasterization.
        for shift in [16, 8, 0] {
            XCTAssertEqual(Double((actual >> shift) & 255), Double((expected >> shift) & 255), accuracy: 2, file: file, line: line)
        }
    }

    private func checkboxFill(_ checkbox: XCUIElement) throws -> Int {
        let frame = checkbox.frame
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: checkbox.screenshot().pngRepresentation))
        let scale = Double(bitmap.pixelsWide) / frame.width
        var frequencies: [Int: Int] = [:]
        // Only the native checkbox bezel, excluding labels and calendar-color dots.
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<min(bitmap.pixelsWide, Int(18 * scale)) {
                let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                let r = Int((color.redComponent * 255).rounded())
                let g = Int((color.greenComponent * 255).rounded())
                let b = Int((color.blueComponent * 255).rounded())
                if b > r + 10 && r > g + 10 {
                    frequencies[(r << 16) | (g << 8) | b, default: 0] += 1
                }
            }
        }
        return try XCTUnwrap(frequencies.max(by: { $0.value < $1.value })?.key)
    }

    // Compare only the ring's outside band: changing the checkmark cannot satisfy this assertion.
    private func focusRingPixels(window: XCUIElement, control: XCUIElement) throws -> [SIMD3<Double>] {
        let windowFrame = window.frame
        let frame = control.frame.offsetBy(dx: -windowFrame.minX, dy: -windowFrame.minY)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: window.screenshot().pngRepresentation))
        let scale = Double(bitmap.pixelsWide) / windowFrame.width
        let band = frame.insetBy(dx: -5, dy: -5)
        var pixels: [SIMD3<Double>] = []
        for y in Int(band.minY * scale)..<Int(band.maxY * scale) {
            for x in Int(band.minX * scale)..<Int(band.maxX * scale) {
                if frame.contains(CGPoint(x: (Double(x) + 0.5) / scale, y: (Double(y) + 0.5) / scale)) { continue }
                let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                pixels.append(SIMD3(color.redComponent, color.greenComponent, color.blueComponent))
            }
        }
        return pixels
    }

    private func differingFocusPixels(_ first: [SIMD3<Double>], _ second: [SIMD3<Double>]) -> Int {
        XCTAssertEqual(first.count, second.count)
        return zip(first, second).filter { a, b in
            abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z) > 0.15
        }.count
    }

    private func openAccounts(appearance: String, extra: [String] = [], scale: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--sample", "--show-agenda", "-NSAppearance", appearance, "-AppleKeyboardUIMode", "3"] + (scale ? ["--fifty-calendars"] : []) + extra
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

    private func checkboxValue(_ checkbox: XCUIElement) -> Int? {
        if let value = checkbox.value as? NSNumber { return value.intValue }
        return Int(checkbox.value as? String ?? "")
    }

    private func capture(_ element: XCUIElement, _ name: String) {
        let attachment = XCTAttachment(screenshot: element.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
