import Testing
import Foundation
@testable import Meetrail

@MainActor struct StabilizationTests {
    @Test func returningUserMigrationPreservesDataAndSelection() throws {
        let store = try NoteRepository(inMemory: true)
        let meeting = KaigiTests().meeting()
        let original = try store.note(for: meeting); try store.save(original, text: "Existing synthetic note")
        let fixture = try TestComposition(firstRun: true, legacyIDs: ["legacy-selected", "temporarily-missing"], store: store)
        defer { fixture.clearPreferences() }
        #expect(fixture.container.onboarding.progress.disposition == .completed)
        #expect(fixture.preferences.selectedCalendarIDs == Set([CalendarID(rawValue: "legacy-selected"), CalendarID(rawValue: "temporarily-missing")]))
        #expect(try fixture.store.fetchNotes().first?.id.rawValue == original.id)
        #expect(try fixture.store.fetchNotes().first?.text == "Existing synthetic note")
    }
    @Test func existingEmptySelectionIsNotReplacedWithAllCalendars() async throws {
        let fixture = try TestComposition(calendars: 50, legacyIDs: []); defer { fixture.clearPreferences() }
        await fixture.container.agenda.load()
        #expect(fixture.container.visibility.effectiveIDs.isEmpty)
        #expect(fixture.preferences.selectedCalendarIDs == [])
    }
    @Test func firstRunDoesNotRequestCalendarAccessOnItsOwn() throws {
        let fixture = try TestComposition(firstRun: true); defer { fixture.clearPreferences() }
        #expect(fixture.provider.access == .unknown)
        #expect(fixture.preferences.selectedCalendarIDs == nil)
        #expect(fixture.container.onboarding.stage == .welcome)
        #expect(fixture.container.onboarding.shouldAutomaticallyPresent)
        fixture.container.onboarding.next()
        #expect(fixture.provider.access == .unknown)
        #expect(fixture.container.onboarding.stage == .connect)
    }
    @Test func onboardingSkipAndProgressSurviveReconstruction() throws {
        let fixture = try TestComposition(firstRun: true); defer { fixture.clearPreferences() }
        let first = fixture.container.onboarding
        first.next(); first.skip()
        let resumed = OnboardingViewModel(preferences: fixture.preferences, accounts: fixture.container.accounts, closeWindow: {})
        #expect(resumed.stage == .connect)
        #expect(!resumed.shouldAutomaticallyPresent)
        resumed.next()
        let another = OnboardingViewModel(preferences: fixture.preferences, accounts: fixture.container.accounts, closeWindow: {})
        #expect(another.stage == .selection)
        #expect(!another.shouldAutomaticallyPresent)
        another.next(); another.next()
        #expect(fixture.preferences.onboardingProgress?.disposition == .completed)
    }
    @Test func fiftyCalendarsAreGroupedSearchableAndPersisted() async throws {
        let fixture = try TestComposition(calendars: 50, firstRun: true); defer { fixture.clearPreferences() }
        let model = fixture.container.accounts
        await model.connectSystem()
        #expect(model.selectedCount == 50)
        #expect(model.groups.count == 5)
        #expect(model.groups.allSatisfy { $0.calendars.count == 10 && !$0.expanded })
        let group = model.groups[0]
        model.setExpanded(group.id, expanded: true); #expect(model.groups[0].expanded)
        model.search = "Calendar 42"
        #expect(model.groups.count == 1)
        #expect(model.groups[0].calendars.count == 1)
        let searchedGroup = model.groups[0].id
        model.selectGroup(searchedGroup, visible: false)
        #expect(model.selectedCount == 40) // Whole-account action, even during search.
        model.selectGroup(searchedGroup, visible: true)
        #expect(model.selectedCount == 50)
        let restored = AppPreferencesStore(defaults: fixture.defaults)
        #expect(restored.selectedCalendarIDs?.count == 50)
    }
    @Test func refreshRenameAndRevocationRetainCalendarIDs() async throws {
        let fixture = try TestComposition(calendars: 50); defer { fixture.clearPreferences() }
        await fixture.container.agenda.load()
        let model = fixture.container.accounts; model.refresh()
        let firstID = CalendarID(rawValue: "sample")
        model.setCalendar(firstID, visible: false)
        fixture.provider.calendars[0] = CalendarChoice(id: "sample", title: "Renamed calendar")
        fixture.provider.onChange?()
        #expect(model.catalog.calendars.contains { $0.name == "Renamed calendar" })
        #expect(!model.selectedIDs.contains(firstID))
        fixture.provider.access = .denied; fixture.provider.onChange?()
        #expect(model.selectedCount == 0)
        #expect(model.missingCount == 49)
        #expect(fixture.preferences.selectedCalendarIDs?.count == 49)
        fixture.provider.access = .allowed; fixture.provider.onChange?()
        #expect(model.selectedCount == 49)
    }
    @Test func unavailableProviderCardsNeverFakeAConnection() async throws {
        let fixture = try TestComposition(firstRun: true); defer { fixture.clearPreferences() }
        #expect(fixture.container.accounts.providers.count == 6)
        #expect(fixture.container.accounts.providers.filter { $0.state == .comingSoon }.count == 5)
        do { try await fixture.container.coordinator.connect(.google); Issue.record("Unregistered provider must not authenticate") }
        catch { #expect(error is CalendarDomainError) }
        #expect(fixture.provider.access == .unknown)
    }
    @Test func explicitDeniedConnectionOpensSettingsRatherThanSimulatingSuccess() throws {
        let fixture = try TestComposition(firstRun: true); defer { fixture.clearPreferences() }
        fixture.provider.access = .denied; fixture.provider.onChange?()
        fixture.container.accounts.requestSystemConnection()
        #expect(fixture.actions.permissionSettings == 1)
        #expect(fixture.provider.access == .denied)
    }
    @Test func providerNamespacingPreservesLegacyKeysWithoutCrossProviderMerging() throws {
        var system = KaigiTests().meeting()
        #expect(system.seriesKey == "calendar|series")
        let legacyKey = system.occurrenceKey
        system.providerKind = .google; system.accountID = "account-A"
        #expect(system.occurrenceKey != legacyKey)
        let googleKey = system.occurrenceKey
        system.providerKind = .microsoft
        #expect(system.occurrenceKey != googleKey)
        let first = MeetingAssociation.seriesKey(calendarID: "c", externalID: "d", provider: .google, accountID: "a|b")
        let second = MeetingAssociation.seriesKey(calendarID: "b|c", externalID: "d", provider: .google, accountID: "a")
        #expect(first != second)
    }
    @Test func injectedProvidersUseTheSameVisibilitySelectionAndNoteUseCases() async throws {
        let fixture = try TestComposition(firstRun: true); defer { fixture.clearPreferences() }
        let event = KaigiTests().meeting()
        let google = StubCalendarProvider(kind: .google, event: event)
        let microsoft = StubCalendarProvider(kind: .microsoft, event: event)
        let coordinator = CalendarAccountCoordinator(providers: [google, microsoft])
        let visibility = CalendarVisibilityUseCase(preferences: fixture.preferences, coordinator: coordinator)
        let accounts = CalendarAccountsViewModel(coordinator: coordinator, visibility: visibility, permissionSettings: fixture.actions)
        #expect(accounts.providers.first { $0.kind == .google }?.canConnect == true)
        try await coordinator.connect(.google); try await coordinator.connect(.microsoft)
        visibility.initializeIfNeeded(); accounts.refresh()
        #expect(accounts.hasConnectedProvider && !accounts.systemConnected)
        #expect(accounts.providers.first { $0.kind == .google }?.connectionSummary == "Connected")
        #expect(accounts.selectedCount == 2 && accounts.groups.count == 2)
        let results = try await coordinator.events(in: DateInterval(start: event.start.addingTimeInterval(-1), end: event.end), visibleCalendarIDs: visibility.effectiveIDs)
        #expect(results.count == 2)
        let selection = MeetingSelectionUseCase(store: fixture.store)
        let first = try selection.select(results[0]); let second = try selection.select(results[1])
        #expect(first.id != second.id && first.seriesID != second.seriesID)
    }
    @Test func deduplicationRequiresIdentityAndRejectsAmbiguousEvents() throws {
        let first = KaigiTests().meeting()
        #expect(try CalendarEventDeduplicator().deduplicate([first, first]).count == 1)
        let unrelated = Meeting(calendarID: first.calendarID, calendarName: first.calendarName, externalID: first.externalID, eventID: "other", title: "Unrelated meeting", start: first.start, end: first.end, originalStart: first.originalStart, recurring: first.recurring, allDay: false, links: [])
        #expect(throws: CalendarDomainError.self) { try CalendarEventDeduplicator().deduplicate([first, unrelated]) }
    }
    @Test func saveFailureRetainsDraftAndCanBeRetried() async throws {
        let base = try NoteRepository(inMemory: true); let store = FailingNotesStore(base: base)
        let note = try store.openNote(for: KaigiTests().meeting())
        let actions = TestActions()
        let model = MeetingDetailViewModel(note: note, meeting: nil, notes: NoteUseCases(store: store), context: MeetingContextUseCase(store: store), ai: UnavailableAIService(), preferences: PreviewPreferencesService(), join: ConferenceJoinUseCase(opener: actions), actions: actions, onSaved: {})
        store.failWrites = true; model.updateText("Preserve this unsaved draft")
        #expect(model.text == "Preserve this unsaved draft")
        #expect(model.error != nil)
        #expect(try store.fetchNote(id: note.id)?.text == "")
        #expect(throws: CocoaError.self) { try model.flushDraft() }
        await model.exportCurrentDraft()
        #expect(actions.exports.first?.text.contains("Preserve this unsaved draft") == true)
        store.failWrites = false; model.retrySave()
        #expect(model.saveStatus == "Saved locally")
        #expect(try store.fetchNote(id: note.id)?.text == "Preserve this unsaved draft")
    }
    @Test func realStructuredInferenceAndUnsupportedLanguage() async throws {
        let service = AIServiceFactory.make()
        if let reason = service.unavailableReason { print("REAL_STRUCTURE_UNAVAILABLE: \(reason)"); return }
        let source = "We discussed the project draft. No decision was made. Should we review the scope next week?"
        let result = try await service.refine(source, action: .structure)
        #expect(result.text.contains("## Topics"))
        #expect(result.text.contains("## Decisions"))
        #expect(result.text.contains("## Open questions"))
        let bullets = result.text.components(separatedBy: "\n").filter { $0.hasPrefix("- ") }.map { String($0.dropFirst(2)) }
        #expect(!bullets.isEmpty && bullets.allSatisfy { source.contains($0) })
        print("REAL_STRUCTURE_PREVIEW: \(result.text)") // Synthetic source only.
        await #expect(throws: RefinementFailure.self) {
            _ = try await service.refine("Ninakumbuka mkutano wetu wa jana. Tutazungumza kuhusu mpango mpya kesho.", action: .cleanUp)
        }
    }
    @Test func aiPreviewPreservesOriginalAndRejectsStaleApplication() async throws {
        let fixture = try TestComposition(ai: MockAIRefinementService(result: "Reviewed result")); defer { fixture.clearPreferences() }
        let record = try fixture.store.openNote(for: KaigiTests().meeting())
        let model = fixture.container.detail(note: record, meeting: nil)
        model.updateText("Rough original")
        model.refine(.cleanUp); await model.waitForRefinement()
        #expect(model.preview?.text == "Reviewed result")
        #expect(try fixture.store.fetchNote(id: record.id)?.text == "Rough original")
        model.updateText("Changed while reviewing"); model.applyPreview()
        #expect(try fixture.store.fetchNote(id: record.id)?.text == "Changed while reviewing")
        #expect(model.error != nil)
        model.discardPreview(); model.refine(.structure); await model.waitForRefinement(); model.applyPreview()
        #expect(try fixture.store.fetchNote(id: record.id)?.text == "Reviewed result")
        #expect(try fixture.store.fetchRevisions(id: record.id).contains { $0.text == "Changed while reviewing" })
        #expect(try fixture.store.fetchNote(id: record.id)?.confirmedContext == "")
    }
    @Test func floatingAndAgendaEditorsShareTheSamePresentationState() throws {
        let fixture = try TestComposition(); defer { fixture.clearPreferences() }
        let note = try fixture.store.openNote(for: KaigiTests().meeting())
        let agendaDetail = fixture.container.detail(note: note, meeting: nil)
        let floating = try fixture.container.detail(id: note.id)
        #expect(agendaDetail === floating)
        agendaDetail.updateText("Shared draft")
        #expect(floating.text == "Shared draft")
    }
}
