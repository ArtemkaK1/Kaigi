import Foundation
import EventKit

enum CalendarAccess: Equatable { case unknown, allowed, denied }
@MainActor protocol CalendarGateway: AnyObject {
    var access: CalendarAccess { get }
    var calendars: [CalendarChoice] { get }
    var onChange: (() -> Void)? { get set }
    func requestAccess() async throws
    func meetings(in interval: DateInterval, calendarIDs: Set<String>) throws -> [Meeting]
}

@MainActor final class SampleCalendarGateway: CalendarGateway {
    let empty: Bool
    init(empty: Bool = false) { self.empty = empty }
    var access = CalendarAccess.allowed
    var calendars = [CalendarChoice(id: "sample", title: "Sample calendar")]
    var onChange: (() -> Void)?
    func requestAccess() async throws {}
    func meetings(in interval: DateInterval, calendarIDs: Set<String>) throws -> [Meeting] {
        guard !empty, calendarIDs.contains("sample") else { return [] }
        return [(9, "Product conversation", "https://meet.google.com/aaa-bbbb-ccc"), (11, "Design review", "https://example.invalid/meeting"), (14, "Weekly planning", "")].enumerated().map { index, item in
            let start = Calendar.current.date(bySettingHour: item.0, minute: 0, second: 0, of: interval.start)!
            return Meeting(calendarID: "sample", calendarName: "Sample calendar", externalID: "sample-\(index)", eventID: "sample-\(index)", title: item.1, start: start, end: start.addingTimeInterval(1800), originalStart: start, recurring: index == 2, allDay: false, links: URL(string: item.2).map { [MeetingLink(url: $0, provider: index == 0 ? "Google Meet" : "Web link", recognized: index == 0)] } ?? [])
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
