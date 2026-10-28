import Foundation
import Testing
@testable import Meetrail

@MainActor struct StartupPerformanceTests {
    @Test func catalogPreparationSuspendsWithoutInitializingAnEmptySelection() async throws {
        let fixture = try TestComposition(); defer { fixture.clearPreferences() }
        let suite = "kaigi.startup-test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferencesStore(defaults: defaults)
        let provider = StartupCalendarProvider(holdPreparation: true)
        let coordinator = CalendarAccountCoordinator(providers: [provider])
        let visibility = CalendarVisibilityUseCase(preferences: preferences, coordinator: coordinator)
        let useCase = AgendaUseCase(coordinator: coordinator, visibility: visibility, notes: fixture.container.noteUseCases, preferences: fixture.system, sample: true)
        let model = AgendaViewModel(useCase: useCase, selection: MeetingSelectionUseCase(store: fixture.store), join: ConferenceJoinUseCase(opener: fixture.actions), actions: fixture.actions, detailFactory: { note, meeting in fixture.container.detail(note: note, meeting: meeting) })
        let load = Task { await model.load() }
        for _ in 0..<100 where provider.pending == nil { await Task.yield() }
        #expect(provider.pending != nil)
        #expect(model.loading)
        #expect(preferences.selectedCalendarIDs == nil)
        // Opening the same day remains a synchronous presentation intention.
        model.showToday(); model.showToday()
        #expect(model.loading && provider.eventQueries == 0)
        provider.finishPreparation()
        await load.value
        #expect(!model.loading && model.meetings.count == 3)
        #expect(provider.eventQueries == 1)
        #expect(visibility.selectedIDs == [CalendarID(rawValue: "sample")])
        model.showToday()
        await Task.yield()
        #expect(provider.eventQueries == 1)
    }

    @Test func recoveryDoesNotRepeatAnIdenticalVisibleCalendarQuery() async throws {
        let fixture = try TestComposition(); defer { fixture.clearPreferences() }
        let missing = KaigiTests().meeting("missing", start: Calendar.current.startOfDay(for: .now).addingTimeInterval(3600))
        let note = try fixture.store.openNote(for: missing)
        _ = try fixture.store.saveDraft(id: note.id, text: "Synthetic recovery", reason: "Edit")
        let provider = StartupCalendarProvider(holdPreparation: false)
        let coordinator = CalendarAccountCoordinator(providers: [provider])
        let visibility = CalendarVisibilityUseCase(preferences: fixture.preferences, coordinator: coordinator)
        let useCase = AgendaUseCase(coordinator: coordinator, visibility: visibility, notes: fixture.container.noteUseCases, preferences: fixture.system, sample: true)
        let result = try await useCase.load(day: Calendar.current.dateInterval(of: .day, for: .now)!)
        #expect(result.recovered.map(\.id) == [note.id])
        #expect(provider.eventQueries == 1)
    }
}

@MainActor private final class StartupCalendarProvider: CalendarProvider {
    let kind = CalendarProviderKind.system
    let connectionState = AccountConnectionState.connected
    var onChange: (() -> Void)?
    let base = SampleCalendarGateway()
    var pending: CheckedContinuation<Void, Never>?
    var ready: Bool
    var eventQueries = 0
    init(holdPreparation: Bool) { ready = !holdPreparation }
    func prepare() async { if !ready { await withCheckedContinuation { pending = $0 } } }
    func finishPreparation() { ready = true; let continuation = pending; pending = nil; continuation?.resume() }
    func catalog() -> CalendarCatalog { ready ? base.catalog() : .empty }
    func connect() async throws {}
    func events(in interval: DateInterval, visibleCalendarIDs: Set<CalendarID>) async throws -> [CalendarEvent] {
        eventQueries += 1
        return try await base.events(in: interval, visibleCalendarIDs: visibleCalendarIDs)
    }
}
