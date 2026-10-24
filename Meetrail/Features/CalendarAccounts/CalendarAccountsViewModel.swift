import Foundation
import Observation

enum CalendarAccountsPage: Hashable { case connections, calendars }

struct CalendarGroupState: Identifiable {
    var id: AccountID { account.id }
    let account: CalendarAccount
    let calendars: [CalendarDescriptor]
    let selectedCount: Int
    let expanded: Bool
}
struct ProviderCardState: Identifiable {
    var id: CalendarProviderKind { kind }
    let kind: CalendarProviderKind
    let state: AccountConnectionState
    var canConnect: Bool { state == .notConnected || state == .permissionDenied }
    var connectionSummary: String { kind == .system ? "Connected through macOS" : "Connected" }
}
@MainActor @Observable final class CalendarAccountsViewModel {
    private let coordinator: CalendarAccountCoordinator
    private let permissionSettings: any PermissionSettingsOpening
    var page = CalendarAccountsPage.connections
    private let visibility: CalendarVisibilityUseCase
    var search = ""
    private var expanded: Set<AccountID> = []
    private(set) var catalog = CalendarCatalog.empty
    private(set) var selectedIDs: Set<CalendarID> = []
    private(set) var providers: [ProviderCardState] = []
    private(set) var connecting = false
    private(set) var error: String?
    init(coordinator: CalendarAccountCoordinator, visibility: CalendarVisibilityUseCase, permissionSettings: any PermissionSettingsOpening) {
        self.coordinator = coordinator; self.visibility = visibility; self.permissionSettings = permissionSettings
        coordinator.observe { [weak self] in self?.refresh() }; refresh()
    }
    var groups: [CalendarGroupState] {
        catalog.accounts.compactMap { account in
            let all = catalog.calendars.filter { $0.accountID == account.id }
            let filtered = all.filter { search.isEmpty || $0.name.localizedStandardContains(search) || account.name.localizedStandardContains(search) }
            guard !filtered.isEmpty else { return nil }
            return CalendarGroupState(account: account, calendars: filtered, selectedCount: all.filter { selectedIDs.contains($0.id) }.count, expanded: !search.isEmpty || expanded.contains(account.id))
        }
    }
    var selectedCount: Int { visibility.effectiveIDs.count }
    var missingCount: Int { selectedIDs.subtracting(Set(catalog.calendars.map(\.id))).count }
    var systemConnected: Bool { coordinator.state(for: .system) == .connected }
    var hasConnectedProvider: Bool { coordinator.connectionState == .connected }
    func refresh() {
        catalog = coordinator.catalog(); selectedIDs = visibility.selectedIDs
        providers = CalendarProviderKind.allCases.map { ProviderCardState(kind: $0, state: coordinator.state(for: $0)) }
    }
    func requestSystemConnection() {
        requestConnection(.system)
    }
    func requestConnection(_ kind: CalendarProviderKind) {
        if kind == .system && coordinator.state(for: kind) == .permissionDenied {
            do { try permissionSettings.openCalendarSettings() } catch { self.error = error.localizedDescription }; return
        }
        Task { await connect(kind) }
    }
    func setExpanded(_ id: AccountID, expanded value: Bool) { if value { expanded.insert(id) } else { expanded.remove(id) } }
    func connectSystem() async {
        await connect(.system)
    }
    func connect(_ kind: CalendarProviderKind) async {
        guard !connecting else { return }
        connecting = true; error = nil; defer { connecting = false; refresh() }
        do { try await coordinator.connect(kind); visibility.initializeIfNeeded() }
        catch { self.error = error.localizedDescription }
    }
    func toggleGroup(_ id: AccountID) { if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) } }
    func setCalendar(_ id: CalendarID, visible: Bool) { visibility.set([id], visible: visible); refresh() }
    func selectGroup(_ id: AccountID, visible: Bool) {
        // Group actions include the entire account, not merely the currently searched rows.
        visibility.set(Set(catalog.calendars.filter { $0.accountID == id }.map(\.id)), visible: visible); refresh()
    }
}
