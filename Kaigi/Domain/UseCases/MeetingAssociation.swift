import Foundation

struct MeetingAssociation {
    // Keep the P0–P5 system-calendar keys byte-for-byte; never match using a title.
    static func seriesKey(calendarID: String, externalID: String, provider: CalendarProviderKind, accountID: String) -> String {
        let legacyKey = "\(calendarID)|\(externalID)"
        return provider == .system ? legacyKey : "provider|" + [provider.rawValue, accountID, calendarID, externalID].map { "\($0.utf8.count):\($0)" }.joined()
    }
    static func occurrenceKey(seriesKey: String, recurring: Bool, originalStart: Date) -> String {
        recurring ? "\(seriesKey)|\(originalStart.timeIntervalSince1970)" : "\(seriesKey)|single"
    }
}
