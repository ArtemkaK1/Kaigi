#if DEBUG
import Foundation

extension SampleCalendarGateway {
    /// This factory cannot replace the production provider without explicit --sample.
    static func forLaunch(arguments: [String]) -> SampleCalendarGateway? {
        guard arguments.contains("--sample") else { return nil }
        let scaleTest = arguments.contains("--fifty-calendars")
        let fixture = SampleCalendarGateway(empty: arguments.contains("--empty"), meetingCount: arguments.contains("--fifteen-meetings") ? 15 : arguments.contains("--one-meeting") ? 1 : 3, calendarCount: scaleTest ? 50 : 1, longTitles: arguments.contains("--long-titles"))
        // An explicit scale test retains its 50 calendars even if flags are combined.
        if arguments.contains("--marketing-fixtures") && !scaleTest {
            fixture.usesMarketingFixtures = true
            fixture.calendars = marketingCatalog.calendars.map { CalendarChoice(id: $0.id.rawValue, title: $0.name) }
        }
        return fixture
    }

    static let marketingCatalog: CalendarCatalog = {
        let groups: [(String, [(String, CalendarColor)])] = [
            ("Work Account", [
                ("Work", CalendarColor(red: 0.28, green: 0.50, blue: 0.78)),
                ("Team Meetings", CalendarColor(red: 0.18, green: 0.58, blue: 0.52)),
                ("Project Reviews", CalendarColor(red: 0.48, green: 0.39, blue: 0.73))
            ]),
            ("Personal Account", [
                ("Personal", CalendarColor(red: 0.85, green: 0.50, blue: 0.25)),
                ("Family", CalendarColor(red: 0.40, green: 0.62, blue: 0.34)),
                ("Birthdays", CalendarColor(red: 0.74, green: 0.40, blue: 0.60))
            ]),
            ("Subscribed Calendars", [
                ("Holidays", CalendarColor(red: 0.78, green: 0.33, blue: 0.37)),
                ("Travel", CalendarColor(red: 0.26, green: 0.61, blue: 0.73))
            ])
        ]
        var accounts: [CalendarAccount] = []
        var calendars: [CalendarDescriptor] = []
        for (index, group) in groups.enumerated() {
            let account = CalendarAccount(id: AccountID(rawValue: "sample-account-\(index)"), provider: .system, name: group.0, state: .connected)
            accounts.append(account)
            for (name, color) in group.1 {
                let id = calendars.isEmpty ? "sample" : "sample-\(calendars.count)"
                calendars.append(CalendarDescriptor(id: CalendarID(rawValue: id), accountID: account.id, name: name, color: color, isAvailable: true))
            }
        }
        return CalendarCatalog(accounts: accounts, calendars: calendars)
    }()
}
#endif
