import Foundation
import Observation

@MainActor @Observable final class MeetingDetailViewModel {
    private let analytics: any AnalyticsTracking
    private var editorSessions: Set<UUID> = []
    private var editedSessions: Set<UUID> = []
    let features: FeatureToggles
    private let notes: NoteUseCases
    private let context: MeetingContextUseCase
    private let preferences: any PreferencesService
    private let ai: any AIRefinementService
    private let joinUseCase: ConferenceJoinUseCase
    private let actions: any ApplicationActions
    private let onSaved: () -> Void
    private(set) var note: NoteRecord
    private(set) var meeting: Meeting?
    var text: String
    var contextDraft: String
    private(set) var saveStatus = "Saved locally"
    private(set) var error: String?
    var showingRevisions = false
    var showingContext = false
    private(set) var selectedHistoryID: NoteID?
    private(set) var history: [NoteRecord] = []
    private(set) var aiEnabled: Bool
    private(set) var revisions: [RevisionRecord] = []
    private(set) var previous: [NoteRecord] = []
    private(set) var carryEnabled = true
    private(set) var preview: RefinementResult?
    private(set) var originalInput = ""
    private(set) var refining = false
    private var refinementTask: Task<Void, Never>?
    private var refinementAction: RefinementAction?
    var hasAI: Bool { features.isEnabled(.aiCleanUp) || features.isEnabled(.aiStructure) }
    var hasHistoryAndContext: Bool { features.isEnabled(.meetingHistory) || features.isEnabled(.recurringContext) }
    var unavailableReason: String? { hasAI ? (aiEnabled ? ai.unavailableReason : "AI is off. Enable it in Settings.") : nil }
    var canRefine: Bool { hasAI && !refining && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && unavailableReason == nil }

    func canRefine(_ action: RefinementAction) -> Bool { canRefine && allows(action) }

    private func allows(_ action: RefinementAction) -> Bool {
        features.isEnabled(action == .cleanUp ? .aiCleanUp : .aiStructure)
    }
    var isRecurring: Bool { meeting?.recurring == true }
    var selectedHistory: NoteRecord? { history.first { $0.id == selectedHistoryID } }
    var canCarrySelectedHistory: Bool { features.isEnabled(.recurringContext) && previous.contains { $0.id == selectedHistoryID } }

    init(note: NoteRecord, meeting: Meeting?, notes: NoteUseCases, context: MeetingContextUseCase, ai: any AIRefinementService, preferences: any PreferencesService, join: ConferenceJoinUseCase, actions: any ApplicationActions, features: FeatureToggles = .appStoreFree, analytics: any AnalyticsTracking, onSaved: @escaping () -> Void) {
        self.analytics = analytics
        self.features = features
        self.note = note; self.meeting = meeting; self.notes = notes; self.context = context; self.ai = ai
        self.preferences = preferences; aiEnabled = preferences.aiEnabled
        self.joinUseCase = join; self.actions = actions; self.onSaved = onSaved
        text = note.text; contextDraft = note.confirmedContext; reloadContext()
    }

    func updateMeeting(_ meeting: Meeting) { self.meeting = meeting; reloadContext() }

    func editorPresented(_ session: UUID) {
        if editorSessions.insert(session).inserted { analytics.track(.notesOpened) }
    }

    func editorDismissed(_ session: UUID) {
        editorSessions.remove(session); editedSessions.remove(session)
    }

    func updateText(_ value: String, session: UUID? = nil) {
        if value != text, let session, editorSessions.contains(session), editedSessions.insert(session).inserted {
            analytics.track(.notesEditStarted)
        }
        text = value; save(value)
    }

    func retrySave() { save(text) }

    func flushDraft() throws {
        guard text != note.text else { return }
        note = try notes.save(note.id, text: text); saveStatus = "Saved locally"; error = nil; onSaved()
    }

    private func save(_ value: String, reason: String = "Edit") {
        do { note = try notes.save(note.id, text: value, reason: reason); text = note.text; saveStatus = "Saved locally"; error = nil; onSaved() }
        catch { saveStatus = "Save failed — your draft is still open"; self.error = error.localizedDescription }
    }

    func toggleRevisions() {
        guard features.isEnabled(.revisionHistoryUI) else { return }
        showingRevisions.toggle()
        do { revisions = try notes.revisions(note.id) } catch { self.error = error.localizedDescription }
    }

    func restore(_ revision: RevisionRecord) {
        guard features.isEnabled(.revisionHistoryUI), revision.noteID == note.id else { return }
        do { note = try notes.restore(revision); text = note.text; saveStatus = "Saved locally"; toggleRevisions(); onSaved() }
        catch { self.error = error.localizedDescription }
    }

    func toggleContext() { guard features.isEnabled(.recurringContext) else { return }; contextDraft = note.confirmedContext; showingContext.toggle() }

    func confirmContext() {
        guard features.isEnabled(.recurringContext) else { return }
        do { note = try context.confirm(note.id, text: contextDraft); reloadContext(); showingContext = false; onSaved() }
        catch { self.error = error.localizedDescription }
    }

    func setCarryEnabled(_ value: Bool) {
        guard features.isEnabled(.recurringContext), let meeting else { return }
        do { try context.setEnabled(value, for: meeting); carryEnabled = value; reloadContext(); onSaved() }
        catch { self.error = error.localizedDescription }
    }

    func reloadContext() {
        do {
            carryEnabled = features.isEnabled(.recurringContext) ? try (meeting.map { try context.enabled(for: $0) } ?? context.enabled(for: note)) : false
            history = features.isEnabled(.meetingHistory) ? try notes.history(of: note) : []
            previous = carryEnabled ? try context.previous(for: note) : []
        } catch { self.error = error.localizedDescription }
    }

    func showHistoryAndContext() {
        guard hasHistoryAndContext else { return }
        reloadContext()
        actions.showMeetingContext(note.id)
    }

    func selectHistory(_ id: NoteID?) {
        guard features.isEnabled(.meetingHistory) else { return }
        guard let id, id != note.id else { selectedHistoryID = nil; return }
        guard history.contains(where: { $0.id == id }) else { return }
        selectedHistoryID = id
    }

    func openHistory(_ record: NoteRecord) {
        guard features.isEnabled(.meetingHistory), features.isEnabled(.floatingNotes), history.contains(where: { $0.id == record.id && $0.seriesID == note.seriesID }) else { return }
        actions.showFloatingNote(record.id)
    }

    func refreshPreferences() {
        aiEnabled = preferences.aiEnabled
        if !hasAI || !aiEnabled { refinementTask?.cancel(); preview = nil; refining = false }
    }

    func carry(_ previous: NoteRecord) {
        guard features.isEnabled(.recurringContext), self.previous.contains(where: { $0.id == previous.id && $0.seriesID == note.seriesID }) else { return }
        updateText(text + "\n\nPrevious context (reviewed):\n" + previous.confirmedContext)
    }

    func refine(_ action: RefinementAction) {
        guard canRefine(action) else { return }
        refinementAction = action
        originalInput = text; let input = text; refining = true; error = nil
        refinementTask = Task { [weak self] in
            guard let self else { return }
            defer { self.refining = false }
            do {
                let result = try await self.ai.refine(input, action: action)
                guard !Task.isCancelled, self.aiEnabled, self.allows(action) else { return }
                self.preview = result
            }
            catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }

    func waitForRefinement() async { await refinementTask?.value }

    func discardPreview() { preview = nil }

    func applyPreview() {
        guard let preview, let refinementAction, allows(refinementAction), aiEnabled else { return }
        guard text == originalInput else { error = "Your notes changed. Generate a fresh preview before applying."; return }
        save(preview.text, reason: "Before AI refinement")
        if saveStatus == "Saved locally" { self.preview = nil }
    }

    func join(_ link: MeetingLink) { analytics.track(.notesJoinTapped); do { try joinUseCase.join(link) } catch { self.error = error.localizedDescription } }

    func export() { Task { await exportCurrentDraft() } }

    func exportCurrentDraft() async {
        guard features.isEnabled(.markdownExport) else { return }
        analytics.track(.notesExportTapped)
        do {
            let outcome = try await actions.export(notes.document(note.id, draft: text, includeContext: features.isEnabled(.recurringContext)))
            analytics.track(.notesExportResult(outcome == .success ? .success : .cancelled))
        } catch {
            analytics.track(.notesExportResult(.error))
            self.error = error.localizedDescription
        }
    }

    func float() { guard features.isEnabled(.floatingNotes) else { return }; actions.showFloatingNote(note.id) }

    func dismissError() { error = nil }
}
