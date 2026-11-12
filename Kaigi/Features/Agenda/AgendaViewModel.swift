import Foundation
import Observation

struct AgendaEntry { let key: String; let start: Date; let meeting: Meeting?; let note: NoteRecord? }

@MainActor @Observable final class AgendaViewModel {
    private let analytics: any AnalyticsTracking
    var access: FeatureAccess { useCase.access }
    private let useCase: AgendaUseCase
    private let selection: MeetingSelectionUseCase
    private let joinUseCase: ConferenceJoinUseCase
    private let actions: any ApplicationActions
    private let detailFactory: (NoteRecord, Meeting?) -> MeetingDetailViewModel
    var day = DaySelection(date: .now)
    private(set) var meetings: [Meeting] = []
    private(set) var selected: NoteRecord?
    private(set) var selectedMeeting: Meeting?
    private(set) var detail: MeetingDetailViewModel?
    private(set) var connection = AccountConnectionState.notConnected
    private(set) var error: String?
    private(set) var loading = false
    private(set) var recovered: [NoteRecord] = []
    private(set) var noteKeys: Set<String> = []
    private var savedContextKeys: Set<String> = []
    var contextKeys: Set<String> { access.allows(.recurringContext) ? savedContextKeys : [] }
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0
    var entries: [AgendaEntry] {
        (meetings.map { AgendaEntry(key: $0.occurrenceKey, start: $0.start, meeting: $0, note: nil) } + recovered.map { AgendaEntry(key: $0.occurrenceKey, start: $0.start, meeting: nil, note: $0) }).sorted { $0.start == $1.start ? $0.key < $1.key : $0.start < $1.start }
    }
    var weekday: String { day.date.formatted(.dateTime.weekday(.wide)) }
    var fullDate: String { day.date.formatted(.dateTime.day().month(.wide).year()) }

    init(useCase: AgendaUseCase, selection: MeetingSelectionUseCase, join: ConferenceJoinUseCase, actions: any ApplicationActions, analytics: any AnalyticsTracking, detailFactory: @escaping (NoteRecord, Meeting?) -> MeetingDetailViewModel) {
        self.analytics = analytics
        self.useCase = useCase; self.selection = selection; joinUseCase = join; self.actions = actions
        self.detailFactory = detailFactory
        useCase.coordinator.observe { [weak self] in self?.refresh() }
    }

    func notesChanged() {
        do { let badges = try useCase.notes.badges(for: meetings); noteKeys = badges.notes; savedContextKeys = badges.previousContext }
        catch { self.error = error.localizedDescription }
    }

    func move(_ days: Int) {
        day.move(days)
        if days != 0 { analytics.track(.agendaDayChanged(days < 0 ? .previous : .next)) }
        refresh()
    }

    func today() {
        let changed = !day.calendar.isDateInToday(day.date)
        day.date = .now
        if changed { analytics.track(.agendaDayChanged(.today)) }
        refresh()
    }

    func showToday() {
        // EventKit changes already refresh today's agenda. Opening the panel must
        // not cancel an in-flight initial load or repeat the same calendar reads.
        if !day.calendar.isDateInToday(day.date) { day.date = .now; refresh() }
    }

    func refresh() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in await self?.load() }
    }

    func load() async {
        loadGeneration += 1; let generation = loadGeneration
        day.calendar = .current; loading = true
        do {
            let value = try await useCase.load(day: day.interval)
            guard !Task.isCancelled, generation == loadGeneration else { return }
            meetings = value.meetings; recovered = value.recovered; noteKeys = value.badges.notes; savedContextKeys = value.badges.previousContext
            connection = value.connection; error = nil
        } catch is CancellationError { return }
        catch { guard generation == loadGeneration else { return }; self.error = error.localizedDescription }
        loading = false
    }

    func select(_ meeting: Meeting) {
        analytics.track(.agendaMeetingOpened)
        do { let note = try selection.select(meeting); selectedMeeting = meeting; selected = note; detail = detailFactory(note, meeting) }
        catch { self.error = error.localizedDescription }
    }

    func selectRecovered(_ record: NoteRecord) {
        analytics.track(.agendaRecoveredNoteOpened)
        do {
            let note = try useCase.notes.note(record.id)
            selectedMeeting = nil; selected = note; detail = detailFactory(note, nil)
        } catch { self.error = error.localizedDescription }
    }

    func back() { detail = nil; selected = nil; selectedMeeting = nil; refresh() }

    func join(_ link: MeetingLink) { analytics.track(.agendaJoinTapped); do { try joinUseCase.join(link) } catch { self.error = error.localizedDescription } }

    func connect() { guard access.allows(.calendarManagement) else { return }; actions.showAccounts() }

    func dismissError() { error = nil }
}
