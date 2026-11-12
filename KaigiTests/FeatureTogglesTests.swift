import AppKit
import Foundation
import Observation
import Synchronization
import Testing
@testable import Meetrail

@MainActor struct FeatureTogglesTests {
    @Test(arguments: AppFeature.allCases) func defaultsAndIndependentConfigurations(_ feature: AppFeature) {
        let free: Set<AppFeature> = [.calendarManagement, .meetingReminders, .markdownExport, .launchAtLogin, .revisionHistoryUI]
        let pro: Set<AppFeature> = [.meetingHistory, .recurringContext, .floatingNotes, .aiCleanUp, .aiStructure]
        let provider = TestEntitlementProvider(.loading)
        let store = EntitlementStore(provider: provider)
        let released = FeatureAccess(toggles: .released, entitlement: store)
        let only = FeatureAccess(toggles: FeatureToggles(enabled: [feature]), entitlement: store)
        // Adding a flag requires an explicit tier and release decision.
        #expect(free.union(pro) == Set(AppFeature.allCases))
        #expect(FeatureToggles.allEnabled.isEnabled(feature))
        #expect(released.status(of: feature) == (free.contains(feature) ? .available : .loading))
        provider.send(.free)
        #expect(released.status(of: feature) == (free.contains(feature) ? .available : .requiresPro))
        provider.send(.pro)
        #expect(released.allows(feature))
        for candidate in AppFeature.allCases {
            #expect(only.status(of: candidate) == (candidate == feature ? .available : .unavailable))
        }
    }

    @Test func launchDefaultsAndIsolatedDebugOverride() {
        #expect(FeatureToggles.forLaunch(arguments: []) == .released)
        #expect(FeatureToggles.forLaunch(arguments: ["--all-features"]) == .released)
        #expect(FeatureToggles.forLaunch(arguments: ["--sample"]) == .released)
        #expect(FeatureToggles.forLaunch(arguments: ["--marketing-fixtures"]) == .released)
        #expect(FeatureToggles.forLaunch(arguments: ["--sample", "--marketing-fixtures"]) == .released)
        #expect(FeatureToggles.forLaunch(arguments: ["--sample", "--marketing-fixtures", "--all-features"]) == .released)
        for arguments in [[], ["--all-features"], ["--simulate-entitlement"], ["--sample"], ["--sample", "--marketing-fixtures", "--all-features", "--simulate-entitlement"]] {
            let store = EntitlementStore(provider: EntitlementLaunchPolicy.makeProvider(arguments: arguments))
            #expect(store.state == .free)
        }
        let simulation = EntitlementStore(provider: EntitlementLaunchPolicy.makeProvider(arguments: ["--sample", "--simulate-entitlement"]))
        let allFeatures = EntitlementStore(provider: EntitlementLaunchPolicy.makeProvider(arguments: ["--sample", "--all-features"]))
        #if DEBUG
        #expect(simulation.state == .loading && allFeatures.state == .pro)
        #expect(FeatureToggles.forLaunch(arguments: ["--sample", "--all-features"]) == .allEnabled)
        #else
        #expect(simulation.state == .free && allFeatures.state == .free)
        #expect(FeatureToggles.forLaunch(arguments: ["--sample", "--all-features"]) == .released)
        #endif
    }

    @Test func freeActionsCannotChangeAdvancedDataOrPreferences() async throws {
        let ai = RefinementSpy()
        let fixture = try TestComposition(ai: ai); defer { fixture.clearPreferences() }
        let first = KaigiTests().meeting()
        let older = try fixture.store.openNote(for: first)
        _ = try fixture.store.confirmContext(id: older.id, text: "Saved earlier context")
        let next = KaigiTests().meeting(start: first.start.addingTimeInterval(86400))
        let current = try fixture.store.openNote(for: next)
        _ = try fixture.store.saveDraft(id: current.id, text: "Existing note", reason: "Edit")
        _ = try fixture.store.confirmContext(id: current.id, text: "Retained current context")
        let model = fixture.container.detail(note: try fixture.container.noteUseCases.note(current.id), meeting: next)
        let before = try fixture.store.fetchNote(id: current.id)
        let revisions = try fixture.store.fetchRevisions(id: current.id)
        let preferences = fixture.defaults.dictionaryRepresentation()
        #expect(model.access.toggles == .released && fixture.container.settings.access.toggles == .released)
        #expect(fixture.container.agenda.access.toggles == .released)
        #expect(!model.hasAI && !model.hasHistoryAndContext && !model.canRefine)
        #expect(model.unavailableReason == nil && model.history.isEmpty && model.previous.isEmpty)
        model.toggleContext()
        #expect(!model.showingContext)
        model.contextDraft = "Must not be confirmed"
        model.confirmContext(); model.setCarryEnabled(false); model.carry(older)
        #expect(throws: MeetingContextError.self) { try fixture.container.contextUseCase.confirm(current.id, text: "Blocked") }
        #expect(throws: MeetingContextError.self) { try fixture.container.contextUseCase.setEnabled(false, for: next) }
        #expect(try fixture.container.noteUseCases.history(of: model.note).isEmpty)
        model.showHistoryAndContext(); model.selectHistory(older.id); model.openHistory(older); model.float()
        model.refine(.cleanUp); model.refine(.structure); await model.waitForRefinement(); model.applyPreview()
        fixture.container.settings.setAIEnabled(false)
        #expect(ai.actions.isEmpty && model.preview == nil && !model.showingRevisions)
        #expect(fixture.actions.contextWindows.isEmpty && fixture.actions.floating.isEmpty)
        #expect(model.selectedHistory == nil && fixture.system.aiEnabled)
        #expect(try fixture.store.fetchNote(id: current.id) == before)
        #expect(try fixture.store.fetchRevisions(id: current.id).map(\.id) == revisions.map(\.id))
        #expect(try fixture.store.contextEnabled(for: next))
        #expect(NSDictionary(dictionary: fixture.defaults.dictionaryRepresentation()).isEqual(to: preferences))
        model.updateText("Edited in free mode")
        #expect(try fixture.store.fetchNote(id: current.id)?.text == "Edited in free mode")
        // Consecutive edits retain the existing 30-second checkpoint coalescing policy.
        #expect(try fixture.store.fetchRevisions(id: current.id).map(\.id) == revisions.map(\.id))
        let fresh = try fixture.store.openNote(for: KaigiTests().meeting("fresh-free-note"))
        let freshEditor = fixture.container.detail(note: fresh, meeting: nil)
        freshEditor.updateText("First free draft")
        #expect(try fixture.store.fetchNote(id: fresh.id)?.text == "First free draft")
        #expect(try fixture.store.fetchRevisions(id: fresh.id).count == 1)
        await model.exportCurrentDraft()
        #expect(fixture.actions.exports.first?.text.contains("Edited in free mode") == true)
        #expect(fixture.actions.exports.first?.text.contains("Retained current context") == true)
        await fixture.container.agenda.load()
        #expect(fixture.container.agenda.contextKeys.isEmpty)
        let enabled = try TestComposition(store: fixture.store, features: .allEnabled, entitlement: .init(.pro)); defer { enabled.clearPreferences() }
        let restored = try enabled.container.detail(id: current.id)
        #expect(restored.text == "Edited in free mode")
        #expect(restored.note.confirmedContext == "Retained current context")
        #expect(restored.previous.first?.confirmedContext == "Saved earlier context")
        #expect(!((try enabled.store.fetchRevisions(id: current.id)).isEmpty))
    }

    @Test(arguments: [AppFeature.aiCleanUp, .aiStructure]) func aiActionsAreIndependent(_ feature: AppFeature) async throws {
        let ai = RefinementSpy()
        let fixture = try TestComposition(ai: ai, features: FeatureToggles(enabled: [feature]), entitlement: .init(.pro)); defer { fixture.clearPreferences() }
        let note = try fixture.store.openNote(for: KaigiTests().meeting())
        let model = fixture.container.detail(note: note, meeting: nil)
        model.updateText("Original")
        let allowed: RefinementAction = feature == .aiCleanUp ? .cleanUp : .structure
        let blocked: RefinementAction = feature == .aiCleanUp ? .structure : .cleanUp
        #expect(model.hasAI && fixture.container.settings.hasAI)
        #expect(model.canRefine(allowed) && !model.canRefine(blocked))
        model.refine(blocked); await model.waitForRefinement()
        #expect(ai.actions.isEmpty && model.preview == nil)
        model.refine(allowed); await model.waitForRefinement()
        #expect(ai.actions == [allowed] && model.text == "Original")
        model.applyPreview()
        #expect(model.text == "Reviewed" && model.preview == nil)
        #expect(try fixture.store.fetchRevisions(id: note.id).contains { $0.text == "Original" })
    }

    @Test(arguments: [AppFeature.meetingHistory, .recurringContext]) func historyAndContextAreIndependent(_ feature: AppFeature) throws {
        let fixture = try TestComposition(features: FeatureToggles(enabled: [feature]), entitlement: .init(.pro)); defer { fixture.clearPreferences() }
        let first = KaigiTests().meeting()
        let older = try fixture.store.openNote(for: first)
        _ = try fixture.store.confirmContext(id: older.id, text: "Earlier context")
        let next = KaigiTests().meeting(start: first.start.addingTimeInterval(86400))
        let note = try fixture.store.openNote(for: next)
        let model = fixture.container.detail(note: note, meeting: next)
        #expect(model.hasHistoryAndContext)
        model.showHistoryAndContext(); #expect(fixture.actions.contextWindows == [note.id])
        model.selectHistory(older.id); model.openHistory(older)
        #expect(fixture.actions.floating.isEmpty) // Earlier-note editing additionally requires floatingNotes.
        #expect(model.history.isEmpty == (feature != .meetingHistory))
        #expect(model.previous.isEmpty == (feature != .recurringContext))
        model.contextDraft = "New context"; model.confirmContext(); model.carry(try fixture.container.noteUseCases.note(older.id))
        #expect(model.note.confirmedContext == (feature == .recurringContext ? "New context" : ""))
        #expect(model.text.contains("Earlier context") == (feature == .recurringContext))
    }

    @Test(arguments: [EntitlementState.free, .pro]) func cachedModelsFollowRepeatedRuntimeChanges(_ firstResolution: EntitlementState) async throws {
        let fixture = try TestComposition(entitlement: .init(.loading))
        defer { fixture.clearPreferences() }
        let agenda = fixture.container.agenda!
        await agenda.load()
        let recurring = agenda.meetings.first { $0.recurring }
        let meeting = try #require(recurring)
        let previousMeeting = KaigiTests().meeting(meeting.externalID, start: meeting.start.addingTimeInterval(-86400), calendar: meeting.calendarID)
        let older = try fixture.store.openNote(for: previousMeeting)
        _ = try fixture.store.confirmContext(id: older.id, text: "Saved previous context")
        agenda.select(meeting)
        agenda.notesChanged()
        let model = try #require(agenda.detail)
        let settings = fixture.container.settings
        model.updateText("Current occurrence note")
        #expect(!settings.hasAI && !model.hasHistoryAndContext && agenda.contextKeys.isEmpty)
        #expect(model.access.status(of: .meetingHistory) == .loading)
        model.showHistoryAndContext()
        model.float()
        #expect(fixture.actions.floating.isEmpty && fixture.actions.contextWindows.isEmpty)

        let observed = AccessObservation()
        withObservationTracking {
            _ = settings.hasAI
            _ = agenda.contextKeys
        } onChange: {
            observed.record()
        }

        for state in [firstResolution, .pro, .free, .pro, .loading, .free, .pro, .free] {
            fixture.entitlement.send(state)
            let hasPro = state == .pro
            #expect(try fixture.container.detail(id: model.note.id) === model)
            #expect(settings.hasAI == hasPro && model.hasAI == hasPro && model.hasHistoryAndContext == hasPro)
            #expect(agenda.contextKeys.contains(meeting.id) == hasPro)
            #expect(fixture.container.accounts.providers.filter { $0.kind != .system }.allSatisfy { $0.state == .comingSoon })
            #expect(model.history.map(\.id) == (hasPro ? [older.id] : []))
            #expect(model.previous.map(\.id) == (hasPro ? [older.id] : []))
            #expect(model.text == "Current occurrence note")
        }
        #expect(observed.changed)
        #expect(try fixture.store.fetchNote(id: older.id)?.confirmedContext == "Saved previous context")
        #expect(try fixture.store.fetchNotes().count == 2)
    }

    @Test func freeEditorReadsExportsAndRestoresExistingData() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("notes.store")
        let fixture = try TestComposition(store: NoteRepository(url: url), entitlement: .init(.pro))
        defer { fixture.clearPreferences() }
        let meeting = KaigiTests().meeting()
        let record = try fixture.store.openNote(for: meeting)
        _ = try fixture.store.saveDraft(id: record.id, text: "Original", reason: "Checkpoint")
        _ = try fixture.store.saveDraft(id: record.id, text: "Latest", reason: "Checkpoint")
        let model = try fixture.container.detail(id: record.id)
        model.toggleContext()
        model.contextDraft = "Confirmed while Pro"
        model.confirmContext()
        model.toggleContext()
        model.contextDraft = "Unconfirmed edit"
        fixture.entitlement.send(.free)
        #expect(model.note.hasConfirmedContext && model.note.confirmedContext == "Confirmed while Pro")
        #expect(model.hasPausedContextDraft && model.contextDraft == "Unconfirmed edit")
        model.confirmContext()
        await model.exportCurrentDraft()
        let markdown = try #require(fixture.actions.exports.last?.text)
        #expect(markdown.contains("Confirmed while Pro") && !markdown.contains("Unconfirmed edit"))
        model.toggleRevisions()
        #expect(model.showingRevisions)
        model.restore(try #require(model.revisions.first { $0.text == "Original" }))
        #expect(model.text == "Original" && !model.showingRevisions)
        #expect(try fixture.store.fetchNote(id: record.id)?.text == "Original")
        #expect(try fixture.store.fetchNote(id: record.id)?.confirmedContext == "Confirmed while Pro")
        fixture.entitlement.send(.pro)
        #expect(model.showingContext && model.contextDraft == "Unconfirmed edit")
        fixture.entitlement.send(.free)
        try fixture.container.flushDrafts()

        let reopened = try NoteRepository(url: url)
        let storedNote = try reopened.fetchNote(id: record.id)
        let persisted = try #require(storedNote)
        #expect(persisted.occurrenceKey == record.occurrenceKey && persisted.seriesID == record.seriesID)
        #expect(persisted.text == "Original" && persisted.confirmedContext == "Confirmed while Pro")
        #expect(try reopened.fetchRevisions(id: record.id).contains { $0.text == "Latest" })
    }

    @Test func revocationKeepsOpenFloatingEditorAndUnsavedDraft() throws {
        let base = try NoteRepository(inMemory: true)
        let store = FailingNotesStore(base: base)
        let fixture = try TestComposition()
        defer { fixture.clearPreferences() }
        let provider = TestEntitlementProvider(.pro)
        let access = FeatureAccess(toggles: .allEnabled, entitlement: EntitlementStore(provider: provider))
        let router = AppRouter(exporter: MarkdownExporter(), access: access)
        let container = try DependencyContainer(
            providers: [fixture.provider], store: store, preferences: fixture.preferences, systemPreferences: fixture.system,
            ai: UnavailableAIService(), opener: fixture.actions, permissionSettings: fixture.actions, actions: router,
            sample: true, suppressOnboarding: true, access: access, closeOnboarding: {}
        )
        let coordinator = AppWindowCoordinator(container: container)
        router.windows = coordinator
        let record = try store.openNote(for: KaigiTests().meeting())
        let model = try container.detail(id: record.id)
        router.showMeetingContext(record.id)
        let context = try #require(NSApp.windows.first { $0.title == "History & Context — \(record.title)" && $0.isVisible })
        defer { context.close() }
        router.showFloatingNote(record.id)
        let panel = try #require(NSApp.windows.compactMap { $0 as? AgendaPanel }.first { $0.title == "Kaigi — \(record.title)" && $0.isVisible })
        defer { panel.close() }
        #expect(panel.isFloatingPanel && panel.level == .floating)
        let editor = panel.contentViewController
        store.failWrites = true
        model.updateText("Unsaved floating draft")
        provider.send(.free)
        #expect(!context.isVisible && panel.isVisible)
        #expect(!panel.isFloatingPanel && panel.level == .normal && !panel.styleMask.contains(.utilityWindow))
        #expect(panel.contentViewController === editor)
        #expect(try container.detail(id: record.id) === model && model.text == "Unsaved floating draft")
        #expect(try store.fetchNote(id: record.id)?.text == "")
        router.showMeetingContext(record.id)
        router.showFloatingNote(record.id)
        #expect(!context.isVisible && !panel.isFloatingPanel)
        store.failWrites = false
        model.retrySave()
        #expect(try store.fetchNote(id: record.id)?.text == "Unsaved floating draft")
        provider.send(.pro)
        #expect(!panel.isFloatingPanel)
        router.showFloatingNote(record.id)
        #expect(panel.isFloatingPanel && panel.contentViewController === editor)
    }

    @Test func revocationInvalidatesPendingAndReadyAIResults() async throws {
        let ai = SuspendedRefinement()
        let fixture = try TestComposition(ai: ai, entitlement: .init(.pro))
        defer { fixture.clearPreferences() }
        let record = try fixture.store.openNote(for: KaigiTests().meeting())
        let model = fixture.container.detail(note: record, meeting: nil)
        model.updateText("Original note")
        var starts = ai.starts.makeAsyncIterator()
        model.refine(.cleanUp)
        #expect(await starts.next() == .cleanUp)
        fixture.entitlement.send(.free)
        #expect(!model.refining && model.preview == nil)
        fixture.entitlement.send(.pro)
        ai.complete(with: "Discard this late result")
        await model.waitForRefinement()
        model.applyPreview()
        #expect(model.preview == nil && model.text == "Original note")

        model.refine(.structure)
        #expect(await starts.next() == .structure)
        ai.complete(with: "Ready for review")
        await model.waitForRefinement()
        #expect(model.preview?.text == "Ready for review")
        fixture.entitlement.send(.free)
        fixture.entitlement.send(.pro)
        model.applyPreview()
        #expect(model.preview == nil && model.text == "Original note")

        model.refine(.cleanUp)
        #expect(await starts.next() == .cleanUp)
        ai.complete(with: "Accepted content")
        await model.waitForRefinement()
        model.applyPreview()
        fixture.entitlement.send(.free)
        #expect(try fixture.store.fetchNote(id: record.id)?.text == "Accepted content")
    }

    @Test func historyUsesSavedOccurrenceDateIdentityAndMeaningfulContent() throws {
        let fixture = try TestComposition(entitlement: .init(.pro))
        defer { fixture.clearPreferences() }
        let current = KaigiTests().meeting()
        let currentNote = try fixture.store.openNote(for: current)
        _ = try fixture.store.saveDraft(id: currentNote.id, text: "Current note", reason: "Edit")
        let start = current.start
        let older = try fixture.store.openNote(for: KaigiTests().meeting(start: start.addingTimeInterval(-7200)))
        _ = try fixture.store.saveDraft(id: older.id, text: "Earlier note", reason: "Edit")
        let recentDate = start.addingTimeInterval(-3600)
        let recent = try fixture.store.openNote(for: KaigiTests().meeting(start: recentDate))
        _ = try fixture.store.confirmContext(id: recent.id, text: "Only confirmed context")
        let sameTime = try fixture.store.openNote(for: KaigiTests().meeting(start: recentDate, original: recentDate.addingTimeInterval(-60)))
        _ = try fixture.store.saveDraft(id: sameTime.id, text: "Same start, different occurrence", reason: "Edit")
        _ = try fixture.store.openNote(for: KaigiTests().meeting(start: start.addingTimeInterval(-300)))
        let whitespace = try fixture.store.openNote(for: KaigiTests().meeting(start: start.addingTimeInterval(-240)))
        _ = try fixture.store.saveDraft(id: whitespace.id, text: "  \n", reason: "Edit")
        _ = try fixture.store.confirmContext(id: whitespace.id, text: "\t")
        let future = try fixture.store.openNote(for: KaigiTests().meeting(start: start.addingTimeInterval(60), original: start.addingTimeInterval(-60)))
        _ = try fixture.store.saveDraft(id: future.id, text: "Rescheduled after current", reason: "Edit")
        let other = try fixture.store.openNote(for: KaigiTests().meeting(start: start.addingTimeInterval(-60), calendar: "another-calendar"))
        _ = try fixture.store.saveDraft(id: other.id, text: "Same title, different series", reason: "Edit")

        let ordered = [recent, sameTime].sorted { $0.occurrenceKey < $1.occurrenceKey } + [older]
        let notes = fixture.container.noteUseCases
        #expect(try notes.history(of: currentNote, now: start).map(\.id) == ordered.map(\.id))
        #expect(try notes.history(of: currentNote, now: start.addingTimeInterval(-4000)).map(\.id) == [older.id])
        let moved = try fixture.store.openNote(for: KaigiTests().meeting(start: start.addingTimeInterval(-4000), original: current.originalStart))
        #expect(moved.id == currentNote.id)
        #expect(try notes.history(of: moved, now: start).map(\.id) == [older.id])
    }

    @Test func disabledOptionalSettingsAndWindowRoutesDoNothing() async throws {
        let none = FeatureToggles(enabled: [])
        let fixture = try TestComposition(features: none); defer { fixture.clearPreferences() }
        let settings = fixture.container.settings
        settings.setReminders(true); settings.setLaunchAtLogin(true); settings.setAIEnabled(false); settings.showAccounts()
        await Task.yield()
        #expect(!fixture.system.remindersEnabled && !fixture.system.launchAtLogin && fixture.system.aiEnabled)
        #expect(fixture.actions.accountWindows == 0)
        let note = try fixture.store.openNote(for: KaigiTests().meeting())
        let model = fixture.container.detail(note: note, meeting: nil)
        await model.exportCurrentDraft(); #expect(fixture.actions.exports.isEmpty)
        let coordinator = AppWindowCoordinator(container: fixture.container)
        let count = NSApp.windows.count
        coordinator.showAccounts(); coordinator.showMeetingContext(note.id); coordinator.showFloatingNote(note.id)
        let router = AppRouter(exporter: MarkdownExporter(), access: fixture.container.access); router.windows = coordinator
        router.showAccounts(); router.showMeetingContext(note.id); router.showFloatingNote(note.id)
        try await router.export(MarkdownDocument(text: "Must not open a save panel", filename: "test.md"))
        #expect(NSApp.windows.count == count)
    }
}

@MainActor private final class RefinementSpy: AIRefinementService {
    var unavailableReason: String? { nil }
    var actions: [RefinementAction] = []

    func refine(_ text: String, action: RefinementAction) async throws -> RefinementResult {
        actions.append(action); return RefinementResult(text: "Reviewed")
    }
}

private final class AccessObservation: Sendable {
    private let storage = Mutex(false)
    var changed: Bool { storage.withLock { $0 } }

    func record() { storage.withLock { $0 = true } }
}

@MainActor private final class SuspendedRefinement: AIRefinementService {
    private let stream = AsyncStream<RefinementAction>.makeStream()
    private var pending: CheckedContinuation<RefinementResult, Never>?
    var starts: AsyncStream<RefinementAction> { stream.stream }
    var unavailableReason: String? { nil }

    func refine(_ text: String, action: RefinementAction) async throws -> RefinementResult {
        await withCheckedContinuation { continuation in
            pending = continuation
            stream.continuation.yield(action)
        }
    }

    func complete(with text: String) {
        let operation = pending
        pending = nil
        operation?.resume(returning: RefinementResult(text: text))
    }
}
