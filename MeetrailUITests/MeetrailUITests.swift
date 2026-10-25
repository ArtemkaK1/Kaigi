import XCTest
import AppKit

@MainActor final class MeetrailUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--sample", "--show-agenda"] + extra
        app.launch()
        app.activate()
        // XCTest may activate its runner after launch; reopen only if that dismissed the panel.
        if !app.windows["Welcome to Meetrail"].exists && !app.buttons["Next day"].waitForExistence(timeout: 2) {
            app.statusItems.firstMatch.click()
            app.activate()
        }
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
    func testFirstStatusClickAfterLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--sample", "--fifty-calendars", "--startup-timing"]
        app.launch()
        XCTAssertTrue(app.statusItems.firstMatch.waitForExistence(timeout: 8))
        let began = ProcessInfo.processInfo.systemUptime
        app.statusItems.firstMatch.click()
        XCTAssertTrue(app.buttons["Next day"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.popovers["Meetrail agenda"].exists)
        print("MEETRAIL_FIRST_CLICK_UI seconds=\(ProcessInfo.processInfo.systemUptime - began)")
        app.terminate()
    }
    func testKeyboardNavigationAndMeetingHistory() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["Next day"].waitForExistence(timeout: 8))
        app.typeKey(.rightArrow, modifierFlags: .command)
        app.typeKey("t", modifierFlags: .command)
        app.buttons["Open notes for Weekly planning"].click()
        let editor = app.textViews["Meeting notes"]
        editor.click(); editor.typeText("Unresolved: review scope")
        app.buttons["Meeting history"].click()
        XCTAssertTrue(app.staticTexts["No other saved occurrences"].exists)
        app.buttons["Back to agenda"].click()
        XCTAssertFalse(app.buttons["Saved notes"].exists)
        app.buttons["Open notes for Weekly planning"].click()
        XCTAssertEqual(app.textViews["Meeting notes"].value as? String, "Unresolved: review scope")
    }
    func testEmptyStateAndStatusItemDismissal() throws {
        let app = launch(["--empty"])
        let empty = app.staticTexts["Room to focus"]
        XCTAssertTrue(empty.waitForExistence(timeout: 8))
        app.statusItems.firstMatch.click()
        XCTAssertFalse(empty.exists)
        app.statusItems.firstMatch.click()
        XCTAssertTrue(empty.waitForExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(empty.exists)
    }
    func testLightAndDarkAgenda() throws {
        var materialBrightness: [String: CGFloat] = [:]
        for appearance in ["Aqua", "DarkAqua"] {
            let app = launch(["-NSAppearance", appearance])
            XCTAssertTrue(app.buttons["Next day"].waitForExistence(timeout: 8))
            XCTAssertTrue(app.buttons["Open notes for Design review"].exists)
            let join = app.buttons["Join Google Meet"]
            let links = app.menuButtons["Links"]
            XCTAssertEqual(join.frame.width, links.frame.width, accuracy: 0.5)
            XCTAssertEqual(join.frame.height, links.frame.height, accuracy: 0.5)
            XCTAssertGreaterThanOrEqual(join.frame.width, 64)
            XCTAssertGreaterThanOrEqual(join.frame.height, 32)
            XCTAssertGreaterThanOrEqual(app.buttons["Today"].frame.height, 32)
            let buttonImage = try XCTUnwrap(NSBitmapImageRep(data: join.screenshot().pngRepresentation))
            let accent = try XCTUnwrap(buttonImage.colorAt(x: buttonImage.pixelsWide / 2, y: buttonImage.pixelsHigh - 4)?.usingColorSpace(.sRGB))
            XCTAssertGreaterThan(accent.redComponent, accent.greenComponent + 0.1)
            XCTAssertGreaterThan(accent.redComponent, accent.blueComponent + 0.2)
            let panel = app.descendants(matching: .any).matching(identifier: "Meetrail agenda").firstMatch
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: panel.screenshot().pngRepresentation))
            let color = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 8)?.usingColorSpace(.sRGB))
            let brightness = (color.redComponent + color.greenComponent + color.blueComponent) / 3
            materialBrightness[appearance] = brightness
            if appearance == "Aqua" { XCTAssertGreaterThan(brightness, 0.7) }
            else { XCTAssertLessThan(brightness, 0.5, "Native dark material may show the desktop through vibrancy") }
            app.terminate()
        }
        XCTAssertGreaterThan(try XCTUnwrap(materialBrightness["Aqua"]), try XCTUnwrap(materialBrightness["DarkAqua"]) + 0.3)
    }
    func testNativeSettingsSceneOpensAccountManagement() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["Next day"].waitForExistence(timeout: 8))
        app.typeKey(",", modifierFlags: .command)
        let accounts = app.buttons["Accounts & Calendars"]
        XCTAssertTrue(accounts.waitForExistence(timeout: 5))
        accounts.click()
        XCTAssertTrue(app.windows["Accounts & Calendars"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Connected through macOS"].exists)
    }
    func testOnboardingConnectionSelectionAndCompletion() throws {
        let app = launch(["--onboarding", "--fifty-calendars"])
        let window = app.windows["Welcome to Meetrail"]
        XCTAssertTrue(window.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Next day"].exists)
        XCTAssertLessThan(window.frame.height, 400, "Welcome fits its content")
        window.buttons["Continue"].click()
        XCTAssertTrue(window.staticTexts["Coming Soon"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertEqual(window.staticTexts.matching(NSPredicate(format: "value == %@ OR label == %@", "Coming Soon", "Coming Soon")).count, 5)
        window.buttons["Connect Apple / System Calendars"].click()
        XCTAssertTrue(window.staticTexts["Connected through macOS"].waitForExistence(timeout: 3))
        window.buttons["Continue"].click()
        XCTAssertTrue(window.staticTexts["50 selected"].exists)
        let search = window.textFields["Search calendars"]
        search.click(); search.typeText("Calendar 42")
        XCTAssertTrue(window.checkBoxes["Calendar 42"].waitForExistence(timeout: 3))
        window.checkBoxes["Calendar 42"].click()
        XCTAssertTrue(window.staticTexts["49 selected"].exists)
        window.buttons["Continue"].click()
        XCTAssertTrue(window.staticTexts["You're ready"].exists)
        XCTAssertLessThan(window.frame.height, 320, "Ready does not retain the calendar viewport")
        window.buttons["Open Meetrail"].click()
        XCTAssertFalse(window.exists)
        XCTAssertTrue(app.buttons["Next day"].waitForExistence(timeout: 3))
    }
    func testOnboardingSkipPersistsAcrossRelaunch() throws {
        let session = UUID().uuidString
        let args = ["--onboarding", "--test-session", session]
        var app = launch(args)
        XCTAssertTrue(app.windows["Welcome to Meetrail"].waitForExistence(timeout: 8))
        app.buttons["Continue"].click(); app.buttons["Skip for now"].click()
        app.terminate(); app = launch(args)
        XCTAssertTrue(app.buttons["Next day"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.windows["Welcome to Meetrail"].exists)
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["Accounts & Calendars"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Review onboarding"].exists)
        app.buttons["Accounts & Calendars"].click()
        XCTAssertTrue(app.windows["Accounts & Calendars"].waitForExistence(timeout: 3))
    }
    func testCompactOneAndFifteenLongMeetings() throws {
        for count in ["--one-meeting", "--fifteen-meetings"] {
            let app = launch([count, "--long-titles"])
            XCTAssertTrue(app.buttons["Next day"].waitForExistence(timeout: 8))
            let panel = app.descendants(matching: .any).matching(identifier: "Meetrail agenda").firstMatch
            XCTAssertLessThanOrEqual(panel.frame.width, 380)
            XCTAssertGreaterThanOrEqual(panel.frame.width, 320)
            let cards = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open notes for"))
            XCTAssertTrue(cards.firstMatch.exists)
            XCTAssertFalse(app.buttons["Quit"].exists)
            XCTAssertFalse(app.buttons["Saved notes"].exists)
            if count == "--one-meeting" {
                XCTAssertLessThanOrEqual(panel.frame.maxY - cards.firstMatch.frame.maxY, 32 + 8, "Compact footer allowance plus the requested 8 pt bottom padding")
                XCTAssertLessThan(panel.frame.height, 240, "The panel fits one rendered card")
            }
            if count == "--fifteen-meetings" { app.scrollViews.firstMatch.swipeUp(); XCTAssertTrue(cards.count > 1) }
            let attachment = XCTAttachment(screenshot: panel.screenshot()); attachment.name = "Synthetic compact \(count)"; attachment.lifetime = .keepAlways; add(attachment)
            app.terminate()
        }
    }
    func testScaledTextInConstrainedPanel() throws {
        let normal = launch(["--one-meeting", "--long-titles"])
        let normalCard = normal.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open notes for")).firstMatch
        XCTAssertTrue(normalCard.waitForExistence(timeout: 8))
        let normalHeight = normalCard.frame.height
        normal.terminate()
        let app = launch(["--fifteen-meetings", "--long-titles", "--large-text", "--constrained-height"])
        XCTAssertTrue(app.buttons["Next day"].waitForExistence(timeout: 8))
        let panel = app.descendants(matching: .any).matching(identifier: "Meetrail agenda").firstMatch
        XCTAssertLessThanOrEqual(panel.frame.width, 380)
        XCTAssertLessThanOrEqual(panel.frame.height, 540)
        XCTAssertTrue(app.buttons["Join Google Meet"].exists)
        let enlargedCard = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open notes for")).firstMatch
        XCTAssertGreaterThan(enlargedCard.frame.height, normalHeight)
        enlargedCard.click()
        XCTAssertTrue(app.textViews["Meeting notes"].waitForExistence(timeout: 3))
        let screenshot = XCTAttachment(screenshot: panel.screenshot()); screenshot.name = "Synthetic scaled text constrained panel"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
    func testStatusContextMenuSettingsAndQuit() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["Next day"].waitForExistence(timeout: 8))
        app.statusItems.firstMatch.rightClick()
        XCTAssertTrue(app.statusItems.firstMatch.menuItems["Settings…"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.statusItems.firstMatch.menuItems["Quit Meetrail"].exists)
        app.statusItems.firstMatch.menuItems["Settings…"].click()
        XCTAssertTrue(app.checkBoxes["On-device AI"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.checkBoxes["Remind me 5 minutes before meetings"].exists)
        app.statusItems.firstMatch.rightClick()
        app.statusItems.firstMatch.menuItems["Quit Meetrail"].click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 3))
    }
    func testAIReviewCancelApplyAndDisabledSetting() throws {
        let app = launch(["--mock-ai"])
        app.buttons["Open notes for Product conversation"].click()
        let editor = app.textViews["Meeting notes"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.click(); editor.typeText("Rough synthetic note")
        app.buttons["Clean Up"].click()
        XCTAssertTrue(app.staticTexts["Review changes"].waitForExistence(timeout: 3))
        XCTAssertEqual(editor.value as? String, "Rough synthetic note")
        app.buttons["Cancel"].click()
        XCTAssertEqual(editor.value as? String, "Rough synthetic note")
        app.buttons["Structure"].click()
        XCTAssertTrue(app.buttons["Apply"].waitForExistence(timeout: 3))
        app.buttons["Apply"].click()
        XCTAssertEqual(editor.value as? String, "Reviewed synthetic suggestion.")
        app.buttons["Revisions"].click()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Before AI refinement")).firstMatch.exists)
        app.typeKey(",", modifierFlags: .command)
        app.checkBoxes["On-device AI"].click()
        app.typeKey("w", modifierFlags: .command)
        app.statusItems.firstMatch.click(); app.activate()
        XCTAssertTrue(app.staticTexts["AI is off. Enable it in Settings."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Clean Up"].isEnabled)
    }

    func testProviderStatusColumnsAcrossAppearanceAndTextSizes() throws {
        for (appearance, large) in [("Aqua", false), ("DarkAqua", false), ("DarkAqua", true)] {
            let app = launch(["--onboarding", "--fifty-calendars", "-NSAppearance", appearance] + (large ? ["--large-text"] : []))
            let window = app.windows["Welcome to Meetrail"]
            XCTAssertTrue(window.waitForExistence(timeout: 8))
            window.buttons["Continue"].click()
            let name = window.staticTexts["provider-name-system"]
            let status = window.staticTexts["provider-status-system"]
            XCTAssertTrue(status.waitForExistence(timeout: 3))
            XCTAssertEqual(status.value as? String, "Not connected")
            XCTAssertEqual(name.frame.minX, status.frame.minX, accuracy: 1)
            XCTAssertGreaterThanOrEqual(status.frame.minY, name.frame.maxY)
            window.buttons["Connect Apple / System Calendars"].click()
            XCTAssertTrue(window.staticTexts["Connected through macOS"].waitForExistence(timeout: 3))
            XCTAssertEqual(name.frame.minX, status.frame.minX, accuracy: 1)
            for kind in ["google", "microsoft", "yandex", "zoho", "calDAV"] {
                let title = window.staticTexts["provider-name-\(kind)"]
                let description = window.staticTexts["provider-status-\(kind)"]
                XCTAssertTrue(title.exists && description.exists)
                XCTAssertEqual(title.frame.minX, description.frame.minX, accuracy: 1)
                XCTAssertGreaterThanOrEqual(description.frame.minY, title.frame.maxY)
            }
            let attachment = XCTAttachment(screenshot: window.screenshot())
            attachment.name = "Synthetic provider alignment \(appearance) large=\(large)"; attachment.lifetime = .keepAlways; add(attachment)
            app.terminate()
        }
        let denied = launch(["--onboarding", "--denied-calendar", "--large-text"])
        denied.buttons["Continue"].click()
        let title = denied.staticTexts["provider-name-system"]
        let status = denied.staticTexts["provider-status-system"]
        XCTAssertTrue(status.waitForExistence(timeout: 3))
        XCTAssertEqual(status.value as? String, "Calendar access denied")
        XCTAssertEqual(title.frame.minX, status.frame.minX, accuracy: 1)
        XCTAssertTrue(denied.buttons["Open calendar privacy settings"].exists)
        denied.terminate()
    }
    func testAIReviewErrorDoesNotOfferSaveRetryForSavedNotes() throws {
        let app = launch(["--mock-ai"])
        app.buttons["Open notes for Product conversation"].click()
        let editor = app.textViews["Meeting notes"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.click(); editor.typeText("Synthetic original")
        app.buttons["Clean Up"].click()
        XCTAssertTrue(app.buttons["Apply"].waitForExistence(timeout: 3))
        editor.click(); app.typeKey("a", modifierFlags: .command); editor.typeText("Changed synthetic note")
        app.buttons["Apply"].click()
        XCTAssertTrue(app.staticTexts["Your notes changed. Generate a fresh preview before applying."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Saved locally"].exists)
        XCTAssertFalse(app.buttons["Retry save"].exists)
        app.buttons["Dismiss"].click(); app.buttons["Cancel"].click()
        XCTAssertEqual(editor.value as? String, "Changed synthetic note")
    }

}
