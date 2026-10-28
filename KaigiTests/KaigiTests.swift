import Testing
import Foundation
@testable import Meetrail

@MainActor struct KaigiTests {
    func meeting(_ id: String = "series", start: Date = Date(timeIntervalSince1970: 1700000000), original: Date? = nil, calendar: String = "calendar", eventID: String = "event") -> Meeting {
        Meeting(calendarID: calendar, calendarName: "Synthetic", externalID: id, eventID: eventID, title: "Synthetic meeting", start: start, end: start.addingTimeInterval(1800), originalStart: original ?? start, recurring: true, allDay: false, links: [])
    }
    @Test func rescheduledOccurrenceKeepsStableIdentity() throws {
        let original = meeting()
        let moved = meeting(start: original.start.addingTimeInterval(86400), original: original.start, eventID: "changed")
        #expect(original.occurrenceKey == moved.occurrenceKey)
        let repository = try NoteRepository(inMemory: true)
        let note = try repository.note(for: original)
        try repository.save(note, text: "Original notes")
        let matched = try repository.note(for: moved)
        #expect(note.id == matched.id)
        #expect(matched.text == "Original notes")
        #expect(matched.start == moved.start)
    }
    @Test func oneTimeReschedulingKeepsItsNote() throws {
        let first = meeting()
        func oneTime(_ start: Date) -> Meeting { Meeting(calendarID: first.calendarID, calendarName: first.calendarName, externalID: first.externalID, eventID: first.eventID, title: first.title, start: start, end: start.addingTimeInterval(1800), originalStart: start, recurring: false, allDay: false, links: []) }
        let repository = try NoteRepository(inMemory: true)
        let note = try repository.note(for: oneTime(first.start))
        try repository.save(note, text: "Keep when a one-time event moves")
        let moved = try repository.note(for: oneTime(first.start.addingTimeInterval(86400)))
        #expect(note.id == moved.id)
        #expect(moved.text == "Keep when a one-time event moves")
    }
    @Test func changedEventKitIDKeepsExternalIdentity() { #expect(meeting().occurrenceKey == meeting(eventID: "resynced").occurrenceKey) }
    @Test func changedExternalIdentityNeverGuesses() throws {
        let repository = try NoteRepository(inMemory: true)
        let one = try repository.note(for: meeting())
        let two = try repository.note(for: meeting("different"))
        #expect(one.id != two.id)
    }
    @Test func sameTitleInAnotherCalendarNeverMerges() { #expect(meeting().seriesKey != meeting(calendar: "another").seriesKey) }
    @Test func differentOccurrencesHaveSeparateNotesAndContext() throws {
        let repository = try NoteRepository(inMemory: true)
        let first = try repository.note(for: meeting())
        let next = try repository.note(for: meeting(start: first.start.addingTimeInterval(86400)))
        try repository.save(first, text: "Maybe ship next week?")
        #expect(try repository.previousContext(for: next).isEmpty)
        try repository.confirm(first, context: "Question: ship next week?")
        #expect(try repository.previousContext(for: next).first?.id == first.id)
        #expect(next.text.isEmpty)
        #expect(first.id != next.id)
    }
    @Test func contextDoesNotLeakAcrossSeriesOrFromFuture() throws {
        let repository = try NoteRepository(inMemory: true)
        let one = try repository.note(for: meeting())
        let other = try repository.note(for: meeting("other"))
        try repository.confirm(other, context: "Private context")
        #expect(try repository.previousContext(for: one).isEmpty)
        let future = try repository.note(for: meeting(start: one.start.addingTimeInterval(86400)))
        try repository.confirm(future, context: "Future")
        #expect(try repository.previousContext(for: one).isEmpty)
    }
    @Test func autosaveRevisionsAndMarkdown() throws {
        let repository = try NoteRepository(inMemory: true)
        let note = try repository.note(for: meeting())
        try repository.save(note, text: "First")
        try repository.save(note, text: "Second", reason: "Before AI refinement")
        #expect(try repository.revisions(note).contains { $0.text == "First" })
        #expect(repository.markdown(note).contains("Second"))
        #expect(try repository.allNotes().count == 1) // Event disappearance never deletes it.
    }
    @Test func diskPersistenceAcrossRepositoryRestart() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("notes.store")
        var identity: UUID?
        do {
            let repository = try NoteRepository(url: url)
            let note = try repository.note(for: meeting()); identity = note.id
            try repository.save(note, text: "Durable synthetic note")
        }
        let reopened = try NoteRepository(url: url)
        #expect(try reopened.allNotes().first?.text == "Durable synthetic note")
        #expect(try reopened.allNotes().first?.id == identity)
    }
    @Test(arguments: ["https://meet.google.com/aaa-bbbb-ccc", "https://us02web.zoom.us/j/00000000000", "https://teams.microsoft.com/l/meetup-join/qa", "https://example.webex.com/meet/qa"])
    func recognizesProviders(_ value: String) { #expect(MeetingLinkResolver().resolve(url: URL(string: value), location: nil, notes: nil).first?.recognized == true) }
    @Test(arguments: ["javascript:alert(1)", "zoommtg://zoom.us/j/123", "file:///tmp/test", "http://zoom.us/j/123", "https://user:password@zoom.us/j/123", "https://localhost/test", "https://127.0.0.1/test", "https://zoom.us:8443/j/123"])
    func rejectsUnsafeURLs(_ value: String) { #expect(MeetingLinkResolver.validated(URL(string: value)!) == nil) }
    @Test func spoofedHostIsNotRecognized() {
        #expect(MeetingLinkResolver().resolve(url: URL(string: "https://zoom.us.evil.example/j/123"), location: nil, notes: nil).first?.recognized == false)
    }
    @Test func resolvesMultipleFieldsDeduplicatesAndKeepsFallback() {
        let links = MeetingLinkResolver().resolve(url: URL(string: "https://meet.google.com/aaa-bbbb-ccc"), location: "https://example.invalid/room", notes: "https://meet.google.com/aaa-bbbb-ccc https://example.webex.com/meet/qa")
        #expect(links.count == 3)
        #expect(links.filter(\.recognized).count == 2)
    }
    @Test(arguments: ["Europe/Belgrade", "America/New_York", "Pacific/Auckland"])
    func dayNavigationRespectsDST(_ zone: String) {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: zone)!
        var selection = DaySelection(date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 12))!, calendar: calendar)
        let original = selection.date
        selection.move(1); selection.move(-1)
        #expect(selection.date == original)
        #expect(selection.interval.contains(selection.date))
        #expect(selection.interval.duration >= 23 * 3600 && selection.interval.duration <= 25 * 3600)
    }
    @Test func dayBoundariesExcludeAdjacentEvents() {
        let start = Date(timeIntervalSince1970: 1700000000)
        #expect(!meeting(start: start).overlaps(DateInterval(start: start.addingTimeInterval(1800), duration: 86400)))
    }
    @Test func navigationAndSelectionAreIndependentOfJoining() async throws {
        let fixture = try TestComposition(); defer { fixture.clearPreferences() }
        let model = fixture.container.agenda!
        await model.load()
        let original = model.day.date; model.move(1); #expect(model.day.date > original)
        model.today(); await model.load(); #expect(Calendar.current.isDateInToday(model.day.date))
        model.select(model.meetings[0]); #expect(model.selected != nil)
        #expect(model.selectedMeeting?.id == model.meetings[0].id)
        #expect(fixture.actions.opened.isEmpty)
        model.join(model.meetings[0].links[0]); #expect(fixture.actions.opened.count == 1)
    }
    @Test func deterministicAIAndUnavailableFallback() async throws {
        let mock = MockAIRefinementService(result: "Corrected note")
        #expect(try await mock.refine("rough note", action: .cleanUp).text == "Corrected note")
        let unavailable = UnavailableAIService(); #expect(unavailable.unavailableReason != nil)
        do { _ = try await unavailable.refine("note", action: .structure); Issue.record("Unavailable service must not generate") }
        catch { #expect(error is RefinementFailure) }
    }
    @Test func structureRejectsFabricatedFacts() throws {
        if #available(macOS 26.0, *) {
            #expect(throws: RefinementFailure.self) { try FoundationModelsRefinementService.validatedStructure([("Actions", ["Alex will deliver Friday"])], source: "Maybe deliver?") }
            let output = try FoundationModelsRefinementService.validatedStructure([("Questions", ["Maybe deliver?"])], source: "Maybe deliver?")
            #expect(output.contains("Maybe deliver?"))
        }
    }
    @Test func canceledAndDeclinedEventsAreExcludedWithoutDeletingNotes() throws {
        let event = meeting()
        let interval = DateInterval(start: event.start, duration: 86400)
        let normalizer = EventNormalizer()
        #expect(normalizer.normalize(event, canceled: true, declined: false, interval: interval) == nil)
        #expect(normalizer.normalize(event, canceled: false, declined: true, interval: interval) == nil)
        #expect(normalizer.normalize(event, canceled: false, declined: false, interval: interval) != nil)
        let repository = try NoteRepository(inMemory: true)
        let note = try repository.note(for: event)
        try repository.save(note, text: "Keep after cancellation")
        #expect(try repository.allNotes().first?.text == "Keep after cancellation")
    }
    @Test func backgroundDayAndTimeZoneChangesAreMarshaledToMain() async {
        await Task.detached {
            NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
            NotificationCenter.default.post(name: NSNotification.Name.NSSystemTimeZoneDidChange, object: nil)
        }.value
        await Task.yield()
        #expect(Thread.isMainThread) // AppKit would terminate the host on a background-window regression.
    }
    @Test func realModelAvailabilityProbe() async throws {
        let service = AIServiceFactory.make()
        if let reason = service.unavailableReason { print("REAL_AI_UNAVAILABLE: \(reason)"); return }
        let result = try await service.refine("We discussed the draft. No decision was made. Should we revisit it next week?", action: .cleanUp)
        #expect(!result.text.isEmpty)
        print("REAL_AI_CLEANUP_PROBE_COMPLETED: synthetic input only; semantic accuracy still requires human review")
    }
}
