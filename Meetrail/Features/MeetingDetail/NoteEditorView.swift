import SwiftUI

struct NoteEditorView: View {
    @Bindable var model: MeetingDetailViewModel
    var back: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                if let back { SymbolButton(symbol: "chevron.left", label: "Back to agenda", action: back).keyboardShortcut("[", modifiers: .command) }
                Spacer(minLength: AppSpacing.xs)
                SymbolButton(symbol: "clock.arrow.circlepath", label: "Meeting history", action: model.toggleHistory)
                SymbolButton(symbol: "square.and.arrow.up", label: "Export Markdown", action: model.export)
                if back != nil { SymbolButton(symbol: "pin", label: "Float notes", action: model.float) }
            }
            Text(model.note.title).appText(.section, weight: .semibold).textSelection(.enabled).accessibilityAddTraits(.isHeader)
            HStack(spacing: AppSpacing.xs) {
                Text(model.note.start.formatted()).appText(.caption).foregroundStyle(AppColors.secondary)
                Spacer(minLength: AppSpacing.xs)
                JoinControl(links: model.meeting?.links ?? [], action: model.join)
            }
            ZStack(alignment: .topLeading) {
                if model.text.isEmpty { Text("Write meeting notes…").appText(.body).foregroundStyle(AppColors.secondary).padding(AppSpacing.sm).allowsHitTesting(false).accessibilityHidden(true) }
                TextEditor(text: Binding(get: { model.text }, set: model.updateText)).appText(.body).scrollContentBackground(.hidden)
                    .padding(AppSpacing.xs).accessibilityLabel("Meeting notes").accessibilityHint("Write notes for this meeting; changes save automatically")
            }.frame(height: AppLayout.editorIdeal)
                .background(AppColors.editor, in: RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
                .overlay { RoundedRectangle(cornerRadius: AppLayout.cornerRadius).strokeBorder(AppColors.border, lineWidth: 1).allowsHitTesting(false) }
            HStack(spacing: AppSpacing.xs) {
                Text(model.saveStatus).appText(.caption).foregroundStyle(model.saveStatus == "Saved locally" ? AppColors.secondary : AppColors.error)
                Spacer(minLength: AppSpacing.xs)
                Button("Revisions", action: model.toggleRevisions).appText(.caption).buttonStyle(MeetrailButtonStyle())
            }
            if let error = model.error {
                InlineMessage(text: error, isError: true)
                HStack(spacing: AppSpacing.xs) { Button("Retry save", action: model.retrySave); Button("Dismiss", action: model.dismissError) }.appText(.caption).buttonStyle(MeetrailButtonStyle())
            }
            if model.showingRevisions {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    if model.revisions.isEmpty { Text("No revisions yet").appText(.caption).foregroundStyle(AppColors.secondary) }
                    ForEach(model.revisions) { revision in
                        Button("Restore \(revision.date.formatted()) · \(revision.reason)") { model.restore(revision) }.help(String(revision.text.prefix(160)))
                    }
                }.appText(.caption).buttonStyle(MeetrailButtonStyle())
            }
            HStack(spacing: AppSpacing.xs) {
                Button("Clean Up") { model.refine(.cleanUp) }.help("Improve spelling and clarity in this note; review before applying")
                Button("Structure") { model.refine(.structure) }.help("Organize this note into topics, decisions, actions and questions; review before applying")
                if model.refining { ProgressView().controlSize(.small) }
            }.disabled(!model.canRefine).appText(.body, weight: .medium).buttonStyle(MeetrailButtonStyle())
            if let reason = model.unavailableReason {
                Text(model.aiEnabled ? "On-device AI unavailable" : reason).appText(.caption).foregroundStyle(AppColors.secondary).help(reason)
            }
            if let preview = model.preview {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Label("Review changes", systemImage: "sparkles").appText(.body, weight: .semibold).accessibilityAddTraits(.isHeader)
                    Text(preview.text).appText(.body).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).accessibilityIdentifier("ai-proposed-note")
                    HStack(spacing: AppSpacing.xs) {
                        Button("Cancel", action: model.discardPreview).buttonStyle(MeetrailButtonStyle()).keyboardShortcut(.cancelAction)
                        Spacer(minLength: AppSpacing.xs)
                        Button("Apply", action: model.applyPreview).buttonStyle(MeetrailButtonStyle(prominent: true))
                    }.appText(.body, weight: .medium)
                }.padding(AppSpacing.sm).background(AppColors.selected, in: RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
            }
            context
            if model.showingHistory {
                Divider().overlay(AppColors.border)
                Text("Meeting history").appText(.body, weight: .semibold).accessibilityAddTraits(.isHeader)
                if model.isRecurring { Toggle("Use previous context", isOn: Binding(get: { model.carryEnabled }, set: model.setCarryEnabled)).appText(.caption) }
                if model.history.isEmpty { Text("No other saved occurrences").appText(.caption).foregroundStyle(AppColors.secondary) }
                ForEach(model.history) { record in
                    Button { model.openHistory(record) } label: {
                        Label(record.start.formatted(date: .abbreviated, time: .shortened), systemImage: "note.text").frame(maxWidth: .infinity, alignment: .leading)
                    }.appText(.caption).buttonStyle(MeetrailButtonStyle()).accessibilityLabel("Open meeting history \(record.start.formatted())")
                }
            }
        }.padding(AppSpacing.sm).foregroundStyle(AppColors.primary)
    }
    private var context: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if !model.previous.isEmpty {
                Divider().overlay(AppColors.border)
                Text("Previous context").appText(.body, weight: .semibold).accessibilityAddTraits(.isHeader)
                ForEach(model.previous.prefix(5)) { older in
                    Text(older.start.formatted(date: .abbreviated, time: .shortened)).appText(.caption).foregroundStyle(AppColors.secondary)
                    Text(older.confirmedContext).appText(.body).textSelection(.enabled)
                    Button("Carry into notes") { model.carry(older) }.appText(.caption).buttonStyle(MeetrailButtonStyle())
                }
            }
            HStack(spacing: AppSpacing.xs) {
                Text("Context for next time").appText(.caption, weight: .medium).foregroundStyle(AppColors.secondary)
                Spacer(minLength: AppSpacing.xs)
                Button(model.showingContext ? "Cancel" : "Edit", action: model.toggleContext).appText(.caption).buttonStyle(MeetrailButtonStyle())
            }
            if model.showingContext {
                TextEditor(text: $model.contextDraft).appText(.body).scrollContentBackground(.hidden).padding(AppSpacing.xs)
                    .frame(height: AppLayout.providerCardHeight).background(AppColors.editor, in: RoundedRectangle(cornerRadius: AppLayout.cornerRadius)).accessibilityLabel("Context to confirm")
                Button("Confirm context", action: model.confirmContext).appText(.caption, weight: .medium).buttonStyle(MeetrailButtonStyle())
            } else if !model.note.confirmedContext.isEmpty { Text(model.note.confirmedContext).appText(.body).textSelection(.enabled) }
        }
    }
}
