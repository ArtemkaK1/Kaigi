import SwiftUI

struct AgendaView: View {
    @Bindable var model: AgendaViewModel
    let maximumHeight: CGFloat
    var onHeightChange: (CGFloat) -> Void
    @State private var headerHeight: CGFloat = AppSpacing.xxl
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .body) private var timeColumn = AppLayout.timeColumn
    var body: some View {
        VStack(spacing: AppSpacing.none) {
            if let detail = model.detail {
                FittingScrollView(maximumHeight: maximumHeight) {
                    NoteEditorView(model: detail, back: model.back)
                }
                .id(detail.note.id)
            } else {
                header
                    .onGeometryChange(for: CGFloat.self) {
                        $0.size.height
                    } action: {
                        headerHeight = $0
                    }
                FittingScrollView(maximumHeight: min(AppLayout.agendaScrollHeight, max(AppLayout.emptyHeight, maximumHeight - headerHeight))) {
                    agenda
                }
            }
            if let error = model.error {
                HStack(spacing: AppSpacing.xs) {
                    InlineMessage(text: error, isError: true)
                    Button("Dismiss", action: model.dismissError)
                        .appText(.caption)
                        .buttonStyle(MeetrailButtonStyle())
                }
                .padding(AppSpacing.xs)
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .frame(width: AppLayout.panelWidth)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(AppColors.primary)
        .tint(AppColors.accent)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.height
        } action: {
            onHeightChange($0)
        }
    }
    private var header: some View {
        HStack(spacing: AppSpacing.xs) {
            VStack(alignment: .leading, spacing: AppSpacing.none) {
                Text(model.weekday)
                    .appText(.section, weight: .semibold)
                    .accessibilityAddTraits(.isHeader)
                Text(model.fullDate)
                    .appText(.caption)
                    .foregroundStyle(AppColors.secondary)
            }
            Spacer(minLength: AppSpacing.xs)
            SymbolButton(symbol: "chevron.left", label: "Previous day", showsBorder: false) {
                model.move(-1)
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            Button("Today", action: model.today)
                .buttonStyle(MeetrailButtonStyle(showsBorder: false))
                .appText(.caption, weight: .medium)
                .keyboardShortcut("t", modifiers: .command)
            SymbolButton(symbol: "chevron.right", label: "Next day", showsBorder: false) {
                model.move(1)
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
        }
        .padding(AppSpacing.xs)
    }
    private var agenda: some View {
        VStack(spacing: AppSpacing.xs) {
            if model.loading && model.meetings.isEmpty && model.recovered.isEmpty {
                ProgressView("Loading calendars…")
                    .appText(.body)
                    .frame(height: AppLayout.emptyHeight)
            } else if model.meetings.isEmpty && model.recovered.isEmpty {
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: model.connection == .connected ? "sun.horizon" : "calendar.badge.lock")
                        .appText(.title)
                        .foregroundStyle(AppColors.secondary)
                        .accessibilityHidden(true)
                    Text(model.connection == .connected ? "Room to focus" : "Connect your calendars")
                        .appText(.section, weight: .semibold)
                    Text(model.connection == .connected ? "No meetings for this day." : "Choose calendars to see your meetings.")
                        .appText(.body)
                        .foregroundStyle(AppColors.secondary)
                    if model.connection != .connected {
                        Button("Connect calendars", action: model.connect)
                            .appText(.body, weight: .medium)
                            .buttonStyle(MeetrailButtonStyle(prominent: true))
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: AppLayout.emptyHeight)
            } else {
                // A missing event remains a meeting occurrence on its original day.
                // There is deliberately no global notes browser.
                ForEach(model.entries, id: \.key) { entry in
                    if let meeting = entry.meeting {
                        MeetingCard(meeting: meeting, hasNotes: model.noteKeys.contains(meeting.id), hasContext: model.contextKeys.contains(meeting.id), select: { model.select(meeting) }, join: model.join)
                    } else if let note = entry.note {
                        Button {
                            model.selectRecovered(note)
                        } label: {
                            HStack(spacing: AppSpacing.xs) {
                                Text(note.start.formatted(date: .omitted, time: .shortened))
                                    .appText(.caption, weight: .medium)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .frame(width: max(timeColumn, AppLayout.timeColumn * AppTypography.scale(for: textSize)), alignment: .leading)
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    Text(note.title)
                                        .appText(.body, weight: .semibold)
                                    Label("Calendar history", systemImage: "clock.arrow.circlepath")
                                        .appText(.caption)
                                        .foregroundStyle(AppColors.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(AppSpacing.xs)
                            .frame(minHeight: AppLayout.rowHeight)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open recovered meeting \(note.title)")
                        .modifier(MeetingCardSurface())
                    }
                }
                if model.connection != .connected {
                    Button("Connect calendars", action: model.connect)
                        .appText(.caption)
                        .buttonStyle(MeetrailButtonStyle())
                }
            }
        }
        .padding(AppSpacing.xs)
    }

}
private struct MeetingCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.editor, in: RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppLayout.cornerRadius)
                    .strokeBorder(AppColors.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}
struct MeetingCard: View {
    let meeting: Meeting
    let hasNotes: Bool
    let hasContext: Bool
    let select: () -> Void
    let join: (MeetingLink) -> Void
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .body) private var timeColumn = AppLayout.timeColumn
    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Button(action: select) {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    Text(meeting.allDay ? "All day" : meeting.start.formatted(date: .omitted, time: .shortened))
                        .appText(.body, weight: .medium)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(width: max(timeColumn, AppLayout.timeColumn * AppTypography.scale(for: textSize)), alignment: .leading)
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(meeting.title)
                            .appText(.body, weight: .semibold)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: AppSpacing.xs) {
                            if let link = meeting.links.first {
                                Label(link.provider, systemImage: "video")
                                    .lineLimit(1)
                            }
                            if hasNotes {
                                Image(systemName: "note.text")
                            }
                            if hasContext {
                                Image(systemName: "text.bubble")
                            }
                            if meeting.recurring {
                                Image(systemName: "repeat")
                            }
                        }
                        .appText(.caption)
                        .foregroundStyle(AppColors.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(meeting.title)
            .accessibilityLabel("Open notes for \(meeting.title)")
            .accessibilityValue("\(meeting.allDay ? "All day" : meeting.start.formatted(date: .omitted, time: .shortened)), \(meeting.calendarName), \(meeting.links.first?.provider ?? "No conference link")\(hasNotes ? ", has notes" : "")\(hasContext ? ", previous confirmed context available" : "")")
            .accessibilityHint("Opens private notes for this occurrence")
            JoinControl(links: meeting.links, action: join)
        }
        .padding(AppSpacing.xs)
        .frame(minHeight: AppLayout.rowHeight)
        .modifier(MeetingCardSurface())
    }
}
