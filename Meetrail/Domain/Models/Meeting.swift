import Foundation

struct Meeting: Identifiable, Hashable, Sendable {
    var id: String { occurrenceKey }
    let calendarID: String
    let calendarName: String
    let externalID: String
    let eventID: String
    let title: String
    let start: Date
    let end: Date
    let originalStart: Date
    let recurring: Bool
    let allDay: Bool
    let links: [MeetingLink]
    var providerKind: CalendarProviderKind = .system
    var accountID: String = ""
    // Never match across calendars or by a title/time similarity heuristic.
    var seriesKey: String { MeetingAssociation.seriesKey(calendarID: calendarID, externalID: externalID, provider: providerKind, accountID: accountID) }
    var occurrenceKey: String { MeetingAssociation.occurrenceKey(seriesKey: seriesKey, recurring: recurring, originalStart: originalStart) }
    func overlaps(_ interval: DateInterval) -> Bool { start < interval.end && end > interval.start }
}

struct CalendarChoice: Identifiable, Sendable {
    let id: String
    let title: String
}

struct MeetingLink: Hashable, Identifiable, Sendable {
    var id: String { url.absoluteString }
    let url: URL
    let provider: String
    let recognized: Bool
}

struct DaySelection {
    var date: Date
    var calendar: Calendar = .current
    var interval: DateInterval { calendar.dateInterval(of: .day, for: date)! }
    mutating func move(_ days: Int) { date = calendar.date(byAdding: .day, value: days, to: date)! }
}
