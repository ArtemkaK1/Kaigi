import Testing
import Foundation
@testable import Meetrail

@MainActor struct RebrandingCompatibilityTests {
    @Test func persistentRuntimeNamespaceRemainsCompatible() {
        #expect(String(reflecting: MeetingSeries.self) == "Meetrail.MeetingSeries")
        #expect(String(reflecting: MeetingNote.self) == "Meetrail.MeetingNote")
        #expect(String(reflecting: NoteRevision.self) == "Meetrail.NoteRevision")
    }

    @Test func renamedHostUsesRegisteredIdentity() {
        #expect(Bundle.main.bundleIdentifier == "com.volrik.kaigi")
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "Kaigi")
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String == "Kaigi")
    }
}
