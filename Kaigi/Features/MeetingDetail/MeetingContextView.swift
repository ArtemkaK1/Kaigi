import SwiftUI

struct MeetingContextView: View {
    @Bindable var model: MeetingDetailViewModel
    @FocusState private var occurrencesFocused: Bool
    @Environment(\.controlActiveState) private var controlActiveState
    var body: some View {
        HSplitView {
            List(selection: Binding<NoteID?>(get: { model.selectedHistoryID ?? model.note.id }, set: model.selectHistory)) {
                Section {
                    occurrenceRow(model.note, current: true)
                        .tag(model.note.id)
                } header: {
                    Text("Current meeting")
                        .appText(.caption)
                }
                Section {
                    ForEach(model.history) { record in
                        occurrenceRow(record, current: false)
                            .tag(record.id)
                    }
                    if model.history.isEmpty {
                        Text("No other saved occurrences")
                            .appText(.caption)
                            .foregroundStyle(AppColors.secondary)
                    }
                } header: {
                    Text("Earlier meetings")
                        .appText(.caption)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.surface)
            .listStyle(.sidebar)
            .tint(AppColors.accentFill)
            .focused($occurrencesFocused)
            .frame(minWidth: AppLayout.contextSidebarMinimum, idealWidth: AppLayout.contextSidebarIdeal, maxWidth: AppLayout.contextSidebarMaximum)
            .accessibilityLabel("Meeting occurrences")
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    if let record = model.selectedHistory {
                        earlierMeeting(record)
                    } else {
                        currentMeeting
                    }
                    if let error = model.error {
                        InlineMessage(text: error, isError: true)
                        Button("Dismiss", action: model.dismissError)
                            .buttonStyle(KaigiButtonStyle())
                    }
                }
                .padding(AppSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppColors.background)
        .tint(AppColors.accent)
    }

    private func occurrenceRow(_ record: NoteRecord, current: Bool) -> some View {
        let emphasized = (model.selectedHistoryID ?? model.note.id) == record.id && occurrencesFocused && controlActiveState != .inactive
        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(current ? "This occurrence" : record.start.formatted(date: .abbreviated, time: .omitted))
                .appText(.body, weight: .medium)
                .foregroundStyle(emphasized ? AppColors.onAccent : AppColors.primary)
            Text(record.start.formatted(date: current ? .abbreviated : .omitted, time: .shortened))
                .appText(.caption)
                .foregroundStyle(emphasized ? AppColors.onAccent : AppColors.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(current ? "context-current-occurrence" : "context-earlier-occurrence")
    }

    private var currentMeeting: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            heading(model.note, category: model.isRecurring ? "Current meeting · Recurring series" : "Current meeting")
            if model.isRecurring {
                Toggle("Use previous context", isOn: Binding(get: { model.carryEnabled }, set: model.setCarryEnabled))
                    .appText(.body)
                    .tint(AppColors.accentFill)
            }
            Divider()
                .overlay(AppColors.border)
            HStack(spacing: AppSpacing.xs) {
                Text("Context for next time")
                    .appText(.section, weight: .semibold)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: AppSpacing.xs)
                Button(model.showingContext ? "Cancel" : "Edit", action: model.toggleContext)
                    .buttonStyle(KaigiButtonStyle())
            }
            if model.showingContext {
                TextEditor(text: $model.contextDraft)
                    .appText(.body)
                    .scrollContentBackground(.hidden)
                    .padding(AppSpacing.xs)
                    .frame(height: AppLayout.editorIdeal)
                    .background(AppColors.editor, in: RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadius)
                            .strokeBorder(AppColors.border, lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                    .accessibilityLabel("Context to confirm")
                Button("Confirm context", action: model.confirmContext)
                    .buttonStyle(KaigiButtonStyle(.primary))
            } else {
                Text(model.note.confirmedContext.isEmpty ? "No confirmed context yet." : model.note.confirmedContext)
                    .appText(.body)
                    .foregroundStyle(model.note.confirmedContext.isEmpty ? AppColors.secondary : AppColors.primary)
                    .textSelection(.enabled)
            }
            Divider()
                .overlay(AppColors.border)
            Text("Previous confirmed context")
                .appText(.section, weight: .semibold)
                .accessibilityAddTraits(.isHeader)
            if model.previous.isEmpty {
                Text(model.carryEnabled ? "No previous confirmed context." : "Previous context is off for this series.")
                    .appText(.body)
                    .foregroundStyle(AppColors.secondary)
            }
            ForEach(model.previous) { record in
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(record.start.formatted(date: .abbreviated, time: .shortened))
                        .appText(.caption)
                        .foregroundStyle(AppColors.secondary)
                    Text(record.confirmedContext)
                        .appText(.body)
                        .textSelection(.enabled)
                    Button("Carry into notes") { model.carry(record) }
                        .buttonStyle(KaigiButtonStyle())
                        .accessibilityLabel("Carry context from \(record.start.formatted(date: .abbreviated, time: .shortened)) into current notes")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func earlierMeeting(_ record: NoteRecord) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            heading(record, category: "Earlier meeting")
            Button("Open note") { model.openHistory(record) }
                .buttonStyle(KaigiButtonStyle())
                .help("Open this occurrence in a floating note editor")
            Divider()
                .overlay(AppColors.border)
            Text("Meeting notes")
                .appText(.section, weight: .semibold)
                .accessibilityAddTraits(.isHeader)
            Text(record.text.isEmpty ? "No notes saved." : record.text)
                .appText(.body)
                .textSelection(.enabled)
                .accessibilityIdentifier("history-note-content")
            if !record.confirmedContext.isEmpty {
                Divider()
                    .overlay(AppColors.border)
                Text("Confirmed context")
                    .appText(.section, weight: .semibold)
                    .accessibilityAddTraits(.isHeader)
                Text(record.confirmedContext)
                    .appText(.body)
                    .textSelection(.enabled)
                if model.canCarrySelectedHistory {
                    Button("Carry into current notes") { model.carry(record) }
                        .buttonStyle(KaigiButtonStyle())
                }
            }
        }
    }

    private func heading(_ record: NoteRecord, category: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(category)
                .appText(.caption)
                .foregroundStyle(AppColors.secondary)
            Text(record.title)
                .appText(.title, weight: .semibold)
                .accessibilityAddTraits(.isHeader)
            Text(record.start.formatted(date: .complete, time: .shortened))
                .appText(.body)
                .foregroundStyle(AppColors.secondary)
        }
    }
}
