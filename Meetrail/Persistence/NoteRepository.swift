import Foundation
import SwiftData

@Model final class MeetingSeries {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var externalKey: String
    var carryContext: Bool
    init(key: String) { id = UUID(); externalKey = key; carryContext = true }
}

@Model final class MeetingNote {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var occurrenceKey: String
    var seriesID: UUID
    var title: String
    var start: Date
    var text: String
    var confirmedContext: String
    var updated: Date
    init(meeting: Meeting, seriesID: UUID) {
        id = UUID(); occurrenceKey = meeting.occurrenceKey; self.seriesID = seriesID
        title = meeting.title; start = meeting.start; text = ""; confirmedContext = ""; updated = .now
    }
}

@Model final class NoteRevision {
    @Attribute(.unique) var id: UUID
    var noteID: UUID
    var text: String
    var date: Date
    var reason: String
    init(note: MeetingNote, reason: String) {
        id = UUID(); noteID = note.id; text = note.text; date = .now; self.reason = reason
    }
}

@MainActor final class NoteRepository {
    let container: ModelContainer
    let context: ModelContext
    private var lastCheckpoint: [UUID: Date] = [:]
    init(inMemory: Bool = false, url: URL? = nil) throws {
        let schema = Schema([MeetingSeries.self, MeetingNote.self, NoteRevision.self])
        let config: ModelConfiguration
        if let url { config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none) }
        else { config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none) }
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container); context.autosaveEnabled = false
    }
    func allNotes() throws -> [MeetingNote] { try context.fetch(FetchDescriptor<MeetingNote>(sortBy: [SortDescriptor(\.start, order: .reverse)])) }
    func series(for meeting: Meeting) throws -> MeetingSeries {
        let key = meeting.seriesKey
        if let found = try context.fetch(FetchDescriptor<MeetingSeries>(predicate: #Predicate { $0.externalKey == key })).first { return found }
        let value = MeetingSeries(key: key); context.insert(value); try context.save(); return value
    }
    func note(for meeting: Meeting) throws -> MeetingNote {
        let key = meeting.occurrenceKey
        if let found = try context.fetch(FetchDescriptor<MeetingNote>(predicate: #Predicate { $0.occurrenceKey == key })).first {
            found.title = meeting.title; found.start = meeting.start; try context.save(); return found
        }
        let value = MeetingNote(meeting: meeting, seriesID: try series(for: meeting).id)
        context.insert(value); try context.save(); return value
    }
    func save(_ note: MeetingNote, text: String, reason: String = "Edit") throws {
        guard note.text != text else { return }
        if reason != "Edit" || lastCheckpoint[note.id] == nil || Date.now.timeIntervalSince(lastCheckpoint[note.id]!) >= 30 {
            context.insert(NoteRevision(note: note, reason: reason))
            lastCheckpoint[note.id] = .now
        }
        note.text = text; note.updated = .now
        try context.save()
    }
    func revisions(_ note: MeetingNote) throws -> [NoteRevision] {
        let id = note.id
        return try context.fetch(FetchDescriptor<NoteRevision>(predicate: #Predicate { $0.noteID == id }, sortBy: [SortDescriptor(\.date, order: .reverse)]))
    }
    func hasPreviousContext(for meeting: Meeting) throws -> Bool {
        let seriesKey = meeting.seriesKey
        guard meeting.recurring,
              let series = try context.fetch(FetchDescriptor<MeetingSeries>(predicate: #Predicate { $0.externalKey == seriesKey })).first,
              series.carryContext else { return false }
        return try allNotes().contains { $0.seriesID == series.id && $0.start < meeting.start && !$0.confirmedContext.isEmpty }
    }
    func previousContext(for note: MeetingNote) throws -> [MeetingNote] {
        try allNotes().filter { $0.seriesID == note.seriesID && $0.id != note.id && $0.start < note.start && !$0.confirmedContext.isEmpty }
    }
    func confirm(_ note: MeetingNote, context text: String) throws { note.confirmedContext = text; try context.save() }
    func markdown(_ note: MeetingNote) -> String {
        "# \(note.title)\n\n\(note.start.formatted(date: .complete, time: .shortened))\n\n\(note.text)\n\n## Confirmed context\n\n\(note.confirmedContext)\n"
    }
}
