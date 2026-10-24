import SwiftUI
import AppKit

@MainActor @Observable final class AgendaViewModel {
    let calendar: any CalendarGateway
    let notes: NoteRepository
    let ai: any AIRefinementService
    let preferences = SystemPreferencesService()
    var day = DaySelection(date: .now)
    var onPermissionResult: (() -> Void)?
    var onPresentationChange: (() -> Void)?
    var meetings: [Meeting] = [] { didSet { onPresentationChange?() } }
    var calendarIDs: Set<String> = []
    var selected: MeetingNote? { didSet { onPresentationChange?() } }
    var selectedMeeting: Meeting?
    var error: String?
    var loading = false
    var showingSettings = false { didSet { onPresentationChange?() } }
    var showingLibrary = false { didSet { onPresentationChange?() } }
    var reminderTask: Task<Void, Never>?
    var contextKeys: Set<String> = []
    var noteKeys: Set<String> = []
    var sample: Bool
    init(calendar: any CalendarGateway, notes: NoteRepository, sample: Bool = false, ai: (any AIRefinementService)? = nil) {
        self.calendar = calendar; self.notes = notes; self.sample = sample; self.ai = ai ?? UnavailableAIService()
        if !sample, let saved = UserDefaults.standard.stringArray(forKey: "selectedCalendars") { calendarIDs = Set(saved) }
        else { calendarIDs = Set(calendar.calendars.map(\.id)) }
        calendar.onChange = { [weak self] in self?.refresh() }
        refresh()
    }
    var panelHeight: CGFloat {
        if showingSettings { return min(550, 330 + CGFloat(calendar.calendars.count) * 26) }
        if showingLibrary { return 500 }
        if selected != nil { return 660 }
        if calendar.access != .allowed || meetings.isEmpty { return 470 }
        return 230 + min(CGFloat(meetings.count) * 96, 390)
    }
    func move(_ days: Int) { day.move(days); refresh() }
    func today() { day.date = .now; refresh() }
    func refresh() {
        day.calendar = .current
        if !sample { UserDefaults.standard.set(Array(calendarIDs), forKey: "selectedCalendars") }
        do {
            meetings = try calendar.meetings(in: day.interval, calendarIDs: calendarIDs).sorted { $0.start < $1.start }
            contextKeys = Set(try meetings.filter { try notes.hasPreviousContext(for: $0) }.map(\.occurrenceKey))
            noteKeys = Set(try notes.allNotes().filter { !$0.text.isEmpty }.map(\.occurrenceKey))
            if preferences.remindersEnabled && !sample {
                let now = Date.now
                let upcoming = try calendar.meetings(in: DateInterval(start: now, duration: 7 * 86400), calendarIDs: calendarIDs).sorted { $0.start < $1.start }
                reminderTask?.cancel()
                reminderTask = Task { await preferences.schedule(upcoming) }
            }
        } catch { self.error = error.localizedDescription }
    }
    func connect() async {
        loading = true; defer { loading = false; onPermissionResult?() }
        let wasAllowed = calendar.access == .allowed
        do { try await calendar.requestAccess(); if !wasAllowed { calendarIDs = Set(calendar.calendars.map(\.id)) }; refresh() }
        catch { self.error = error.localizedDescription }
    }
    func select(_ meeting: Meeting) {
        do { selected = try notes.note(for: meeting); selectedMeeting = meeting }
        catch { self.error = error.localizedDescription }
    }
    func join(_ link: MeetingLink) { guard let url = MeetingLinkResolver.validated(link.url) else { return }; NSWorkspace.shared.open(url) }
}
