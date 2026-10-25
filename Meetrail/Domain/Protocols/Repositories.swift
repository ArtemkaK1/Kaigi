import Foundation

@MainActor protocol NotesStore: AnyObject {
    func fetchNotes() throws -> [NoteRecord]
    func fetchNote(id: NoteID) throws -> NoteRecord?
    func openNote(for meeting: Meeting) throws -> NoteRecord
    func saveDraft(id: NoteID, text: String, reason: String) throws -> NoteRecord
    func fetchRevisions(id: NoteID) throws -> [RevisionRecord]
    func confirmContext(id: NoteID, text: String) throws -> NoteRecord
    func fetchSeries() throws -> [SeriesRecord]
    func contextEnabled(for meeting: Meeting) throws -> Bool
    func setContextEnabled(_ enabled: Bool, for meeting: Meeting) throws
    func flush() throws
}
@MainActor protocol CalendarPreferences: AnyObject {
    var selectedCalendarIDs: Set<CalendarID>? { get set }
}
@MainActor protocol OnboardingPreferences: AnyObject {
    var onboardingProgress: OnboardingProgress? { get set }
}
@MainActor protocol CalendarProvider: AnyObject {
    var kind: CalendarProviderKind { get }
    var connectionState: AccountConnectionState { get }
    var onChange: (() -> Void)? { get set }
    func prepare() async
    func catalog() -> CalendarCatalog
    func connect() async throws
    func events(in interval: DateInterval, visibleCalendarIDs: Set<CalendarID>) async throws -> [CalendarEvent]
}
extension CalendarProvider {
    // Providers with an immediately available catalog need no preparation.
    func prepare() async {}
}
@MainActor protocol PreferencesService: AnyObject {
    var aiEnabled: Bool { get set }
    var remindersEnabled: Bool { get }
    var launchAtLogin: Bool { get }
    var message: String? { get }
    func setLaunchAtLogin(_ value: Bool)
    func setReminders(_ enabled: Bool) async
    func schedule(_ meetings: [Meeting], now: Date) async
}
@MainActor protocol LinkOpening { func open(_ url: URL) throws }
@MainActor protocol ApplicationActions: AnyObject {
    func showAccounts()
    func showFloatingNote(_ id: NoteID)
    func export(_ document: MarkdownDocument) async throws
}

@MainActor protocol PermissionSettingsOpening { func openCalendarSettings() throws }
