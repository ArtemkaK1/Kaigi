import SwiftUI

struct NoteEditorView: View {
    @Bindable var model: MeetingDetailViewModel
    @State private var editorSession = UUID()
    var back: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if back != nil || model.access.allows(.markdownExport) {
                HStack(spacing: AppSpacing.xs) {
                    if let back {
                        SymbolButton(symbol: "chevron.left", label: "Back to agenda", action: back)
                            .keyboardShortcut("[", modifiers: .command)
                    }
                    Spacer(minLength: AppSpacing.xs)
                    if model.access.allows(.markdownExport) {
                        SymbolButton(symbol: "square.and.arrow.up", label: "Export Markdown", action: model.export)
                    }
                    if back != nil {
                        if model.access.allows(.floatingNotes) {
                            SymbolButton(symbol: "pin", label: "Float notes", action: model.float)
                        } else if model.showsProEntry(.floatingNotes) {
                            Button {
                                model.showPro(from: .floatingNotes)
                            } label: {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: "pin")
                                    Image(systemName: "lock")
                                        .appText(.caption)
                                        .foregroundStyle(AppColors.accent)
                                }
                            }
                            .buttonStyle(KaigiButtonStyle(.tertiary))
                            .accessibilityLabel("Floating Notes, Kaigi Pro")
                            .help("Learn about Floating Notes in Kaigi Pro")
                        }
                    }
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
                TextEditor(text: Binding(get: { model.text }, set: { model.updateText($0, session: editorSession) }))
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
                if model.access.allows(.revisionHistoryUI) {
                    Spacer(minLength: AppSpacing.xs)
                    Button("Revisions", action: model.toggleRevisions)
                        .buttonStyle(KaigiButtonStyle(.tertiary))
                }
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
            if model.access.allows(.revisionHistoryUI) && model.showingRevisions {
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
            if model.note.hasConfirmedContext {
                NoteContextDisclosure(title: "Confirmed context", text: model.note.confirmedContext, contentID: "confirmed-note-context")
            }
            if model.hasPausedContextDraft {
                NoteContextDisclosure(title: "Unconfirmed context draft", text: model.contextDraft, contentID: "unconfirmed-note-context")
            }
            if model.hasAI {
                aiActions
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
            }
            if !model.hasAI && (model.showsProEntry(.ai(.cleanUp)) || model.showsProEntry(.ai(.structure))) {
                aiActions
            }
            if model.hasHistoryAndContext {
                Button(action: model.showHistoryAndContext) {
                    Label("History & Context", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(KaigiButtonStyle(.tertiary))
                .accessibilityHint("Opens meeting history and confirmed context in a separate window")
            } else if model.showsProEntry(.meetingContext) {
                proButton("History & Context", entry: .meetingContext, symbol: "clock.arrow.circlepath")
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.background)
        .foregroundStyle(AppColors.primary)
        .onAppear { model.editorPresented(editorSession) }
        .onDisappear { model.editorDismissed(editorSession) }
    }

    private var aiActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.xs) {
                aiButtons
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                aiButtons
            }
        }
    }

    @ViewBuilder private var aiButtons: some View {
        if model.access.allows(.aiCleanUp) {
            Button("Clean Up") { model.refine(.cleanUp) }
                .buttonStyle(KaigiButtonStyle())
                .disabled(!model.canRefine)
                .help("Improve spelling and clarity in this note; review before applying")
        } else if model.showsProEntry(.ai(.cleanUp)) {
            proButton("Clean Up", entry: .ai(.cleanUp))
        }
        if model.access.allows(.aiStructure) {
            Button("Structure") { model.refine(.structure) }
                .buttonStyle(KaigiButtonStyle())
                .disabled(!model.canRefine)
                .help("Organize this note into topics, decisions, actions and questions; review before applying")
        } else if model.showsProEntry(.ai(.structure)) {
            proButton("Structure", entry: .ai(.structure))
        }
        if model.refining {
            ProgressView()
                .controlSize(.small)
        }
    }

    private func proButton(_ title: String, entry: ProEntryPoint, symbol: String? = nil) -> some View {
        Button {
            model.showPro(from: entry)
        } label: {
            HStack(spacing: AppSpacing.xs) {
                if let symbol {
                    Image(systemName: symbol)
                        .accessibilityHidden(true)
                }
                Text(title)
                Text("Pro")
                    .appText(.caption, weight: .medium)
                    .foregroundStyle(AppColors.accent)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: entry == .meetingContext ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(KaigiButtonStyle(.tertiary))
        .accessibilityLabel("\(title), Kaigi Pro")
        .help("Learn about \(title) in Kaigi Pro")
    }
}

private struct NoteContextDisclosure: View {
    let title: String
    let text: String
    let contentID: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Button {
                expanded.toggle()
            } label: {
                Label(title, systemImage: expanded ? "chevron.down" : "chevron.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(KaigiButtonStyle(.tertiary))
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            if expanded {
                Text(text)
                    .appText(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(contentID)
            }
        }
    }
}
