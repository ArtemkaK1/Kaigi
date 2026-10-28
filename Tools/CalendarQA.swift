// Separate local QA executable; never part of the Kaigi production target.
import AppKit
import EventKit

struct Manifest: Codable { let calendarID: String; var ids: [String] }
let manifestURL = URL(fileURLWithPath: "/tmp/meetrail-qa-manifest.json")
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 540, height: 220), styleMask: [.titled, .closable], backing: .buffered, defer: false)
window.title = "Kaigi Calendar QA"
let label = NSTextField(wrappingLabelWithString: "Requesting calendar access for isolated, attendee-free QA fixtures…")
label.frame = NSRect(x: 24, y: 24, width: 490, height: 160); window.contentView?.addSubview(label)
window.makeKeyAndOrderFront(nil); app.activate(ignoringOtherApps: true)
let store = EKEventStore()
Task { @MainActor in
    do {
        guard try await store.requestFullAccessToEvents() else { throw NSError(domain: "QA", code: 1, userInfo: [NSLocalizedDescriptionKey: "Calendar permission denied. No fixtures created."]) }
        if CommandLine.arguments.contains("--cleanup") {
            let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
            for id in manifest.ids {
                if let event = store.event(withIdentifier: id), event.calendar.calendarIdentifier == manifest.calendarID,
                   event.title.hasPrefix("[Meetrail QA]"), (event.attendees ?? []).isEmpty {
                    try store.remove(event, span: .futureEvents, commit: true)
                }
            }
            try FileManager.default.removeItem(at: manifestURL)
            label.stringValue = "Removed only fixtures listed in this workflow’s local manifest. The QA calendar has been retained."
        } else if let index = CommandLine.arguments.firstIndex(of: "--own-link"), CommandLine.arguments.count > index + 1 {
            var manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
            guard let calendar = store.calendar(withIdentifier: manifest.calendarID), calendar.title == "Meetrail QA",
                  let link = URL(string: CommandLine.arguments[index + 1]), link.scheme == "https", link.host == "meet.google.com" else {
                throw NSError(domain: "QA", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid owned-link fixture request"])
            }
            let event = EKEvent(eventStore: store); event.calendar = calendar; event.title = "[Meetrail QA] Owned conference check"
            event.startDate = Date.now.addingTimeInterval(180); event.endDate = event.startDate.addingTimeInterval(600)
            event.url = link; event.notes = "Own-account conference check. No attendees."
            try store.save(event, span: .thisEvent, commit: true)
            manifest.ids.append(event.eventIdentifier)
            try JSONEncoder().encode(manifest).write(to: manifestURL, options: .atomic)
            label.stringValue = "Created one attendee-free owned-conference fixture. The link is stored only in your QA calendar, outside Git."
        } else if FileManager.default.fileExists(atPath: manifestURL.path) {
            label.stringValue = "A QA manifest already exists. Reusing existing fixtures; no duplicates created. Use --cleanup to remove them."
        } else {
            let calendars = store.calendars(for: .event)
            let calendar: EKCalendar
            if let existing = calendars.first(where: { $0.title == "Meetrail QA" && $0.allowsContentModifications }) { calendar = existing }
            else {
                guard let source = store.sources.first(where: { $0.sourceType == .local }) ?? store.defaultCalendarForNewEvents?.source else {
                    throw NSError(domain: "QA", code: 2, userInfo: [NSLocalizedDescriptionKey: "No writable calendar source. Add an account in Calendar and retry."])
                }
                calendar = EKCalendar(for: .event, eventStore: store); calendar.title = "Meetrail QA"; calendar.source = source
                try store.saveCalendar(calendar, commit: true)
            }
            var manifest = Manifest(calendarID: calendar.calendarIdentifier, ids: [])
            let day = Calendar.current.startOfDay(for: .now)
            let fixtures: [(String, Int, String?, EKRecurrenceFrequency?, Bool)] = [
                ("One-time Meet", 9, "https://meet.google.com/aaa-bbbb-ccc", nil, false),
                ("Daily Zoom", 10, "https://example.zoom.us/j/00000000000", .daily, false),
                ("Weekly Teams", 11, "https://teams.microsoft.com/l/meetup-join/qa-placeholder", .weekly, false),
                ("Overlap Webex", 11, "https://example.webex.com/meet/qa-placeholder", nil, false),
                ("No conference link", 14, nil, nil, false),
                ("All-day", 0, nil, nil, true),
                ("Rescheduled series", 15, nil, .daily, false)]
            // Persist the manifest after each successful save to allow recovery from interrupted setup.
            for fixture in fixtures {
                let event = EKEvent(eventStore: store); event.calendar = calendar; event.title = "[Meetrail QA] " + fixture.0
                event.startDate = Calendar.current.date(byAdding: .hour, value: fixture.1, to: day)!
                event.endDate = event.startDate.addingTimeInterval(fixture.4 ? 86400 : 2700)
                event.isAllDay = fixture.4; event.url = fixture.2.flatMap(URL.init(string:))
                event.notes = "Synthetic QA fixture. Placeholder URLs are not real conferences. No attendees."
                if let frequency = fixture.3 { event.recurrenceRules = [EKRecurrenceRule(recurrenceWith: frequency, interval: 1, end: EKRecurrenceEnd(occurrenceCount: 3))] }
                try store.save(event, span: .thisEvent, commit: true)
                manifest.ids.append(event.eventIdentifier)
                try JSONEncoder().encode(manifest).write(to: manifestURL, options: .atomic)
                if fixture.0 == "Rescheduled series" {
                    let tomorrow = day.addingTimeInterval(86400)
                    let events = store.events(matching: store.predicateForEvents(withStart: tomorrow, end: tomorrow.addingTimeInterval(86400), calendars: [calendar]))
                    if let occurrence = events.first(where: { $0.title == event.title }) {
                        occurrence.startDate = Calendar.current.date(byAdding: .day, value: 1, to: occurrence.startDate)!
                        occurrence.endDate = occurrence.startDate.addingTimeInterval(2700)
                        try store.save(occurrence, span: .thisEvent, commit: true)
                        manifest.ids.append(occurrence.eventIdentifier)
                        try JSONEncoder().encode(manifest).write(to: manifestURL, options: .atomic)
                    }
                }
            }
            label.stringValue = "Created 7 attendee-free fixture series/events in Meetrail QA, including a moved recurring exception. Placeholder links are for parser/opening tests only. Manifest: /tmp/meetrail-qa-manifest.json"
        }
    } catch { label.stringValue = "QA stopped: \(error.localizedDescription)" }
}
app.run()
