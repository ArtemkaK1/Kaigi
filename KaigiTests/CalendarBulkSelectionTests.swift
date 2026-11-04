import AppKit
import Foundation
import Testing
@testable import Meetrail

@MainActor struct CalendarBulkSelectionTests {
    @Test func allStateUsesTheWholeAccountDuringFiltering() async throws {
        let fixture = try TestComposition(calendars: 50)
        defer { fixture.clearPreferences() }
        await fixture.container.agenda.load()
        let model = fixture.container.accounts
        model.refresh()
        let id = try #require(model.groups.first?.id)
        #expect(model.groups[0].allSelected && !model.groups[0].partiallySelected)
        model.setCalendar(CalendarID(rawValue: "sample"), visible: false)
        #expect(!model.groups[0].allSelected && model.groups[0].partiallySelected)
        model.search = "Calendar 2"
        let filtered = try #require(model.groups.first { $0.id == id })
        #expect(filtered.calendars.count == 1 && filtered.calendarCount == 10)
        #expect(filtered.selectedCount == 9 && filtered.partiallySelected)
        // The UI uses the same derived state to choose the next bulk operation.
        model.selectGroup(id, visible: !filtered.allSelected)
        #expect(try #require(model.groups.first { $0.id == id }).allSelected)
        model.selectGroup(id, visible: false)
        let empty = try #require(model.groups.first { $0.id == id })
        #expect(empty.selectedCount == 0 && !empty.allSelected && !empty.partiallySelected)
        #expect(model.selectedCount == 40)
        model.selectGroup(id, visible: !empty.allSelected)
        #expect(model.selectedCount == 50)
    }

    @Test func emptyBulkSelectionPersistsWithoutReinitializing() async throws {
        let provider = try #require(SampleCalendarGateway.forLaunch(arguments: ["--sample", "--marketing-fixtures"]))
        let fixture = try TestComposition(provider: provider)
        defer { fixture.clearPreferences() }
        await fixture.container.agenda.load()
        let model = fixture.container.accounts
        for group in model.groups { model.selectGroup(group.id, visible: false) }
        let restored = AppPreferencesStore(defaults: fixture.defaults)
        #expect(restored.selectedCalendarIDs == [])
        fixture.container.visibility.initializeIfNeeded()
        let reloaded = CalendarAccountsViewModel(coordinator: fixture.container.coordinator, visibility: CalendarVisibilityUseCase(preferences: restored, coordinator: fixture.container.coordinator), permissionSettings: fixture.actions)
        #expect(reloaded.selectedIDs.isEmpty)
        #expect(reloaded.groups.allSatisfy { !$0.allSelected && !$0.partiallySelected })
        await fixture.container.agenda.load()
        #expect(fixture.container.agenda.meetings.isEmpty)
    }

    @Test func missingIDsAndUnavailableCalendarsKeepTheirExistingSemantics() throws {
        let fixture = try TestComposition(legacyIDs: ["sample", "temporarily-missing"])
        defer { fixture.clearPreferences() }
        let source = SampleCalendarGateway.marketingCatalog
        let provider = MutableCatalogProvider(snapshot: CalendarCatalog(accounts: [source.accounts[0]], calendars: [source.calendars[0], CalendarDescriptor(id: source.calendars[1].id, accountID: source.accounts[0].id, name: "Unavailable", color: .neutral, isAvailable: false)]))
        let coordinator = CalendarAccountCoordinator(providers: [provider])
        let visibility = CalendarVisibilityUseCase(preferences: fixture.preferences, coordinator: coordinator)
        let model = CalendarAccountsViewModel(coordinator: coordinator, visibility: visibility, permissionSettings: fixture.actions)
        let id = try #require(model.groups.first?.id)
        #expect(model.groups[0].partiallySelected)
        model.selectGroup(id, visible: true)
        #expect(model.groups[0].allSelected)
        #expect(visibility.effectiveIDs == [CalendarID(rawValue: "sample")])
        #expect(model.selectedIDs.contains(CalendarID(rawValue: "temporarily-missing")))
        provider.snapshot = CalendarCatalog(accounts: source.accounts, calendars: [])
        provider.onChange?()
        #expect(model.selectedIDs.count == 3)
        provider.snapshot = CalendarCatalog(accounts: [source.accounts[0]], calendars: [source.calendars[0]])
        provider.onChange?()
        model.selectGroup(id, visible: false)
        #expect(model.selectedIDs == [source.calendars[1].id, CalendarID(rawValue: "temporarily-missing")])
    }

    @Test func nativeCheckboxDoesNotCycleIntoMixedState() throws {
        let button = MixedStateCheckbox.NativeCheckbox(checkboxWithTitle: "All", target: nil, action: nil)
        button.setButtonType(.switch)
        button.allowsMixedState = true
        button.setAccessibilityLabel("All calendars in Work Account")
        let transitions: [(NSControl.StateValue, NSControl.StateValue)] = [(.off, .on), (.mixed, .on), (.on, .off)]
        for (before, after) in transitions {
            button.state = before
            button.setNextState()
            #expect(button.state == after)
        }
        button.state = .mixed
        #expect(button.state == .mixed && button.allowsMixedState)
        // The hosted checkbox's AX role and mixed value are checked by UI automation.
        #expect(button.accessibilityLabel() == "All calendars in Work Account")
    }
}

@MainActor private final class MutableCatalogProvider: CalendarProvider {
    let kind = CalendarProviderKind.system
    let connectionState = AccountConnectionState.connected
    var snapshot: CalendarCatalog
    var onChange: (() -> Void)?
    init(snapshot: CalendarCatalog) { self.snapshot = snapshot }
    func catalog() -> CalendarCatalog { snapshot }
    func connect() async throws {}
    func events(in interval: DateInterval, visibleCalendarIDs: Set<CalendarID>) async throws -> [CalendarEvent] { [] }
}
