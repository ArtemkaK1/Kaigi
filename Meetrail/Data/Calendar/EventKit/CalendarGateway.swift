import Foundation
import EventKit
import AppKit

enum CalendarAccess: Equatable { case unknown, allowed, denied }
@MainActor protocol CalendarGateway: AnyObject {
    var access: CalendarAccess { get }
    var calendars: [CalendarChoice] { get }
    var onChange: (() -> Void)? { get set }
    func requestAccess() async throws
    func meetings(in interval: DateInterval, calendarIDs: Set<String>) throws -> [Meeting]
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
@MainActor final class EventKitCalendarGateway: CalendarGateway {
    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    var onChange: (() -> Void)?
    var access: CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .allowed
        case .notDetermined: .unknown
        default: .denied
        }
    }
    var calendars: [CalendarChoice] {
        guard access == .allowed else { return [] }
        return store.calendars(for: .event).map { CalendarChoice(id: $0.calendarIdentifier, title: $0.title) }
    }
    init() {
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.onChange?() }
        }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    func requestAccess() async throws { _ = try await store.requestFullAccessToEvents() }
    func meetings(in interval: DateInterval, calendarIDs: Set<String>) throws -> [Meeting] {
        guard access == .allowed else { return [] }
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
}

// Adapter implementation shares the existing read-only EventKit gateway.
extension EventKitCalendarGateway: CalendarProvider {
    var kind: CalendarProviderKind { .system }
    var connectionState: AccountConnectionState {
        switch access { case .allowed: .connected; case .denied: .permissionDenied; case .unknown: .notConnected }
    }
    func connect() async throws { try await requestAccess() }
    func catalog() -> CalendarCatalog {
        guard access == .allowed else { return .empty }
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
    func events(in interval: DateInterval, visibleCalendarIDs: Set<CalendarID>) async throws -> [CalendarEvent] {
        try meetings(in: interval, calendarIDs: Set(visibleCalendarIDs.map(\.rawValue)))
    }
}
