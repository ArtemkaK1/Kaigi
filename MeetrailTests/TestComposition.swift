import Foundation
@testable import Meetrail

@MainActor final class TestActions: ApplicationActions, LinkOpening, PermissionSettingsOpening {
    var opened: [URL] = []
    var floating: [NoteID] = []
    var contextWindows: [NoteID] = []
    var exports: [MarkdownDocument] = []
    var accountWindows = 0
    var permissionSettings = 0
    func showAccounts() { accountWindows += 1 }
    func showFloatingNote(_ id: NoteID) { floating.append(id) }
    func showMeetingContext(_ id: NoteID) { contextWindows.append(id) }
    func export(_ document: MarkdownDocument) async throws { exports.append(document) }
    func open(_ url: URL) throws { opened.append(url) }
    func openCalendarSettings() throws { permissionSettings += 1 }
}
@MainActor final class TestComposition {
    let suite: String
    let defaults: UserDefaults
    let preferences: AppPreferencesStore
    let provider: SampleCalendarGateway
    let store: NoteRepository
    let system = PreviewPreferencesService()
    let actions = TestActions()
    let container: DependencyContainer
    init(calendars: Int = 1, meetings: Int = 3, firstRun: Bool = false, legacyIDs: [String]? = nil, store: NoteRepository? = nil, ai: (any AIRefinementService)? = nil) throws {
        suite = "meetrail.test.\(UUID().uuidString)"; defaults = UserDefaults(suiteName: suite)!
        if let legacyIDs { defaults.set(legacyIDs, forKey: "selectedCalendars") }
        preferences = AppPreferencesStore(defaults: defaults)
        provider = SampleCalendarGateway(meetingCount: meetings, calendarCount: calendars)
        if firstRun { provider.access = .unknown }
        self.store = try store ?? NoteRepository(inMemory: true)
        container = try DependencyContainer(providers: [provider], store: self.store, preferences: preferences, systemPreferences: system, ai: ai ?? UnavailableAIService(), opener: actions, permissionSettings: actions, actions: actions, sample: true, suppressOnboarding: !firstRun, closeOnboarding: {})
    }
    func clearPreferences() { defaults.removePersistentDomain(forName: suite) }
}
@MainActor final class FailingNotesStore: NotesStore {
    let base: NoteRepository
    var failWrites = false
    init(base: NoteRepository) { self.base = base }
    func fetchNotes() throws -> [NoteRecord] { try base.fetchNotes() }
    func fetchNote(id: NoteID) throws -> NoteRecord? { try base.fetchNote(id: id) }
    func openNote(for meeting: Meeting) throws -> NoteRecord { try base.openNote(for: meeting) }
    func saveDraft(id: NoteID, text: String, reason: String) throws -> NoteRecord {
        if failWrites { throw CocoaError(.fileWriteNoPermission) }; return try base.saveDraft(id: id, text: text, reason: reason)
    }
    func fetchRevisions(id: NoteID) throws -> [RevisionRecord] { try base.fetchRevisions(id: id) }
    func confirmContext(id: NoteID, text: String) throws -> NoteRecord { try base.confirmContext(id: id, text: text) }
    func fetchSeries() throws -> [SeriesRecord] { try base.fetchSeries() }
    func contextEnabled(for meeting: Meeting) throws -> Bool { try base.contextEnabled(for: meeting) }
    func setContextEnabled(_ enabled: Bool, for meeting: Meeting) throws { try base.setContextEnabled(enabled, for: meeting) }
    func flush() throws { try base.flush() }
}

// Protocol fixture only: no networking/authentication or production provider claims.
@MainActor final class StubCalendarProvider: CalendarProvider {
    let kind: CalendarProviderKind
    var connectionState = AccountConnectionState.notConnected
    var onChange: (() -> Void)?
    let account: CalendarAccount
    let calendar: CalendarDescriptor
    var fixtureEvents: [CalendarEvent]
    init(kind: CalendarProviderKind, event: Meeting) {
        self.kind = kind
        let accountID = AccountID(rawValue: "test-\(kind.rawValue)")
        account = CalendarAccount(id: accountID, provider: kind, name: "Synthetic adapter contract", state: .connected)
        let id = CalendarID(provider: kind, account: accountID, externalID: "calendar")
        calendar = CalendarDescriptor(id: id, accountID: accountID, name: "Synthetic provider calendar", color: .neutral, isAvailable: true)
        var namespaced = event; namespaced.providerKind = kind; namespaced.accountID = accountID.rawValue
        fixtureEvents = [namespaced]
    }
    func catalog() -> CalendarCatalog { connectionState == .connected ? CalendarCatalog(accounts: [account], calendars: [calendar]) : .empty }
    func connect() async throws { connectionState = .connected }
    func events(in interval: DateInterval, visibleCalendarIDs: Set<CalendarID>) async throws -> [CalendarEvent] {
        visibleCalendarIDs.contains(calendar.id) ? fixtureEvents.filter { $0.overlaps(interval) } : []
    }
}
