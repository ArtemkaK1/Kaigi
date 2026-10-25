import Foundation

@MainActor final class CalendarAccountCoordinator {
    private let providers: [any CalendarProvider]
    private var observers: [UUID: () -> Void] = [:]
    init(providers: [any CalendarProvider]) {
        precondition(Set(providers.map(\.kind)).count == providers.count, "Register each provider kind once")
        self.providers = providers
        for provider in providers { provider.onChange = { [weak self] in self?.notifyChange() } }
    }
    @discardableResult func observe(_ action: @escaping () -> Void) -> UUID {
        let token = UUID(); observers[token] = action; return token
    }
    func removeObserver(_ token: UUID) { observers.removeValue(forKey: token) }
    func prepare() async { for provider in providers { await provider.prepare() } }
    func notifyChange() { for action in Array(observers.values) { action() } }
    func state(for kind: CalendarProviderKind) -> AccountConnectionState {
        providers.first { $0.kind == kind }?.connectionState ?? .comingSoon
    }
    var connectionState: AccountConnectionState {
        if providers.contains(where: { $0.connectionState == .connected }) { return .connected }
        if providers.contains(where: { $0.connectionState == .permissionDenied }) { return .permissionDenied }
        return .notConnected
    }
    func catalog() -> CalendarCatalog {
        let catalogs = providers.map { $0.catalog() }
        return CalendarCatalog(accounts: catalogs.flatMap(\.accounts), calendars: catalogs.flatMap(\.calendars))
    }
    func connect(_ kind: CalendarProviderKind) async throws {
        guard let provider = providers.first(where: { $0.kind == kind }) else {
            throw CalendarDomainError.unavailableProvider
        }
        try await provider.connect(); notifyChange()
    }
    func events(in interval: DateInterval, visibleCalendarIDs: Set<CalendarID>) async throws -> [CalendarEvent] {
        var events: [CalendarEvent] = []
        for provider in providers where provider.connectionState == .connected {
            events += try await provider.events(in: interval, visibleCalendarIDs: visibleCalendarIDs)
        }
        return try CalendarEventDeduplicator().deduplicate(events)
    }
}
enum CalendarDomainError: LocalizedError {
    case unavailableProvider, ambiguousIdentity, missingNote
    var errorDescription: String? {
        switch self {
        case .unavailableProvider: "Direct connection for this provider is coming soon."
        case .ambiguousIdentity: "Some calendar events share an ambiguous identity. They were not attached to private notes. Refresh the calendar source and try again."
        case .missingNote: "This saved note could not be found."
        }
    }
}
struct CalendarEventDeduplicator {
    func deduplicate(_ events: [CalendarEvent]) throws -> [CalendarEvent] {
        var byID: [String: CalendarEvent] = [:]
        for event in events {
            if let previous = byID[event.id], previous != event { throw CalendarDomainError.ambiguousIdentity }
            byID[event.id] = event
        }
        return byID.values.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }
}
@MainActor struct CalendarVisibilityUseCase {
    let preferences: any CalendarPreferences
    let coordinator: CalendarAccountCoordinator
    func initializeIfNeeded() {
        guard preferences.selectedCalendarIDs == nil, coordinator.connectionState == .connected else { return }
        preferences.selectedCalendarIDs = Set(coordinator.catalog().calendars.filter(\.isAvailable).map(\.id))
    }
    var selectedIDs: Set<CalendarID> { preferences.selectedCalendarIDs ?? [] }
    var effectiveIDs: Set<CalendarID> { selectedIDs.intersection(Set(coordinator.catalog().calendars.filter(\.isAvailable).map(\.id))) }
    func set(_ ids: Set<CalendarID>, visible: Bool) {
        var updated = selectedIDs
        if visible { updated.formUnion(ids) } else { updated.subtract(ids) }
        preferences.selectedCalendarIDs = updated
        coordinator.notifyChange()
    }
}
