import AppKit
import FirebaseCore
import Foundation
import Testing
@testable import Meetrail

@MainActor struct AnalyticsTests {
    @Test func exactCatalogAndAllParameterVariants() {
        let catalog: [(AnalyticsEvent, String)] = [
            (.onboardingStarted, "onboarding_started"), (.onboardingConnectTapped, "onboarding_connect_tapped"),
            (.onboardingPermissionResult(.granted), "onboarding_permission_result"),
            (.onboardingCompleted, "onboarding_completed"), (.onboardingSkipped, "onboarding_skipped"),
            (.menubarAgendaOpened, "menubar_agenda_opened"), (.agendaDayChanged(.previous), "agenda_day_changed"),
            (.agendaMeetingOpened, "agenda_meeting_opened"), (.agendaJoinTapped, "agenda_join_tapped"),
            (.agendaRecoveredNoteOpened, "agenda_recovered_note_opened"), (.notesOpened, "notes_opened"),
            (.notesEditStarted, "notes_edit_started"), (.notesJoinTapped, "notes_join_tapped"),
            (.notesExportTapped, "notes_export_tapped"), (.notesExportResult(.success), "notes_export_result"),
            (.accountsOpened, "accounts_opened"), (.accountsConnectTapped, "accounts_connect_tapped"),
            (.accountsConnectResult(.success), "accounts_connect_result"), (.calendarsOpened, "calendars_opened"),
            (.calendarsSearchUsed, "calendars_search_used"), (.calendarsVisibilityChanged(true), "calendars_visibility_changed"),
            (.calendarsAllChanged(.all), "calendars_all_changed"), (.settingsOpened, "settings_opened"),
            (.settingsRemindersChanged(true), "settings_reminders_changed"), (.settingsLaunchAtLoginChanged(true), "settings_launch_at_login_changed")
        ]
        #expect(catalog.count == 25 && Set(catalog.map { $0.1 }).count == 25)
        for (event, name) in catalog {
            #expect(event.name == name)
            #expect(name.count <= 40 && name.range(of: "^[a-z][a-z0-9]*(?:_[a-z0-9]+)+$", options: .regularExpression) != nil)
            #expect(!["firebase_", "google_", "ga_"].contains(where: name.hasPrefix))
        }
        for value in AnalyticsEvent.PermissionResult.allCases {
            #expect(AnalyticsEvent.onboardingPermissionResult(value).parameters == ["result": .string(value.rawValue)])
        }
        for value in AnalyticsEvent.ConnectionResult.allCases {
            #expect(AnalyticsEvent.accountsConnectResult(value).parameters == ["result": .string(value.rawValue)])
        }
        for value in AnalyticsEvent.ExportResult.allCases {
            #expect(AnalyticsEvent.notesExportResult(value).parameters == ["result": .string(value.rawValue)])
        }
        for value in AnalyticsEvent.Direction.allCases {
            #expect(AnalyticsEvent.agendaDayChanged(value).parameters == ["direction": .string(value.rawValue)])
        }
        for value in AnalyticsEvent.SelectionState.allCases {
            #expect(AnalyticsEvent.calendarsAllChanged(value).parameters == ["selection_state": .string(value.rawValue)])
        }
        for enabled in [false, true] {
            for event in [AnalyticsEvent.calendarsVisibilityChanged(enabled), .settingsRemindersChanged(enabled), .settingsLaunchAtLoginChanged(enabled)] {
                #expect(event.parameters == ["enabled": .integer(enabled ? 1 : 0)])
            }
        }
        let parameterizedNames = Set(["onboarding_permission_result", "agenda_day_changed", "notes_export_result", "accounts_connect_result", "calendars_visibility_changed", "calendars_all_changed", "settings_reminders_changed", "settings_launch_at_login_changed"])
        for (event, _) in catalog {
            #expect(event.parameters.count <= 1)
            if !parameterizedNames.contains(event.name) { #expect(event.parameters.isEmpty) }
            for (key, value) in event.parameters {
                #expect(["result", "direction", "enabled", "selection_state"].contains(key))
                switch value {
                case .integer(let integer): #expect([0, 1].contains(integer))
                case .string(let string):
                    #expect(["granted", "denied", "error", "success", "cancelled", "previous", "next", "today", "all", "none"].contains(string))
                }
            }
        }
    }

    @Test func launchIsolationAndUnconfiguredAdapter() {
        #expect(FirebaseApp.app() == nil) // Actual XCTest application host never configured Firebase.
        #expect(AnalyticsLaunchPolicy.usesLiveAnalytics(arguments: [], isTesting: false))
        for arguments in [[], ["--sample"], ["--marketing-fixtures"], ["--all-features"], ["--test-session", "private-value"], ["--sample", "--all-features", "-FIRDebugEnabled"]] {
            #expect(!AnalyticsLaunchPolicy.usesLiveAnalytics(arguments: arguments, isTesting: true))
            if !arguments.isEmpty { #expect(!AnalyticsLaunchPolicy.usesLiveAnalytics(arguments: arguments, isTesting: false)) }
        }
        // Even a premature call during composition cannot enter the SDK.
        FirebaseAnalyticsAdapter().track(.notesOpened)
        NoOpAnalyticsTracker().track(.notesOpened)
        #expect(FirebaseApp.app() == nil)
    }

    @Test func onboardingPresentationCompletionAndExplicitSkip() throws {
        let spy = SpyAnalyticsTracker()
        let fixture = try TestComposition(firstRun: true, analytics: spy)
        defer { fixture.clearPreferences() }
        let model = fixture.container.onboarding
        model.presented(); model.presented()
        let resumed = OnboardingViewModel(preferences: fixture.preferences, accounts: fixture.container.accounts, analytics: spy, closeWindow: {})
        resumed.presented()
        #expect(spy.events == [.onboardingStarted])
        for _ in 0..<5 { model.next() }
        #expect(spy.events == [.onboardingStarted, .onboardingCompleted])
        fixture.preferences.onboardingProgress = OnboardingProgress()
        let skipped = OnboardingViewModel(preferences: fixture.preferences, accounts: fixture.container.accounts, analytics: spy, closeWindow: {})
        skipped.skip(); skipped.skip()
        #expect(spy.events.last == .onboardingSkipped)
        #expect(spy.events.filter { $0 == .onboardingSkipped }.count == 1)
        fixture.preferences.onboardingProgress = OnboardingProgress()
        let closed = OnboardingViewModel(preferences: fixture.preferences, accounts: fixture.container.accounts, analytics: spy, closeWindow: {})
        spy.reset(); closed.windowClosed()
        #expect(spy.events.isEmpty)
    }

    @Test func permissionAndConnectionResultsAreActualOutcomes() async throws {
        for fromOnboarding in [false, true] {
            for outcome in PermissionProvider.Outcome.allCases {
                let spy = SpyAnalyticsTracker()
                let provider = PermissionProvider(outcome: outcome)
                let coordinator = CalendarAccountCoordinator(providers: [provider])
                let fixture = try TestComposition()
                defer { fixture.clearPreferences() }
                let visibility = CalendarVisibilityUseCase(preferences: fixture.preferences, coordinator: coordinator)
                let model = CalendarAccountsViewModel(coordinator: coordinator, visibility: visibility, permissionSettings: fixture.actions, access: fixture.container.access, analytics: spy)
                await model.connect(.system, fromOnboarding: fromOnboarding)
                let expected: [AnalyticsEvent]
                switch outcome {
                case .granted: expected = fromOnboarding ? [.onboardingConnectTapped, .onboardingPermissionResult(.granted)] : [.accountsConnectTapped, .accountsConnectResult(.success)]
                case .denied: expected = fromOnboarding ? [.onboardingConnectTapped, .onboardingPermissionResult(.denied)] : [.accountsConnectTapped, .accountsConnectResult(.denied)]
                case .error: expected = fromOnboarding ? [.onboardingConnectTapped, .onboardingPermissionResult(.error)] : [.accountsConnectTapped, .accountsConnectResult(.error)]
                }
                #expect(spy.events == expected)
                spy.reset(); model.refresh(); await model.connect(.google)
                #expect(spy.events.isEmpty)
            }
        }
    }

    @Test func agendaRefreshDayNavigationAndMeetingActions() async throws {
        let spy = SpyAnalyticsTracker()
        let fixture = try TestComposition(analytics: spy)
        defer { fixture.clearPreferences() }
        let agenda = fixture.container.agenda!
        await agenda.load(); await agenda.load(); agenda.notesChanged(); agenda.today(); agenda.showToday()
        #expect(spy.events.isEmpty)
        agenda.move(-1); agenda.move(1); agenda.move(0); agenda.move(1); agenda.today(); agenda.today()
        #expect(spy.events == [.agendaDayChanged(.previous), .agendaDayChanged(.next), .agendaDayChanged(.next), .agendaDayChanged(.today)])
        spy.reset()
        let meeting = try #require(agenda.meetings.first)
        agenda.select(meeting)
        let note = try #require(agenda.selected)
        agenda.back(); agenda.selectRecovered(note)
        if let link = meeting.links.first { agenda.join(link) }
        #expect(spy.events == [.agendaMeetingOpened, .agendaRecoveredNoteOpened, .agendaJoinTapped])
        #expect(fixture.actions.opened.count == 1)
    }

    @Test func editorSessionsAndKeystrokesDoNotSpamOrSendContent() async throws {
        let spy = SpyAnalyticsTracker()
        let fixture = try TestComposition(analytics: spy)
        defer { fixture.clearPreferences() }
        await fixture.container.agenda.load()
        fixture.container.agenda.select(try #require(fixture.container.agenda.meetings.first))
        let model = try #require(fixture.container.agenda.detail)
        spy.reset()
        let session = UUID()
        model.editorPresented(session); model.editorPresented(session); model.reloadContext()
        model.updateText(model.text, session: session)
        #expect(spy.events == [.notesOpened])
        for text in ["Private synthetic title", "private@example.invalid", "https://example.invalid/private", "Synthetic note body"] { model.updateText(text, session: session) }
        #expect(spy.events == [.notesOpened, .notesEditStarted])
        #expect(try fixture.store.fetchNote(id: model.note.id)?.text == "Synthetic note body")
        model.editorDismissed(session); model.editorPresented(session); model.updateText("Next edit", session: session)
        #expect(spy.events == [.notesOpened, .notesEditStarted, .notesOpened, .notesEditStarted])
        if let link = model.meeting?.links.first { model.join(link) }
        #expect(spy.events.last == .notesJoinTapped)
        #expect(spy.events.allSatisfy { $0.parameters.isEmpty })
    }

    @Test func exportsClassifySuccessCancellationAndError() async throws {
        let spy = SpyAnalyticsTracker()
        let fixture = try TestComposition(analytics: spy)
        defer { fixture.clearPreferences() }
        await fixture.container.agenda.load()
        fixture.container.agenda.select(try #require(fixture.container.agenda.meetings.first))
        let model = try #require(fixture.container.agenda.detail)
        spy.reset()
        await model.exportCurrentDraft()
        fixture.actions.exportOutcome = .cancelled
        await model.exportCurrentDraft()
        fixture.actions.exportError = CocoaError(.fileWriteNoPermission)
        await model.exportCurrentDraft()
        #expect(spy.events == [.notesExportTapped, .notesExportResult(.success), .notesExportTapped, .notesExportResult(.cancelled), .notesExportTapped, .notesExportResult(.error)])
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let document = MarkdownDocument(text: "# Synthetic note\n\nExact contents.\n", filename: "synthetic.md")
        let url = folder.appendingPathComponent(document.filename)
        #expect(try MarkdownExporter().write(document, to: url) == .success)
        #expect(try String(contentsOf: url, encoding: .utf8) == document.text)
        #expect(throws: (any Error).self) { try MarkdownExporter().write(document, to: folder.appendingPathComponent("missing/note.md")) }
    }

    @Test func accountPagesSearchAndWholeAccountSelection() async throws {
        let spy = SpyAnalyticsTracker()
        let provider = try #require(SampleCalendarGateway.forLaunch(arguments: ["--sample", "--marketing-fixtures"]))
        let fixture = try TestComposition(analytics: spy, provider: provider)
        defer { fixture.clearPreferences() }
        await fixture.container.agenda.load()
        let model = fixture.container.accounts
        model.pagePresented(); model.pagePresented(); model.refresh()
        model.page = .calendars; model.pagePresented()
        model.search = " "; model.search = "T"; model.search = "Te"; model.search = "Team"
        #expect(spy.events == [.accountsOpened, .calendarsOpened, .calendarsSearchUsed])
        let group = try #require(model.groups.first)
        model.selectGroup(group.id, visible: false)
        #expect(model.selectedIDs.isDisjoint(with: Set(model.catalog.calendars.filter { $0.accountID == group.id }.map(\.id))))
        model.selectGroup(group.id, visible: true)
        let id = try #require(group.calendars.first?.id)
        model.setCalendar(id, visible: false); model.setCalendar(id, visible: false); model.setCalendar(id, visible: true)
        #expect(Array(spy.events.suffix(4)) == [.calendarsAllChanged(.none), .calendarsAllChanged(.all), .calendarsVisibilityChanged(false), .calendarsVisibilityChanged(true)])
        spy.reset(); model.search = ""; model.search = "Another private query"
        model.pageDismissed(); model.pagePresented()
        #expect(spy.events == [.calendarsSearchUsed, .calendarsOpened])
        #expect(!String(describing: spy.events).contains("private"))
    }

    @Test func settingsTracksEffectiveChangesAndRejectedOSChanges() async throws {
        let fixture = try TestComposition()
        defer { fixture.clearPreferences() }
        let spy = SpyAnalyticsTracker()
        let service = OutcomePreferences()
        let model = SettingsViewModel(service: service, actions: fixture.actions, access: fixture.container.access, analytics: spy, onChanged: {})
        model.presented(); model.presented(); model.refresh()
        await model.changeReminders(true); model.setLaunchAtLogin(true)
        #expect(spy.events == [.settingsOpened])
        service.accept = true
        await model.changeReminders(true); await model.changeReminders(true)
        model.setLaunchAtLogin(true); model.setLaunchAtLogin(true)
        await model.changeReminders(false); model.setLaunchAtLogin(false)
        #expect(spy.events == [.settingsOpened, .settingsRemindersChanged(true), .settingsLaunchAtLoginChanged(true), .settingsRemindersChanged(false), .settingsLaunchAtLoginChanged(false)])
        model.dismissed(); model.presented()
        #expect(spy.events.filter { $0 == .settingsOpened }.count == 2)
    }

    @Test func nativePopoverAndAccountsPresentationDoNotRepeatOnRefresh() async throws {
        let spy = SpyAnalyticsTracker()
        let fixture = try TestComposition(analytics: spy)
        defer { fixture.clearPreferences() }
        let windows = AppWindowCoordinator(container: fixture.container)
        windows.start()
        defer { windows.closeAgenda() }
        // Native status-item scene registration completes on a later run-loop turn.
        try await Task.sleep(for: .milliseconds(150))
        windows.showAgenda()
        try await Task.sleep(for: .milliseconds(150))
        windows.showAgenda()
        await fixture.container.agenda.load()
        #expect(spy.events == [.menubarAgendaOpened])
        windows.closeAgenda()
        try await Task.sleep(for: .milliseconds(150))
        windows.showAgenda()
        try await Task.sleep(for: .milliseconds(150))
        #expect(spy.events == [.menubarAgendaOpened, .menubarAgendaOpened])
        windows.closeAgenda(); spy.reset()
        windows.showAccounts(); windows.showAccounts(); fixture.container.accounts.refresh()
        #expect(spy.events == [.accountsOpened])
        fixture.container.accounts.page = .calendars
        windows.showAccounts()
        #expect(spy.events == [.accountsOpened, .calendarsOpened])
        let accounts = try #require(NSApp.windows.first { $0.title == "Accounts & Calendars" })
        accounts.close(); windows.showAccounts(); accounts.close()
        #expect(spy.events == [.accountsOpened, .calendarsOpened, .calendarsOpened])
    }

    @Test func nativeSettingsWindowCloseReopenAndRefocus() throws {
        let spy = SpyAnalyticsTracker()
        let fixture = try TestComposition(analytics: spy)
        defer { fixture.clearPreferences() }
        let model = fixture.container.settings
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 240), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = WindowPresentationObserver.ObserverView(onPresented: model.presented, onDismissed: model.dismissed)
        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
        #expect(spy.events == [.settingsOpened])
        window.close(); window.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
        #expect(spy.events == [.settingsOpened, .settingsOpened])
    }

    @Test func disabledOperationsEmitNothingAndPreserveData() async throws {
        let spy = SpyAnalyticsTracker()
        let fixture = try TestComposition(features: FeatureToggles(enabled: []), analytics: spy)
        defer { fixture.clearPreferences() }
        await fixture.container.agenda.load()
        fixture.container.agenda.select(try #require(fixture.container.agenda.meetings.first))
        let model = try #require(fixture.container.agenda.detail)
        model.updateText("Preserved synthetic draft")
        spy.reset()
        model.refine(.cleanUp); model.refine(.structure); model.float(); model.showHistoryAndContext()
        await model.exportCurrentDraft()
        fixture.container.settings.setLaunchAtLogin(true)
        await fixture.container.settings.changeReminders(true)
        fixture.container.settings.showAccounts(); fixture.container.agenda.connect()
        fixture.container.accounts.pagePresented()
        fixture.container.accounts.search = "Private synthetic search"
        await fixture.container.accounts.connectSystem()
        fixture.container.accounts.requestConnection(.system)
        fixture.container.accounts.setCalendar(CalendarID(rawValue: "sample"), visible: false)
        if let id = fixture.container.accounts.catalog.accounts.first?.id { fixture.container.accounts.selectGroup(id, visible: false) }
        #expect(spy.events.isEmpty && fixture.actions.exports.isEmpty && fixture.actions.accountWindows == 0)
        #expect(try fixture.store.fetchNote(id: model.note.id)?.text == "Preserved synthetic draft")
    }
}

@MainActor private final class PermissionProvider: CalendarProvider {
    enum Outcome: CaseIterable { case granted, denied, error }
    let kind = CalendarProviderKind.system
    var connectionState = AccountConnectionState.notConnected
    var onChange: (() -> Void)?
    let outcome: Outcome

    init(outcome: Outcome) { self.outcome = outcome }

    func catalog() -> CalendarCatalog { .empty }

    func connect() async throws {
        switch outcome {
        case .granted: connectionState = .connected
        case .denied: connectionState = .permissionDenied
        case .error: throw CocoaError(.fileReadNoPermission)
        }
    }

    func events(in interval: DateInterval, visibleCalendarIDs: Set<CalendarID>) async throws -> [CalendarEvent] { [] }
}

@MainActor private final class OutcomePreferences: PreferencesService {
    var aiEnabled = false
    var remindersEnabled = false
    var launchAtLogin = false
    var message: String?
    var accept = false

    func setLaunchAtLogin(_ value: Bool) { if accept { launchAtLogin = value } }

    func setReminders(_ enabled: Bool) async { if accept { remindersEnabled = enabled } }

    func schedule(_ meetings: [Meeting], now: Date) async {}
}
