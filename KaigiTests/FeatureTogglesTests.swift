import AppKit
import Foundation
import Testing
@testable import Meetrail

@MainActor struct FeatureTogglesTests {
    @Test(arguments: AppFeature.allCases) func defaultsAndIndependentConfigurations(_ feature: AppFeature) {
        let free: Set<AppFeature> = [.calendarManagement, .meetingReminders, .markdownExport, .launchAtLogin]
        #expect(FeatureToggles.appStoreFree.isEnabled(feature) == free.contains(feature))
        #expect(FeatureToggles.allEnabled.isEnabled(feature))
        let only = FeatureToggles(enabled: [feature])
        for candidate in AppFeature.allCases {
            #expect(only.isEnabled(candidate) == (candidate == feature))
        }
    }

    @Test func launchDefaultsAndIsolatedDebugOverride() {
        #expect(FeatureToggles.forLaunch(arguments: []) == .appStoreFree)
        #expect(FeatureToggles.forLaunch(arguments: ["--all-features"]) == .appStoreFree)
        #expect(FeatureToggles.forLaunch(arguments: ["--sample"]) == .appStoreFree)
        #if DEBUG
        #expect(FeatureToggles.forLaunch(arguments: ["--sample", "--all-features"]) == .allEnabled)
        #else
        #expect(FeatureToggles.forLaunch(arguments: ["--sample", "--all-features"]) == .appStoreFree)
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
        #expect(model.features == .appStoreFree && fixture.container.settings.features == .appStoreFree)
        #expect(fixture.container.agenda.features == .appStoreFree)
        #expect(!model.hasAI && !model.hasHistoryAndContext && !model.canRefine)
        #expect(model.unavailableReason == nil && model.history.isEmpty && model.previous.isEmpty)
        model.toggleRevisions(); model.restore(try #require(revisions.first))
        model.contextDraft = "Must not be confirmed"; model.showingContext = true
        model.confirmContext(); model.setCarryEnabled(false); model.carry(older)
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
        #expect(fixture.actions.exports.first?.text.contains("Retained current context") == false)
        await fixture.container.agenda.load()
        #expect(fixture.container.agenda.contextKeys.isEmpty)
        let enabled = try TestComposition(store: fixture.store, features: .allEnabled); defer { enabled.clearPreferences() }
        let restored = try enabled.container.detail(id: current.id)
        #expect(restored.text == "Edited in free mode")
        #expect(restored.note.confirmedContext == "Retained current context")
        #expect(restored.previous.first?.confirmedContext == "Saved earlier context")
        #expect(!((try enabled.store.fetchRevisions(id: current.id)).isEmpty))
    }

    @Test(arguments: [AppFeature.aiCleanUp, .aiStructure]) func aiActionsAreIndependent(_ feature: AppFeature) async throws {
        let ai = RefinementSpy()
        let fixture = try TestComposition(ai: ai, features: FeatureToggles(enabled: [feature])); defer { fixture.clearPreferences() }
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
        let fixture = try TestComposition(features: FeatureToggles(enabled: [feature])); defer { fixture.clearPreferences() }
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
        let router = AppRouter(exporter: MarkdownExporter(), features: none); router.windows = coordinator
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
