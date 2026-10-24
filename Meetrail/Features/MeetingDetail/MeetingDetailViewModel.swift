import Foundation
import Observation

@MainActor @Observable final class MeetingDetailViewModel {
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
    var showingHistory = false
    private(set) var history: [NoteRecord] = []
    private(set) var aiEnabled: Bool
    private(set) var revisions: [RevisionRecord] = []
    private(set) var previous: [NoteRecord] = []
    private(set) var carryEnabled = true
    private(set) var preview: RefinementResult?
    private(set) var originalInput = ""
    private(set) var refining = false
    private var refinementTask: Task<Void, Never>?
    var unavailableReason: String? { aiEnabled ? ai.unavailableReason : "AI is off. Enable it in Settings." }
    var canRefine: Bool { !refining && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && unavailableReason == nil }
    var isRecurring: Bool { meeting?.recurring == true }
    init(note: NoteRecord, meeting: Meeting?, notes: NoteUseCases, context: MeetingContextUseCase, ai: any AIRefinementService, preferences: any PreferencesService, join: ConferenceJoinUseCase, actions: any ApplicationActions, onSaved: @escaping () -> Void) {
        self.note = note; self.meeting = meeting; self.notes = notes; self.context = context; self.ai = ai
        self.preferences = preferences; aiEnabled = preferences.aiEnabled
        self.joinUseCase = join; self.actions = actions; self.onSaved = onSaved
        text = note.text; contextDraft = note.confirmedContext; reloadContext()
    }
    func updateMeeting(_ meeting: Meeting) { self.meeting = meeting; reloadContext() }
    func updateText(_ value: String) { text = value; save(value) }
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
        showingRevisions.toggle()
        do { revisions = try notes.revisions(note.id) } catch { self.error = error.localizedDescription }
    }
    func restore(_ revision: RevisionRecord) {
        do { note = try notes.restore(revision); text = note.text; saveStatus = "Saved locally"; toggleRevisions(); onSaved() }
        catch { self.error = error.localizedDescription }
    }
    func toggleContext() { contextDraft = note.confirmedContext; showingContext.toggle() }
    func confirmContext() {
        do { note = try context.confirm(note.id, text: contextDraft); reloadContext(); showingContext = false; onSaved() }
        catch { self.error = error.localizedDescription }
    }
    func setCarryEnabled(_ value: Bool) {
        guard let meeting else { return }
        do { try context.setEnabled(value, for: meeting); carryEnabled = value; reloadContext(); onSaved() }
        catch { self.error = error.localizedDescription }
    }
    func reloadContext() {
        do {
            carryEnabled = try meeting.map { try context.enabled(for: $0) } ?? context.enabled(for: note)
            history = try notes.history(of: note)
            previous = carryEnabled ? try context.previous(for: note) : []
        } catch { self.error = error.localizedDescription }
    }
    func toggleHistory() { showingHistory.toggle(); reloadContext() }
    func openHistory(_ record: NoteRecord) {
        guard history.contains(where: { $0.id == record.id && $0.seriesID == note.seriesID }) else { return }
        actions.showFloatingNote(record.id)
    }
    func refreshPreferences() {
        aiEnabled = preferences.aiEnabled
        if !aiEnabled { refinementTask?.cancel(); preview = nil; refining = false }
    }
    func carry(_ previous: NoteRecord) { updateText(text + "\n\nPrevious context (reviewed):\n" + previous.confirmedContext) }
    func refine(_ action: RefinementAction) {
        guard canRefine else { return }
        originalInput = text; let input = text; refining = true; error = nil
        refinementTask = Task { [weak self] in
            guard let self else { return }
            defer { self.refining = false }
            do {
                let result = try await self.ai.refine(input, action: action)
                guard !Task.isCancelled, self.aiEnabled else { return }
                self.preview = result
            }
            catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }
    func waitForRefinement() async { await refinementTask?.value }
    func discardPreview() { preview = nil }
    func applyPreview() {
        guard let preview else { return }
        guard text == originalInput else { error = "Your notes changed. Generate a fresh preview before applying."; return }
        save(preview.text, reason: "Before AI refinement")
        if saveStatus == "Saved locally" { self.preview = nil }
    }
    func join(_ link: MeetingLink) { do { try joinUseCase.join(link) } catch { self.error = error.localizedDescription } }
    func export() { Task { await exportCurrentDraft() } }
    func exportCurrentDraft() async {
        do { try await actions.export(notes.document(note.id, draft: text)) }
        catch { self.error = error.localizedDescription }
    }
    func float() { actions.showFloatingNote(note.id) }
    func dismissError() { error = nil }
}
