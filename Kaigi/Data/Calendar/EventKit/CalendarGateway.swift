import Foundation
import EventKit
import AppKit

nonisolated enum CalendarAccess: Equatable, Sendable { case unknown, allowed, denied }
@MainActor protocol CalendarGateway: AnyObject {
    var access: CalendarAccess { get }
    var calendars: [CalendarChoice] { get }
    var onChange: (() -> Void)? { get set }
    func requestAccess() async throws
    func meetings(in interval: DateInterval, calendarIDs: Set<String>) async throws -> [Meeting]
}

@MainActor final class SampleCalendarGateway: CalendarGateway, CalendarProvider {
    let empty: Bool
    let meetingCount: Int
    let longTitles: Bool
    var access = CalendarAccess.allowed
    var calendars: [CalendarChoice]
    var onChange: (() -> Void)?
    var kind: CalendarProviderKind { .system }
    var connectionState: AccountConnectionState { access == .allowed ? .connected : access == .denied ? .permissionDenied : .notConnected }
    init(empty: Bool = false, meetingCount: Int = 3, calendarCount: Int = 1, longTitles: Bool = false) {
        self.empty = empty; self.meetingCount = meetingCount; self.longTitles = longTitles
        calendars = (0..<calendarCount).map { CalendarChoice(id: $0 == 0 ? "sample" : "sample-\($0)", title: $0 == 0 ? "Sample calendar" : "Calendar \($0 + 1)") }
    }
    func requestAccess() async throws { access = .allowed }
    func connect() async throws { try await requestAccess() }
    func catalog() -> CalendarCatalog {
        guard access == .allowed else { return .empty }
        let count = max(1, (calendars.count + 9) / 10)
        let accounts = (0..<count).map { CalendarAccount(id: AccountID(rawValue: "sample-account-\($0)"), provider: .system, name: "Sample account \($0 + 1)", state: .connected) }
        let descriptors = calendars.enumerated().map { index, calendar in
            CalendarDescriptor(id: CalendarID(rawValue: calendar.id), accountID: accounts[index / 10].id, name: calendar.title,
                               color: CalendarColor(red: Double(index % 3 + 1) / 4, green: 0.5, blue: 0.6), isAvailable: true)
        }
        return CalendarCatalog(accounts: accounts, calendars: descriptors)
    }
    func events(in interval: DateInterval, visibleCalendarIDs: Set<CalendarID>) async throws -> [CalendarEvent] {
        try meetings(in: interval, calendarIDs: Set(visibleCalendarIDs.map(\.rawValue)))
    }
    func meetings(in interval: DateInterval, calendarIDs: Set<String>) throws -> [Meeting] {
        guard !empty, access == .allowed, calendarIDs.contains("sample") else { return [] }
        let base = [(9, "Product conversation", "https://meet.google.com/aaa-bbbb-ccc"), (11, "Design review", "https://example.invalid/meeting"), (14, "Weekly planning", "")]
        return (0..<meetingCount).map { index in
            let entry = index < base.count ? base[index] : (9 + index / 2, "Working session \(index + 1)", "")
            let start = Calendar.current.date(bySettingHour: min(entry.0, 23), minute: index < 3 ? 0 : (index % 2) * 30, second: 0, of: interval.start)!
            let title = longTitles ? entry.1 + " — extended synthetic agenda title for accessibility and compact layout review" : entry.1
            return Meeting(calendarID: "sample", calendarName: "Sample calendar", externalID: "sample-\(index)", eventID: "sample-\(index)", title: title, start: start, end: start.addingTimeInterval(1800), originalStart: start, recurring: index == 2, allDay: false, links: URL(string: entry.2).map { [MeetingLink(url: $0, provider: index == 0 ? "Google Meet" : "Web link", recognized: index == 0)] } ?? [])
        }
    }
}

// This production gateway deliberately has no save/remove/create methods.
// The worker owns EventKit objects; only immutable domain snapshots cross actors.
private actor EventKitReader {
    private lazy var store = EKEventStore()
    var access: CalendarAccess {
        StartupTrace.mark("authorization.begin")
        defer { StartupTrace.mark("authorization.end") }
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .allowed
        case .notDetermined: return .unknown
        default: return .denied
        }
    }
    func snapshot() -> (CalendarAccess, CalendarCatalog) { (access, catalog()) }
    func requestAccess() async throws { _ = try await store.requestFullAccessToEvents() }
    func meetings(in interval: DateInterval, calendarIDs: Set<String>) throws -> [Meeting] {
        StartupTrace.mark("events.begin")
        defer { StartupTrace.mark("events.end") }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        let selected = store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
        guard !selected.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: selected)
        return store.events(matching: predicate).compactMap { event in
            guard event.status != .canceled,
                  !(event.attendees ?? []).contains(where: { $0.isCurrentUser && $0.participantStatus == .declined }),
                  let start = event.startDate, let end = event.endDate,
                  let external = event.calendarItemExternalIdentifier, !external.isEmpty,
                  let calendar = event.calendar else { return nil }
            let meeting = Meeting(calendarID: calendar.calendarIdentifier, calendarName: calendar.title, externalID: external,
                                  eventID: event.eventIdentifier ?? external, title: event.title ?? "Untitled meeting", start: start, end: end,
                                  originalStart: event.occurrenceDate ?? start, recurring: event.hasRecurrenceRules || event.isDetached,
                                  allDay: event.isAllDay, links: MeetingLinkResolver().resolve(url: event.url, location: event.location, notes: event.notes))
            return EventNormalizer().normalize(meeting, canceled: event.status == .canceled, declined: (event.attendees ?? []).contains { $0.isCurrentUser && $0.participantStatus == .declined }, interval: interval)
        }
    }
    func catalog() -> CalendarCatalog {
        StartupTrace.mark("catalog.begin")
        defer { StartupTrace.mark("catalog.end") }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return .empty }
        let calendars = store.calendars(for: .event)
        var sources: [String: CalendarAccount] = [:]
        let descriptors = calendars.map { calendar in
            let accountID = AccountID(rawValue: "system:\(calendar.source.sourceIdentifier)")
            sources[accountID.rawValue] = CalendarAccount(id: accountID, provider: .system, name: calendar.source.title, state: .connected)
            let color = NSColor(cgColor: calendar.cgColor)?.usingColorSpace(.sRGB)
            return CalendarDescriptor(id: CalendarID(rawValue: calendar.calendarIdentifier), accountID: accountID, name: calendar.title,
                                      color: color.map { CalendarColor(red: $0.redComponent, green: $0.greenComponent, blue: $0.blueComponent) } ?? .neutral,
                                      isAvailable: true)
        }
        return CalendarCatalog(accounts: sources.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
                               calendars: descriptors.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
    }
}

@MainActor final class EventKitCalendarGateway: CalendarGateway, CalendarProvider {
    private let reader = EventKitReader()
    private var observers: [NSObjectProtocol] = []
    private var cachedCatalog = CalendarCatalog.empty
    private var catalogTask: Task<(CalendarAccess, CalendarCatalog), Never>?
    private var catalogGeneration = 0
    private var prepared = false
    private var cachedAccess = CalendarAccess.unknown
    var onChange: (() -> Void)?
    var kind: CalendarProviderKind { .system }
    var access: CalendarAccess { cachedAccess }
    var calendars: [CalendarChoice] { cachedCatalog.calendars.map { CalendarChoice(id: $0.id.rawValue, title: $0.name) } }
    var connectionState: AccountConnectionState {
        switch access { case .allowed: .connected; case .denied: .permissionDenied; case .unknown: .notConnected }
    }
    init() {
        StartupTrace.mark("eventkit.created")
        observers.append(NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.invalidate() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.prepared else { return }
                let access = await self.reader.access
                guard access != self.cachedAccess else { return }
                self.invalidate()
            }
        })
    }
    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
    func prepare() async {
        while !prepared {
            let generation = catalogGeneration
            if catalogTask == nil { catalogTask = Task { await reader.snapshot() } }
            let value = await catalogTask!.value
            guard generation == catalogGeneration else { continue }
            cachedAccess = value.0; cachedCatalog = value.1; prepared = true; catalogTask = nil
        }
    }
    private func invalidate() {
        catalogGeneration += 1; prepared = false; catalogTask = nil
        let generation = catalogGeneration
        Task {
            await prepare()
            guard generation == catalogGeneration else { return }
            onChange?()
        }
    }
    func requestAccess() async throws {
        try await reader.requestAccess()
        catalogGeneration += 1; prepared = false; catalogTask = nil
        await prepare()
    }
    func connect() async throws { try await requestAccess() }
    func catalog() -> CalendarCatalog { access == .allowed ? cachedCatalog : .empty }
    func meetings(in interval: DateInterval, calendarIDs: Set<String>) async throws -> [Meeting] {
        await prepare(); try Task.checkCancellation()
        return try await reader.meetings(in: interval, calendarIDs: calendarIDs)
    }
    func events(in interval: DateInterval, visibleCalendarIDs: Set<CalendarID>) async throws -> [CalendarEvent] {
        try await meetings(in: interval, calendarIDs: Set(visibleCalendarIDs.map(\.rawValue)))
    }
}
