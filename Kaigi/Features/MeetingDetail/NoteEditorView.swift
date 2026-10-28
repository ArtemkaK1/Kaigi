import SwiftUI

struct NoteEditorView: View {
    @Bindable var model: MeetingDetailViewModel
    var back: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                if let back {
                    SymbolButton(symbol: "chevron.left", label: "Back to agenda", action: back)
                        .keyboardShortcut("[", modifiers: .command)
                }
                Spacer(minLength: AppSpacing.xs)
                SymbolButton(symbol: "square.and.arrow.up", label: "Export Markdown", action: model.export)
                if back != nil {
                    SymbolButton(symbol: "pin", label: "Float notes", action: model.float)
                }
            }
            Text(model.note.title)
                .appText(.section, weight: .semibold)
                .textSelection(.enabled)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: AppSpacing.xs) {
                Text(model.note.start.formatted())
                    .appText(.caption)
                    .foregroundStyle(AppColors.secondary)
                Spacer(minLength: AppSpacing.xs)
                JoinControl(links: model.meeting?.links ?? [], action: model.join)
            }
            ZStack(alignment: .topLeading) {
                if model.text.isEmpty {
                    Text("Write meeting notes…")
                        .appText(.body)
                        .foregroundStyle(AppColors.secondary)
                        .padding(AppSpacing.sm)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextEditor(text: Binding(get: { model.text }, set: model.updateText))
                    .appText(.body)
                    .scrollContentBackground(.hidden)
                    .padding(AppSpacing.xs)
                    .accessibilityLabel("Meeting notes")
                    .accessibilityHint("Write notes for this meeting; changes save automatically")
            }
            .frame(height: AppLayout.editorIdeal)
            .background(AppColors.editor, in: RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppLayout.cornerRadius)
                    .strokeBorder(AppColors.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            HStack(spacing: AppSpacing.xs) {
                Text(model.saveStatus)
                    .appText(.caption)
                    .foregroundStyle(model.saveStatus == "Saved locally" ? AppColors.secondary : AppColors.error)
                Spacer(minLength: AppSpacing.xs)
                Button("Revisions", action: model.toggleRevisions)
                    .buttonStyle(KaigiButtonStyle(.tertiary))
            }
            if let error = model.error {
                InlineMessage(text: error, isError: true)
                HStack(spacing: AppSpacing.xs) {
                    if model.saveStatus != "Saved locally" {
                        Button("Retry save", action: model.retrySave)
                    }
                    Button("Dismiss", action: model.dismissError)
                }
                .appText(.caption)
                .buttonStyle(KaigiButtonStyle())
            }
            if model.showingRevisions {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    if model.revisions.isEmpty {
                        Text("No revisions yet")
                            .appText(.caption)
                            .foregroundStyle(AppColors.secondary)
                    }
                    ForEach(model.revisions) { revision in
                        Button("Restore \(revision.date.formatted()) · \(revision.reason)") {
                            model.restore(revision)
                        }
                        .help(String(revision.text.prefix(160)))
                    }
                }
                .appText(.caption)
                .buttonStyle(KaigiButtonStyle())
            }
            HStack(spacing: AppSpacing.xs) {
                Button("Clean Up") {
                    model.refine(.cleanUp)
                }
                .help("Improve spelling and clarity in this note; review before applying")
                Button("Structure") {
                    model.refine(.structure)
                }
                .help("Organize this note into topics, decisions, actions and questions; review before applying")
                if model.refining {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .disabled(!model.canRefine)
            .appText(.body, weight: .medium)
            .buttonStyle(KaigiButtonStyle())
            if let reason = model.unavailableReason {
                Text(model.aiEnabled ? "On-device AI unavailable" : reason)
                    .appText(.caption)
                    .foregroundStyle(AppColors.secondary)
                    .help(reason)
            }
            if let preview = model.preview {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Label("Review changes", systemImage: "sparkles")
                        .appText(.body, weight: .medium)
                        .accessibilityAddTraits(.isHeader)
                    Text(preview.text)
                        .appText(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("ai-proposed-note")
                    HStack(spacing: AppSpacing.xs) {
                        Button("Cancel", action: model.discardPreview)
                            .buttonStyle(KaigiButtonStyle(.tertiary))
                            .keyboardShortcut(.cancelAction)
                        Spacer(minLength: AppSpacing.xs)
                        Button("Apply", action: model.applyPreview)
                            .buttonStyle(KaigiButtonStyle(.primary))
                    }
                    .appText(.body, weight: .medium)
                }
                .padding(AppSpacing.sm)
                .background(AppColors.selected, in: RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
            }
            Button(action: model.showHistoryAndContext) {
                Label("History & Context", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(KaigiButtonStyle(.tertiary))
            .accessibilityHint("Opens meeting history and confirmed context in a separate window")
        }
        .padding(AppSpacing.sm)
        .background(AppColors.background)
        .foregroundStyle(AppColors.primary)
    }
}
