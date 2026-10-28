import Testing
import Foundation
import UserNotifications
@testable import Meetrail

@MainActor struct UICleanupTests {
    @Test func contextWindowSharesDraftAndSynchronizesEarlierNoteEdits() throws {
        let fixture = try TestComposition(); defer { fixture.clearPreferences() }
        let first = KaigiTests().meeting()
        let older = try fixture.store.openNote(for: first)
        _ = try fixture.store.saveDraft(id: older.id, text: "Earlier notes", reason: "Edit")
        _ = try fixture.store.confirmContext(id: older.id, text: "Review scope")
        let next = KaigiTests().meeting(start: first.start.addingTimeInterval(86400))
        let current = try fixture.store.openNote(for: next)
        let model = fixture.container.detail(note: current, meeting: next)
        model.updateText("Current draft")
        model.toggleContext(); model.contextDraft = "Unconfirmed current context"
        model.showHistoryAndContext()
        #expect(fixture.actions.contextWindows == [current.id])
        #expect(model.text == "Current draft" && model.contextDraft == "Unconfirmed current context")
        #expect(try fixture.container.detail(id: current.id) === model)
        model.selectHistory(older.id)
        #expect(model.selectedHistory?.text == "Earlier notes")
        #expect(model.canCarrySelectedHistory)
        model.selectHistory(NoteID(rawValue: UUID()))
        #expect(model.selectedHistoryID == older.id)
        let earlierEditor = try fixture.container.detail(id: older.id)
        earlierEditor.updateText("Updated earlier notes")
        earlierEditor.contextDraft = "Updated confirmed scope"
        earlierEditor.confirmContext()
        #expect(model.selectedHistory?.text == "Updated earlier notes")
        #expect(model.previous.first?.confirmedContext == "Updated confirmed scope")
        #expect(model.contextDraft == "Unconfirmed current context")
        model.carry(try #require(model.previous.first))
        #expect(model.text.hasPrefix("Current draft"))
        #expect(model.text.contains("Updated confirmed scope"))
        model.selectHistory(current.id)
        #expect(model.selectedHistory == nil)
        model.confirmContext()
        #expect(try fixture.store.fetchNote(id: current.id)?.confirmedContext == "Unconfirmed current context")
        model.setCarryEnabled(false); #expect(model.previous.isEmpty)
        model.setCarryEnabled(true); #expect(model.previous.count == 1)
        #expect(!((try fixture.store.fetchRevisions(id: current.id)).isEmpty))
    }
    @Test func recoveredMeetingsStayOnTheirDayAndHiddenCalendarsStayHidden() async throws {
        let fixture = try TestComposition(); defer { fixture.clearPreferences() }
        let now = Calendar.current.startOfDay(for: .now).addingTimeInterval(9 * 3600)
        let missing = KaigiTests().meeting("removed-series", start: now, eventID: "removed-event")
        let note = try fixture.store.openNote(for: missing)
        _ = try fixture.store.saveDraft(id: note.id, text: "Recover this occurrence", reason: "Edit")
        await fixture.container.agenda.load()
        #expect(fixture.container.agenda.recovered.map(\.id) == [note.id])
        fixture.container.agenda.selectRecovered(note)
        #expect(fixture.container.agenda.detail?.text == "Recover this occurrence")
        #expect(fixture.container.agenda.detail?.meeting == nil)
        fixture.container.agenda.back()
        fixture.container.agenda.move(1); await fixture.container.agenda.load()
        #expect(fixture.container.agenda.recovered.isEmpty)
        fixture.container.agenda.today(); await fixture.container.agenda.load()
        let live = try #require(fixture.container.agenda.meetings.first)
        let liveNote = try fixture.store.openNote(for: live)
        _ = try fixture.store.saveDraft(id: liveNote.id, text: "Hidden live meeting", reason: "Edit")
        fixture.container.visibility.set([CalendarID(rawValue: live.calendarID)], visible: false)
        await fixture.container.agenda.load()
        #expect(!fixture.container.agenda.recovered.contains { $0.id == liveNote.id })
    }
    @Test func historyAndContextRemainAssociatedAfterCalendarRemoval() throws {
        let fixture = try TestComposition(); defer { fixture.clearPreferences() }
        let first = KaigiTests().meeting()
        let older = try fixture.store.openNote(for: first)
        _ = try fixture.store.confirmContext(id: older.id, text: "Review scope")
        let next = KaigiTests().meeting(start: first.start.addingTimeInterval(86400))
        let current = try fixture.store.openNote(for: next)
        let unrelated = KaigiTests().meeting("unrelated", start: next.start, eventID: "unrelated")
        let other = try fixture.store.openNote(for: unrelated)
        let model = fixture.container.detail(note: current, meeting: nil)
        #expect(model.previous.map(\.id) == [older.id])
        #expect(model.history.map(\.id) == [older.id])
        model.openHistory(other); #expect(fixture.actions.floating.isEmpty)
        model.openHistory(older); #expect(fixture.actions.floating == [older.id])
    }
    @Test func aiSettingPersistsAndDisablingDiscardsOnlyTheSuggestion() async throws {
        let fixture = try TestComposition(ai: MockAIRefinementService(result: "Suggestion")); defer { fixture.clearPreferences() }
        let record = try fixture.store.openNote(for: KaigiTests().meeting())
        let model = fixture.container.detail(note: record, meeting: nil)
        model.updateText("Original note"); model.refine(.cleanUp); await model.waitForRefinement()
        #expect(model.preview?.text == "Suggestion")
        fixture.container.settings.setAIEnabled(false)
        #expect(!model.canRefine && model.preview == nil)
        #expect(model.text == "Original note")
        #expect(try fixture.store.fetchNote(id: record.id)?.text == "Original note")
        let center = NotificationCenterSpy()
        let preferences = SystemPreferencesService(defaults: fixture.defaults, notifications: center)
        #expect(preferences.aiEnabled) // Missing key preserves existing enabled behavior.
        preferences.aiEnabled = false
        let restored = SystemPreferencesService(defaults: fixture.defaults, notifications: center)
        #expect(!restored.aiEnabled)
    }
    @Test func remindersUseFiveMinutesAndReplacePendingRequests() async throws {
        let fixture = try TestComposition(); defer { fixture.clearPreferences() }
        fixture.defaults.set(true, forKey: "remindersEnabled")
        let center = NotificationCenterSpy()
        let service = SystemPreferencesService(defaults: fixture.defaults, notifications: center)
        #expect(service.remindersEnabled) // Existing enabled preference is retained.
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let future = KaigiTests().meeting(start: now.addingTimeInterval(900))
        let imminent = KaigiTests().meeting(start: now.addingTimeInterval(240))
        let allDay = Meeting(calendarID: future.calendarID, calendarName: future.calendarName, externalID: "all-day", eventID: "all-day", title: "All day", start: future.start, end: future.end, originalStart: future.originalStart, recurring: false, allDay: true, links: [])
        await service.schedule([future, imminent, allDay], now: now)
        #expect(center.requests.count == 1)
        #expect((center.requests.values.first?.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval == 600)
        await service.schedule([future], now: now)
        #expect(center.requests.count == 1)
        #expect(center.requests.values.first?.content.title == "Your meeting starts soon")
        await service.setReminders(false)
        #expect(center.requests.isEmpty && !fixture.defaults.bool(forKey: "remindersEnabled"))
    }
}

@MainActor final class NotificationCenterSpy: NotificationCenterClient {
    var requests: [String: UNNotificationRequest] = [:]
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
    func removeAllPendingNotificationRequests() { requests.removeAll() }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) { identifiers.forEach { requests.removeValue(forKey: $0) } }
    func add(_ request: UNNotificationRequest) async throws { requests[request.identifier] = request }
}
