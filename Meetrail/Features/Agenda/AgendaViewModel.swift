import Foundation
import Observation

struct AgendaEntry { let key: String; let start: Date; let meeting: Meeting?; let note: NoteRecord? }

@MainActor @Observable final class AgendaViewModel {
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
    private(set) var contextKeys: Set<String> = []
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0
    var entries: [AgendaEntry] {
        (meetings.map { AgendaEntry(key: $0.occurrenceKey, start: $0.start, meeting: $0, note: nil) } + recovered.map { AgendaEntry(key: $0.occurrenceKey, start: $0.start, meeting: nil, note: $0) }).sorted { $0.start == $1.start ? $0.key < $1.key : $0.start < $1.start }
    }
    var weekday: String { day.date.formatted(.dateTime.weekday(.wide)) }
    var fullDate: String { day.date.formatted(.dateTime.day().month(.wide).year()) }
    init(useCase: AgendaUseCase, selection: MeetingSelectionUseCase, join: ConferenceJoinUseCase, actions: any ApplicationActions, detailFactory: @escaping (NoteRecord, Meeting?) -> MeetingDetailViewModel) {
        self.useCase = useCase; self.selection = selection; joinUseCase = join; self.actions = actions
        self.detailFactory = detailFactory
        useCase.coordinator.observe { [weak self] in self?.refresh() }
    }
    func notesChanged() {
        do { let badges = try useCase.notes.badges(for: meetings); noteKeys = badges.notes; contextKeys = badges.previousContext }
        catch { self.error = error.localizedDescription }
    }
    func move(_ days: Int) { day.move(days); refresh() }
    func today() { day.date = .now; refresh() }
    func showToday() {
        // EventKit changes already refresh today's agenda. Opening the panel must
        // not cancel an in-flight initial load or repeat the same calendar reads.
        if !day.calendar.isDateInToday(day.date) { today() }
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
            meetings = value.meetings; recovered = value.recovered; noteKeys = value.badges.notes; contextKeys = value.badges.previousContext
            connection = value.connection; error = nil
        } catch is CancellationError { return }
        catch { guard generation == loadGeneration else { return }; self.error = error.localizedDescription }
        loading = false
    }
    func select(_ meeting: Meeting) {
        do { let note = try selection.select(meeting); selectedMeeting = meeting; selected = note; detail = detailFactory(note, meeting) }
        catch { self.error = error.localizedDescription }
    }
    func selectRecovered(_ record: NoteRecord) {
        do {
            let note = try useCase.notes.note(record.id)
            selectedMeeting = nil; selected = note; detail = detailFactory(note, nil)
        } catch { self.error = error.localizedDescription }
    }
    func back() { detail = nil; selected = nil; selectedMeeting = nil; refresh() }
    func join(_ link: MeetingLink) { do { try joinUseCase.join(link) } catch { self.error = error.localizedDescription } }
    func connect() { actions.showAccounts() }
    func dismissError() { error = nil }
}
