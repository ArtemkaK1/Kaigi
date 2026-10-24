import XCTest
import EventKit
@testable import Meetrail

@MainActor final class CalendarIntegrationTests: XCTestCase {
    func testRealQAEventsThroughProductionReadOnlyGateway() async throws {
        let gateway = EventKitCalendarGateway()
        if gateway.access == .unknown { try await gateway.requestAccess() }
        guard gateway.access == .allowed else { throw XCTSkip("Real calendar permission has not been granted to this test host") }
        guard let qa = gateway.calendars.first(where: { $0.title == "Meetrail QA" }) else { throw XCTSkip("Run the standalone QA harness first") }
        let fixtureRange = DateInterval(start: Date.now.addingTimeInterval(-7 * 86400), duration: 14 * 86400)
        let fixtureEvents = try gateway.meetings(in: fixtureRange, calendarIDs: [qa.id])
        guard let anchor = fixtureEvents.first(where: { $0.title.contains("One-time Meet") }) else { throw XCTSkip("Complete QA fixtures are not installed") }
        let start = Calendar.current.startOfDay(for: anchor.start)
        let today = try gateway.meetings(in: DateInterval(start: start, duration: 86400), calendarIDs: [qa.id])
        XCTAssertGreaterThanOrEqual(today.count, 7)
        XCTAssertTrue(today.allSatisfy { $0.title.hasPrefix("[Meetrail QA]") })
        XCTAssertEqual(Set(today.flatMap(\.links).map(\.provider)), ["Google Meet", "Zoom", "Microsoft Teams", "Webex"])
        XCTAssertTrue(today.contains { $0.allDay })
        XCTAssertTrue(today.contains { $0.links.isEmpty })
        XCTAssertTrue(today.contains { $0.recurring })
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let thirdDay = Calendar.current.date(byAdding: .day, value: 2, to: start)!
        let tomorrowEvents = try gateway.meetings(in: Calendar.current.dateInterval(of: .day, for: tomorrow)!, calendarIDs: [qa.id])
        XCTAssertFalse(tomorrowEvents.contains { $0.title.contains("Rescheduled series") })
        let exceptions = try gateway.meetings(in: Calendar.current.dateInterval(of: .day, for: thirdDay)!, calendarIDs: [qa.id]).filter { $0.title.contains("Rescheduled series") }
        XCTAssertEqual(exceptions.count, 2)
        XCTAssertEqual(Set(exceptions.map(\.occurrenceKey)).count, 2, "Moved exception must not merge with regular occurrence on the same date")
        let repository = try NoteRepository(inMemory: true)
        let recurring = try XCTUnwrap(today.first { $0.title.contains("Daily Zoom") })
        let note = try repository.note(for: recurring)
        try repository.save(note, text: "Synthetic real-calendar persistence check")
        let refetched = try XCTUnwrap(gateway.meetings(in: DateInterval(start: start, duration: 86400), calendarIDs: [qa.id]).first { $0.id == recurring.id })
        XCTAssertEqual(try repository.note(for: refetched).text, note.text)
    }
}
