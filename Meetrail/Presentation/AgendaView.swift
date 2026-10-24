import SwiftUI
import AppKit

enum MeetrailStyle {
    static let accent = Color.accentColor
    static let radius: CGFloat = 12
}

struct AgendaView: View {
    @Bindable var model: AgendaViewModel
    var close: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let close { Button(action: close) { Image(systemName: "xmark") }.accessibilityLabel("Close agenda") }
                Label("Meetrail", systemImage: "note.text").font(.headline)
                Spacer()
                Button { model.showingLibrary.toggle() } label: { Image(systemName: "tray.full") }.help("Saved notes").accessibilityLabel("Saved notes")
                Button { model.showingSettings.toggle() } label: { Image(systemName: "gearshape") }.help("Settings").accessibilityLabel("Settings")
            }.buttonStyle(.borderless).padding(16)
            Divider()
            if model.showingSettings { SettingsView(model: model) }
            else if model.showingLibrary { library }
            else if let note = model.selected { ScrollView { NoteEditorView(note: note, meeting: model.selectedMeeting, model: model).id(note.id) } }
            else { agenda }
            if let error = model.error {
                HStack { Text(error).font(.caption).foregroundStyle(.red); Button("Dismiss") { model.error = nil } }.padding(12)
            }
            Divider()
            HStack {
                Text(model.sample ? "Sample data · local preview" : "Your notes stay on this Mac").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.borderless).font(.caption)
            }.padding(12)
        }
        .frame(width: 380, height: model.panelHeight, alignment: .top).background(.regularMaterial).tint(MeetrailStyle.accent)
        .onAppear { model.refresh() }
    }
    private var agenda: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.day.date.formatted(.dateTime.weekday(.wide))).font(.system(size: 26, weight: .semibold, design: .rounded))
                    Text(model.day.date.formatted(.dateTime.day().month(.wide).year())).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Button { model.move(-1) } label: { Image(systemName: "chevron.left").frame(width: 24, height: 28) }.accessibilityLabel("Previous day").keyboardShortcut(.leftArrow, modifiers: .command)
                    Button { model.move(1) } label: { Image(systemName: "chevron.right").frame(width: 24, height: 28) }.accessibilityLabel("Next day").keyboardShortcut(.rightArrow, modifiers: .command)
                }.buttonStyle(.plain)
            }
            HStack {
                Text(Calendar.current.isDateInToday(model.day.date) ? "TODAY" : "AGENDA").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button("Today") { model.today() }.keyboardShortcut("t", modifiers: .command).buttonStyle(.borderless)
            }
            if model.loading { ProgressView("Loading calendars…").frame(maxWidth: .infinity).padding(24) }
            else if model.calendar.access != .allowed {
                ContentUnavailableView { Label("Your day, connected", systemImage: "calendar.badge.lock") } description: {
                    Text("Allow calendar access to see meetings. Notes stay private on this Mac.")
                } actions: {
                    Button(model.calendar.access == .denied ? "Open Privacy Settings" : "Connect calendars") {
                        if model.calendar.access == .denied { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!) }
                        else { Task { await model.connect() } }
                    }
                }.frame(height: 250)
            } else if model.meetings.isEmpty {
                ContentUnavailableView("Room to focus", systemImage: "sun.horizon", description: Text(model.calendar.calendars.isEmpty ? "Add a calendar account in macOS Calendar." : "No meetings for this day in your selected calendars.")).frame(height: 220)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) { ForEach(model.meetings) { meeting in MeetingCard(meeting: meeting, model: model) } }
                }.frame(height: min(CGFloat(model.meetings.count) * 96, 390))
            }
        }.padding(16)
    }
    private var library: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Back to agenda") { model.showingLibrary = false }
            Text("Saved notes").font(.title2.weight(.semibold))
            Text("Notes remain here even when calendar events disappear. Changed calendar identities are kept separate for safety.").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                ForEach((try? model.notes.allNotes()) ?? []) { note in
                    Button { model.selected = note; model.selectedMeeting = nil; model.showingLibrary = false } label: {
                        VStack(alignment: .leading) { Text(note.title); Text(note.start.formatted()).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                    }.buttonStyle(.plain)
                }
            }.frame(height: 300)
        }.padding(16)
    }
}

struct MeetingCard: View {
    let meeting: Meeting
    @Bindable var model: AgendaViewModel
    var body: some View {
        HStack(spacing: 8) {
            Button { model.select(meeting) } label: {
                HStack(alignment: .top, spacing: 12) {
                    Text(meeting.allDay ? "All day" : meeting.start.formatted(date: .omitted, time: .shortened)).font(.system(.caption, design: .monospaced).weight(.medium)).frame(width: 64, alignment: .leading)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(meeting.title).font(.body.weight(.semibold)).lineLimit(2).foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            if let link = meeting.links.first { Label(link.provider, systemImage: "video").lineLimit(1) }
                            if model.noteKeys.contains(meeting.occurrenceKey) { Image(systemName: "note.text").accessibilityLabel("Has notes") }
                            if model.contextKeys.contains(meeting.occurrenceKey) { Image(systemName: "text.bubble").accessibilityLabel("Previous confirmed context") }
                            if meeting.recurring { Image(systemName: "repeat").accessibilityLabel("Recurring") }
                        }.font(.caption2).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(Rectangle()).padding(.vertical, 12)
            }.buttonStyle(.plain).accessibilityLabel("Open notes for \(meeting.title)")
                .accessibilityValue("\(meeting.allDay ? "All day" : meeting.start.formatted(date: .omitted, time: .shortened)), \(meeting.calendarName), \(meeting.links.first?.provider ?? "No conference link")\(model.noteKeys.contains(meeting.id) ? ", has notes" : "")\(model.contextKeys.contains(meeting.id) ? ", previous confirmed context available" : "")")
                .accessibilityHint("Opens private notes for this occurrence")
            JoinControl(links: meeting.links, action: model.join)
        }.padding(.horizontal, 12).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: MeetrailStyle.radius))
    }
}

struct JoinControl: View {
    let links: [MeetingLink]
    let action: (MeetingLink) -> Void
    var body: some View {
        if links.count == 1, let link = links.first, link.recognized {
            Button("Join") { action(link) }.accessibilityLabel("Join \(link.provider)")
        } else if !links.isEmpty {
            Menu("Links") { ForEach(links) { link in Button("\(link.provider) · \(link.url.host ?? "")") { action(link) } } }
                .help("Choose a calendar link; verify the destination before opening")
        }
    }
}
