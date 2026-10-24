import Foundation

@MainActor struct NoteUseCases {
    let store: any NotesStore
    func note(_ id: NoteID) throws -> NoteRecord {
        guard let note = try store.fetchNote(id: id) else { throw CalendarDomainError.missingNote }; return note
    }
    func save(_ id: NoteID, text: String, reason: String = "Edit") throws -> NoteRecord { try store.saveDraft(id: id, text: text, reason: reason) }
    func revisions(_ id: NoteID) throws -> [RevisionRecord] { try store.fetchRevisions(id: id) }
    func restore(_ revision: RevisionRecord) throws -> NoteRecord { try save(revision.noteID, text: revision.text, reason: "Restore revision") }
    func document(_ id: NoteID, draft: String? = nil) throws -> MarkdownDocument {
        let note = try note(id)
        return MarkdownDocument(text: "# \(note.title)\n\n\(note.start.formatted(date: .complete, time: .shortened))\n\n\(draft ?? note.text)\n\n## Confirmed context\n\n\(note.confirmedContext)\n", filename: "Meetrail-note.md")
    }
    func badges(for meetings: [Meeting]) throws -> NoteBadges {
        let notes = try store.fetchNotes()
        let series = Dictionary(uniqueKeysWithValues: try store.fetchSeries().map { ($0.externalKey, $0) })
        let noteKeys = Set(notes.filter { !$0.text.isEmpty }.map(\.occurrenceKey))
        let contextKeys = Set(meetings.filter { meeting in
            guard meeting.recurring, let entry = series[meeting.seriesKey], entry.carryContext else { return false }
            return notes.contains { $0.seriesID == entry.id && $0.start < meeting.start && !$0.confirmedContext.isEmpty }
        }.map(\.occurrenceKey))
        return NoteBadges(notes: noteKeys, previousContext: contextKeys)
    }
    func recovered(in day: DateInterval, excluding keys: Set<String>) throws -> [NoteRecord] {
        try store.fetchNotes().filter {
            $0.start >= day.start && $0.start < day.end && !keys.contains($0.occurrenceKey) && (!$0.text.isEmpty || !$0.confirmedContext.isEmpty)
        }
    }
    func history(of note: NoteRecord) throws -> [NoteRecord] {
        try store.fetchNotes().filter { $0.seriesID == note.seriesID && $0.id != note.id }.sorted { $0.start > $1.start }
    }
    func flush() throws { try store.flush() }
}
@MainActor struct MeetingSelectionUseCase {
    let store: any NotesStore
    func select(_ event: CalendarEvent) throws -> NoteRecord { try store.openNote(for: event) }
}
@MainActor struct MeetingContextUseCase {
    let store: any NotesStore
    func previous(for note: NoteRecord) throws -> [NoteRecord] {
        try store.fetchNotes().filter { $0.seriesID == note.seriesID && $0.id != note.id && $0.start < note.start && !$0.confirmedContext.isEmpty }
    }
    func confirm(_ id: NoteID, text: String) throws -> NoteRecord { try store.confirmContext(id: id, text: text) }
    func enabled(for note: NoteRecord) throws -> Bool { try store.fetchSeries().first { $0.id == note.seriesID }?.carryContext ?? false }
    func enabled(for meeting: Meeting) throws -> Bool { try store.contextEnabled(for: meeting) }
    func setEnabled(_ value: Bool, for meeting: Meeting) throws { try store.setContextEnabled(value, for: meeting) }
}
@MainActor struct ConferenceJoinUseCase {
    let opener: any LinkOpening
    func join(_ link: MeetingLink) throws {
        guard let safe = MeetingLinkResolver.validated(link.url) else { throw RefinementFailure(message: "This meeting URL is not a safe HTTPS link.") }
        try opener.open(safe)
    }
}
struct AgendaResult: Sendable { let meetings: [Meeting]; let recovered: [NoteRecord]; let badges: NoteBadges; let connection: AccountConnectionState }
@MainActor struct AgendaUseCase {
    let coordinator: CalendarAccountCoordinator
    let visibility: CalendarVisibilityUseCase
    let notes: NoteUseCases
    let preferences: any PreferencesService
    let sample: Bool
    func load(day: DateInterval) async throws -> AgendaResult {
        visibility.initializeIfNeeded()
        let events = try await coordinator.events(in: day, visibleCalendarIDs: visibility.effectiveIDs)
        if preferences.remindersEnabled && !sample {
            let now = Date.now
            let upcoming = try await coordinator.events(in: DateInterval(start: now, duration: 7 * 86400), visibleCalendarIDs: visibility.effectiveIDs)
            guard !Task.isCancelled else { throw CancellationError() }
            await preferences.schedule(upcoming, now: now)
        }
        // Exclude events from hidden calendars too: hiding a calendar must not
        // reintroduce its live notes as apparently missing events.
        let catalog = coordinator.catalog()
        var recovered = try notes.recovered(in: day, excluding: Set(events.map(\.occurrenceKey)))
        if !recovered.isEmpty && coordinator.connectionState == .connected {
            let allEvents = try await coordinator.events(in: day, visibleCalendarIDs: Set(catalog.calendars.map(\.id)))
            recovered = try notes.recovered(in: day, excluding: Set(allEvents.map(\.occurrenceKey)))
        }
        return AgendaResult(meetings: events, recovered: recovered, badges: try notes.badges(for: events), connection: coordinator.connectionState)
    }
}
