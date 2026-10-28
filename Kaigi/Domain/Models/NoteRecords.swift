import Foundation

struct NoteID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: UUID }
struct NoteRecord: Identifiable, Equatable, Sendable {
    let id: NoteID
    let occurrenceKey: String
    let seriesID: UUID
    let title: String
    let start: Date
    let text: String
    let confirmedContext: String
    let updated: Date
}
struct RevisionRecord: Identifiable, Sendable {
    let id: UUID
    let noteID: NoteID
    let text: String
    let date: Date
    let reason: String
}
struct SeriesRecord: Sendable {
    let id: UUID
    let externalKey: String
    let carryContext: Bool
}
struct MarkdownDocument: Sendable { let text: String; let filename: String }
struct NoteBadges: Sendable { let notes: Set<String>; let previousContext: Set<String> }
