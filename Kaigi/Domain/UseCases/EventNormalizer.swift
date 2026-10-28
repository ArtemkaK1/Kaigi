import Foundation

nonisolated struct EventNormalizer {
    func normalize(_ meeting: Meeting, canceled: Bool, declined: Bool, interval: DateInterval) -> Meeting? {
        guard !canceled, !declined, !meeting.externalID.isEmpty, !meeting.calendarID.isEmpty,
              meeting.end > meeting.start, meeting.overlaps(interval) else { return nil }
        return meeting
    }
}
