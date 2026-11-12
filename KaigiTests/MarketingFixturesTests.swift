import Foundation
import Testing
@testable import Meetrail

@MainActor struct MarketingFixturesTests {
    @Test func deterministicNamesColorsAndStableIDs() throws {
        let args = ["--sample", "--marketing-fixtures"]
        let first = try #require(SampleCalendarGateway.forLaunch(arguments: args))
        let second = try #require(SampleCalendarGateway.forLaunch(arguments: args))
        let catalog = first.catalog()
        #expect(catalog.accounts.map(\.name) == ["Work Account", "Personal Account", "Subscribed Calendars"])
        #expect(catalog.calendars.map(\.name) == ["Work", "Team Meetings", "Project Reviews", "Personal", "Family", "Birthdays", "Holidays", "Travel"])
        #expect(catalog.accounts == second.catalog().accounts)
        #expect(catalog.calendars == second.catalog().calendars)
        #expect(catalog.accounts.allSatisfy { $0.provider == .system })
        #expect(catalog.calendars.map(\.id.rawValue) == ["sample"] + (1..<8).map { "sample-\($0)" })
        #expect(Set(catalog.calendars.map(\.color)).count == 8)
        #expect(catalog.accounts.map { account in catalog.calendars.filter { $0.accountID == account.id }.count } == [3, 3, 2])
    }

    @Test func marketingIsOptInAndCannotReplaceTheScaleFixture() throws {
        #expect(SampleCalendarGateway.forLaunch(arguments: []) == nil)
        #expect(SampleCalendarGateway.forLaunch(arguments: ["--marketing-fixtures"]) == nil)
        let normal = try #require(SampleCalendarGateway.forLaunch(arguments: ["--sample"]))
        #expect(normal.catalog().accounts.map(\.name) == ["Sample account 1"])
        #expect(normal.calendars.map(\.title) == ["Sample calendar"])
        for extra in [[], ["--marketing-fixtures"]] {
            let scale = try #require(SampleCalendarGateway.forLaunch(arguments: ["--sample", "--fifty-calendars"] + extra))
            #expect(scale.calendars.count == 50 && scale.catalog().accounts.count == 5)
            #expect(scale.calendars[41].id == "sample-41" && scale.calendars[41].title == "Calendar 42")
        }
    }

    @Test func meetingsNotesAndJoinKeepTheirStableAssociations() async throws {
        let provider = try #require(SampleCalendarGateway.forLaunch(arguments: ["--sample", "--marketing-fixtures"]))
        let fixture = try TestComposition(provider: provider)
        defer { fixture.clearPreferences() }
        let day = try #require(Calendar.current.dateInterval(of: .day, for: .now))
        let normal = try SampleCalendarGateway().meetings(in: day, calendarIDs: ["sample"])
        let marketing = try provider.meetings(in: day, calendarIDs: ["sample"])
        #expect(marketing.map(\.id) == normal.map(\.id))
        #expect(marketing.map(\.links) == normal.map(\.links))
        #expect(marketing.allSatisfy { $0.calendarName == "Work" })
        await fixture.container.agenda.load()
        #expect(fixture.container.access.toggles == .released)
        #expect(fixture.container.agenda.meetings.count == 3)
        let meeting = try #require(fixture.container.agenda.meetings.first)
        fixture.container.agenda.select(meeting)
        let detail = try #require(fixture.container.agenda.detail)
        detail.updateText("Synthetic marketing-profile note")
        #expect(try fixture.store.fetchNotes().first?.text == "Synthetic marketing-profile note")
        let link = try #require(meeting.links.first)
        fixture.container.agenda.join(link)
        #expect(fixture.actions.opened == [link.url])
        let persisted = fixture.defaults.persistentDomain(forName: fixture.suite) ?? [:]
        #expect(!String(describing: persisted).contains("Work Account"))
        #expect(!String(describing: persisted).contains("marketing-fixtures"))
    }

    @Test func normalAndMarketingSessionsAreIsolated() async throws {
        let provider = try #require(SampleCalendarGateway.forLaunch(arguments: ["--sample", "--marketing-fixtures"]))
        let marketing = try TestComposition(provider: provider)
        let normal = try TestComposition()
        defer { marketing.clearPreferences(); normal.clearPreferences() }
        await marketing.container.agenda.load()
        await normal.container.agenda.load()
        marketing.container.accounts.selectGroup(provider.catalog().accounts[0].id, visible: false)
        #expect(marketing.container.accounts.selectedCount == 5)
        #expect(normal.container.accounts.selectedCount == 1)
        #expect(normal.provider.catalog().accounts[0].name == "Sample account 1")
        #expect(try normal.store.fetchNotes().isEmpty)
    }
}
