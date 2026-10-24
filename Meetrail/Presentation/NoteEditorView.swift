import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct NoteEditorView: View {
    @Bindable var note: MeetingNote
    let meeting: Meeting?
    @Bindable var model: AgendaViewModel
    var floating = false
    @State private var contextDraft = ""
    @State private var status = "Saved locally"
    @State private var showHistory = false
    @State private var showContext = false
    @State private var preview: RefinementResult?
    @State private var refining = false
    @State private var aiError: String?
    @State private var inputSnapshot = ""
    @State private var carryEnabled = true
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if !floating { Button("Back") { model.selected = nil; model.refresh() }.keyboardShortcut(.escape, modifiers: []) }
                Spacer()
                Button { export() } label: { Image(systemName: "square.and.arrow.up") }.help("Export Markdown").accessibilityLabel("Export Markdown")
                if !floating { Button { FloatingNotesController.shared.show(note: note, meeting: meeting, model: model) } label: { Image(systemName: "pin") }.help("Float notes").accessibilityLabel("Float notes") }
            }.buttonStyle(.borderless)
            Text(note.title).font(.title3.weight(.semibold)).textSelection(.enabled)
            HStack { Text(note.start.formatted()).font(.caption).foregroundStyle(.secondary); Spacer(); JoinControl(links: meeting?.links ?? [], action: model.join) }
            TextEditor(text: Binding(get: { note.text }, set: save)).font(.body).scrollContentBackground(.hidden)
                .padding(8).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                .frame(minHeight: 170, idealHeight: 220, maxHeight: 260).accessibilityLabel("Meeting notes")
            HStack {
                Text(status).font(.caption2).foregroundStyle(status == "Saved locally" ? Color.secondary : Color.red)
                Spacer()
                Button("Revisions") { showHistory.toggle() }.font(.caption)
            }
            if showHistory {
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach((try? model.notes.revisions(note)) ?? []) { revision in
                            Button("Restore \(revision.date.formatted()) · \(revision.reason)") {
                                do { try model.notes.save(note, text: revision.text, reason: "Restore revision") } catch { model.error = error.localizedDescription }
                            }.help(String(revision.text.prefix(160)))
                        }
                    }
                }.frame(maxHeight: 100)
            }
            HStack {
                Button("Clean Up") { refine(.cleanUp) }
                Button("Structure") { refine(.structure) }
                if refining { ProgressView().controlSize(.small) }
            }.disabled(refining || note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.ai.unavailableReason != nil)
            Text(aiError ?? model.ai.unavailableReason ?? "On-device AI · Review every suggestion").font(.caption2).foregroundStyle(.secondary)
            if let preview {
                DisclosureGroup("Original input") { Text(inputSnapshot).textSelection(.enabled).font(.caption) }
                ScrollView { Text(preview.text).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }.frame(height: 130)
                Text("Review for changed meaning, invented facts, owners, and deadlines. Applying never confirms future context.").font(.caption2).foregroundStyle(.secondary)
                HStack {
                    Button("Discard") { self.preview = nil }
                    Button("Apply reviewed version") {
                        guard note.text == inputSnapshot else { aiError = "Your notes changed. Generate a fresh preview before applying."; return }
                        do { try model.notes.save(note, text: preview.text, reason: "Before AI refinement"); self.preview = nil }
                        catch { model.error = error.localizedDescription }
                    }
                }
            }
            Divider()
            DisclosureGroup("Confirmed context", isExpanded: $showContext) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Write only the decisions and unresolved items you want to retain. Review before confirming.").font(.caption2).foregroundStyle(.secondary)
                    TextEditor(text: $contextDraft).frame(height: 70).accessibilityLabel("Context to confirm")
                    Button("Confirm context") {
                        do { try model.notes.confirm(note, context: contextDraft) } catch { model.error = error.localizedDescription }
                    }
                }
            }.font(.caption)
            if meeting?.recurring == true {
                Toggle("Show previous confirmed context", isOn: $carryEnabled).font(.caption).onChange(of: carryEnabled) { _, value in
                    do { let series = try model.notes.series(for: meeting!); series.carryContext = value; try model.notes.context.save() } catch { model.error = error.localizedDescription }
                }
                if carryEnabled, let previous = try? model.notes.previousContext(for: note), !previous.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(previous.prefix(5)) { older in
                                Text(older.start.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                                Text(older.confirmedContext).font(.caption).textSelection(.enabled)
                                Button("Carry reviewed context into notes") { save(note.text + "\n\nPrevious context (reviewed):\n" + older.confirmedContext) }.font(.caption)
                            }
                        }
                    }.frame(maxHeight: 110)
                }
            }
        }.padding(16)
        .onAppear {
            contextDraft = note.confirmedContext
            if let meeting { carryEnabled = (try? model.notes.series(for: meeting).carryContext) ?? true }
        }
    }
    private func save(_ text: String) {
        do { try model.notes.save(note, text: text); status = "Saved locally" }
        catch { status = "Save failed — keep this editor open"; model.error = error.localizedDescription }
    }
    private func export() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.plainText]; panel.nameFieldStringValue = "Meetrail-note.md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try model.notes.markdown(note).write(to: url, atomically: true, encoding: .utf8) } catch { model.error = error.localizedDescription }
    }
    private func refine(_ action: RefinementAction) {
        inputSnapshot = note.text; refining = true; aiError = nil
        Task {
            defer { refining = false }
            do { preview = try await model.ai.refine(inputSnapshot, action: action) }
            catch { aiError = error.localizedDescription }
        }
    }
}

struct SettingsView: View {
    @Bindable var model: AgendaViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("Back") { model.showingSettings = false }
            Text("Calendars").font(.title3.weight(.semibold))
            ForEach(model.calendar.calendars) { calendar in
                Toggle(calendar.title, isOn: Binding(get: { model.calendarIDs.contains(calendar.id) }, set: { included in
                    if included { model.calendarIDs.insert(calendar.id) } else { model.calendarIDs.remove(calendar.id) }; model.refresh()
                }))
            }
            Divider()
            Toggle("Remind me one minute before meetings", isOn: Binding(get: { model.preferences.remindersEnabled }, set: { value in
                Task { await model.preferences.setReminders(value); model.refresh() }
            }))
            Toggle("Launch at login", isOn: Binding(get: { model.preferences.launchAtLogin }, set: { model.preferences.setLaunchAtLogin($0) }))
            if let message = model.preferences.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            Text("Reminders show no meeting titles or notes. Calendar access is read-only in Meetrail.").font(.caption2).foregroundStyle(.secondary)
            Button("Refresh calendar access") { Task { await model.connect() } }
        }.padding(16)
    }
}
