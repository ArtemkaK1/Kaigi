import Foundation
import Observation

@MainActor @Observable final class MeetingDetailViewModel {
    private let analytics: any AnalyticsTracking
    private var editorSessions: Set<UUID> = []
    private var editedSessions: Set<UUID> = []
    let access: FeatureAccess
    private let notes: NoteUseCases
    private let context: MeetingContextUseCase
    private let preferences: any PreferencesService
    private let ai: any AIRefinementService
    private let joinUseCase: ConferenceJoinUseCase
    private let actions: any ApplicationActions
    private let onSaved: () -> Void
    private(set) var note: NoteRecord
    private(set) var meeting: Meeting?
    private(set) var text: String
    var contextDraft: String
    private(set) var saveStatus = "Saved locally"
    private(set) var error: String?
    private(set) var showingRevisions = false
    private(set) var showingContext = false
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
    private var refinementID: UUID?
    private var refinementAction: RefinementAction?
    var hasAI: Bool { access.allows(.aiCleanUp) || access.allows(.aiStructure) }
    var hasHistoryAndContext: Bool { access.allowsMeetingContextWindow }
    var unavailableReason: String? { hasAI ? (aiEnabled ? ai.unavailableReason : "AI is off. Enable it in Settings.") : nil }
    var canRefine: Bool { hasAI && !refining && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && unavailableReason == nil }

    func canRefine(_ action: RefinementAction) -> Bool { canRefine && allows(action) }

    private func allows(_ action: RefinementAction) -> Bool {
        access.allows(action == .cleanUp ? .aiCleanUp : .aiStructure)
    }
    var isRecurring: Bool { meeting?.recurring == true }
    var selectedHistory: NoteRecord? { history.first { $0.id == selectedHistoryID } }
    var hasPausedContextDraft: Bool {
        !access.allows(.recurringContext) && hasUnconfirmedContextDraft
    }
    var hasUnconfirmedContextDraft: Bool { showingContext && contextDraft != note.confirmedContext }
    var canCarrySelectedHistory: Bool { access.allows(.recurringContext) && previous.contains { $0.id == selectedHistoryID } }

    init(note: NoteRecord, meeting: Meeting?, notes: NoteUseCases, context: MeetingContextUseCase, ai: any AIRefinementService, preferences: any PreferencesService, join: ConferenceJoinUseCase, actions: any ApplicationActions, access: FeatureAccess, analytics: any AnalyticsTracking, onSaved: @escaping () -> Void) {
        self.analytics = analytics
        self.access = access
        self.note = note; self.meeting = meeting; self.notes = notes; self.context = context; self.ai = ai
        self.preferences = preferences; aiEnabled = preferences.aiEnabled
        self.joinUseCase = join; self.actions = actions; self.onSaved = onSaved
        text = note.text; contextDraft = note.confirmedContext; reloadContext()
    }

    func updateOccurrence(_ latest: NoteRecord, meeting: Meeting?) {
        if text == note.text && latest.text != text {
            if refining { invalidateRefinement() }
            text = latest.text
        }
        if !showingContext { contextDraft = latest.confirmedContext }
        note = latest
        if let meeting { self.meeting = meeting }
        reloadContext()
    }

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
        if value != text && refining { invalidateRefinement() }
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
        guard access.allows(.revisionHistoryUI) else { return }
        showingRevisions.toggle()
        do { revisions = try notes.revisions(note.id) } catch { self.error = error.localizedDescription }
    }

    func restore(_ revision: RevisionRecord) {
        guard access.allows(.revisionHistoryUI), revision.noteID == note.id else { return }
        if refining { invalidateRefinement() }
        do { note = try notes.restore(revision); text = note.text; saveStatus = "Saved locally"; toggleRevisions(); onSaved() }
        catch { self.error = error.localizedDescription }
    }

    func toggleContext() {
        guard access.allows(.recurringContext) else { return }
        contextDraft = note.confirmedContext
        showingContext.toggle()
    }

    func confirmContext() {
        guard access.allows(.recurringContext) else { return }
        do { note = try context.confirm(note.id, text: contextDraft); reloadContext(); showingContext = false; onSaved() }
        catch { self.error = error.localizedDescription }
    }

    func setCarryEnabled(_ value: Bool) {
        guard access.allows(.recurringContext), let meeting else { return }
        do { try context.setEnabled(value, for: meeting); carryEnabled = value; reloadContext(); onSaved() }
        catch { self.error = error.localizedDescription }
    }

    func reloadContext() {
        if !access.allows(.meetingHistory) {
            history = []
            selectedHistoryID = nil
        }
        if !access.allows(.recurringContext) {
            carryEnabled = false
            previous = []
        }
        do {
            if access.allows(.meetingHistory) {
                history = try notes.history(of: note)
                if !history.contains(where: { $0.id == selectedHistoryID }) { selectedHistoryID = nil }
            }
            if access.allows(.recurringContext) {
                carryEnabled = try context.enabled(for: note)
                previous = carryEnabled ? try context.previous(for: note) : []
            }
        } catch { self.error = error.localizedDescription }
    }

    func accessChanged() {
        if let refinementAction, !allows(refinementAction) { invalidateRefinement() }
        reloadContext()
    }

    func showHistoryAndContext() {
        guard hasHistoryAndContext else { return }
        reloadContext()
        actions.showMeetingContext(note.id)
    }

    func selectHistory(_ id: NoteID?) {
        guard access.allows(.meetingHistory) else { return }
        guard let id, id != note.id else { selectedHistoryID = nil; return }
        guard history.contains(where: { $0.id == id }) else { return }
        selectedHistoryID = id
    }

    func openHistory(_ record: NoteRecord) {
        guard access.allows(.meetingHistory), access.allows(.floatingNotes), history.contains(where: { $0.id == record.id && $0.seriesID == note.seriesID }) else { return }
        actions.showFloatingNote(record.id)
    }

    func refreshPreferences() {
        aiEnabled = preferences.aiEnabled
        if !aiEnabled { invalidateRefinement() }
    }

    func carry(_ previous: NoteRecord) {
        guard access.allows(.recurringContext),
              let source = self.previous.first(where: { $0.id == previous.id }) else { return }
        updateText(text + "\n\nPrevious context (reviewed):\n" + source.confirmedContext)
    }

    func refine(_ action: RefinementAction) {
        guard canRefine(action) else { return }
        invalidateRefinement()
        let id = UUID()
        let input = text
        refinementID = id
        refinementAction = action
        originalInput = input
        refining = true
        error = nil
        refinementTask = Task { [weak self, ai] in
            guard !Task.isCancelled else { return }
            do {
                let result = try await ai.refine(input, action: action)
                guard let self, self.refinementID == id, !Task.isCancelled else { return }
                self.refining = false
                guard self.aiEnabled, self.allows(action), self.text == input else { return }
                self.preview = result
            } catch {
                guard let self, self.refinementID == id, !Task.isCancelled else { return }
                self.refining = false
                self.error = error.localizedDescription
            }
        }
    }

    private func invalidateRefinement() {
        refinementTask?.cancel()
        refinementID = nil
        refinementAction = nil
        preview = nil
        refining = false
    }

    func waitForRefinement() async { await refinementTask?.value }

    func discardPreview() { invalidateRefinement() }

    func applyPreview() {
        guard let preview, let refinementAction, allows(refinementAction), aiEnabled else { return }
        guard text == originalInput else { error = "Your notes changed. Generate a fresh preview before applying."; return }
        save(preview.text, reason: "Before AI refinement")
        if saveStatus == "Saved locally" { invalidateRefinement() }
    }

    func join(_ link: MeetingLink) { analytics.track(.notesJoinTapped); do { try joinUseCase.join(link) } catch { self.error = error.localizedDescription } }

    func export() { Task { await exportCurrentDraft() } }

    func exportCurrentDraft() async {
        guard access.allows(.markdownExport) else { return }
        analytics.track(.notesExportTapped)
        do {
            let outcome = try await actions.export(notes.document(note.id, draft: text))
            analytics.track(.notesExportResult(outcome == .success ? .success : .cancelled))
        } catch {
            analytics.track(.notesExportResult(.error))
            self.error = error.localizedDescription
        }
    }

    func float() { guard access.allows(.floatingNotes) else { return }; actions.showFloatingNote(note.id) }

    func dismissError() { error = nil }
}
