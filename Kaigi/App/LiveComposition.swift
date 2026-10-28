import Foundation
import UserNotifications

extension DependencyContainer {
    static func makeLive(actions: any ApplicationActions, closeOnboarding: @escaping () -> Void) throws -> DependencyContainer {
        StartupTrace.mark("composition.begin")
        defer { StartupTrace.mark("composition.end") }
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let sample = arguments.contains("--sample")
        let firstRun = arguments.contains("--onboarding")
        let defaults: UserDefaults
        if sample {
            let session = arguments.firstIndex(of: "--test-session").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } ?? UUID().uuidString
            defaults = UserDefaults(suiteName: "com.volrik.kaigi.qa.\(session)")!
        } else { defaults = .standard }
        let provider: any CalendarProvider
        if sample {
            let fixture = SampleCalendarGateway(empty: arguments.contains("--empty"), meetingCount: arguments.contains("--fifteen-meetings") ? 15 : arguments.contains("--one-meeting") ? 1 : 3, calendarCount: arguments.contains("--fifty-calendars") ? 50 : 1, longTitles: arguments.contains("--long-titles"))
            if firstRun && !arguments.contains("--connected") { fixture.access = .unknown }
            if arguments.contains("--denied-calendar") { fixture.access = .denied }
            provider = fixture
        } else { provider = EventKitCalendarGateway() }
        StartupTrace.mark("provider.created")
        // Explicit Debug QA can exercise real OS services with synthetic calendars/notes.
        let system: any PreferencesService = sample && !arguments.contains("--live-system-services") ? PreviewPreferencesService() : SystemPreferencesService(defaults: defaults, notifications: UNUserNotificationCenter.current())
        let ai: any AIRefinementService = arguments.contains("--mock-ai") && sample ? MockAIRefinementService(result: "Reviewed synthetic suggestion.") : AIServiceFactory.make()
        #else
        let sample = false; let firstRun = false
        let defaults = UserDefaults.standard
        let provider: any CalendarProvider = EventKitCalendarGateway()
        let system: any PreferencesService = SystemPreferencesService(defaults: defaults, notifications: UNUserNotificationCenter.current())
        let ai: any AIRefinementService = AIServiceFactory.make()
        #endif
        StartupTrace.mark("services.created")
        let store = try NoteRepository(inMemory: sample)
        #if DEBUG
        if sample && arguments.contains("--context-history") {
            let fixtures = SampleCalendarGateway()
            for offset in 1...3 {
                let date = Calendar.current.date(byAdding: .day, value: -offset, to: .now)!
                let day = Calendar.current.dateInterval(of: .day, for: date)!
                if let meeting = try fixtures.meetings(in: day, calendarIDs: ["sample"]).first(where: { $0.externalID == "sample-2" }) {
                    let note = try store.openNote(for: meeting)
                    let paragraphs = offset == 2 ? 32 : 1
                    _ = try store.saveDraft(id: note.id, text: String(repeating: "Synthetic planning notes: reviewed the draft and discussed scope. No owner or deadline was agreed.\n\n", count: paragraphs), reason: "Synthetic review fixture")
                    _ = try store.confirmContext(id: note.id, text: String(repeating: "Review the draft at the next meeting. The scope question remains open.\n\n", count: offset == 2 ? 12 : 1))
                }
            }
        }
        #endif
        StartupTrace.mark("notes.created")
        return try DependencyContainer(providers: [provider], store: store, preferences: AppPreferencesStore(defaults: defaults), systemPreferences: system, ai: ai, opener: WorkspaceLinkOpener(), permissionSettings: WorkspacePermissionSettings(), actions: actions, sample: sample, suppressOnboarding: sample && !firstRun, closeOnboarding: closeOnboarding)
    }
}
#if DEBUG
@MainActor final class PreviewPreferencesService: PreferencesService {
    var aiEnabled = true
    var remindersEnabled = false
    var launchAtLogin = false
    var message: String?
    func setLaunchAtLogin(_ value: Bool) { launchAtLogin = value }
    func setReminders(_ enabled: Bool) async { remindersEnabled = enabled }
    func schedule(_ meetings: [Meeting], now: Date) async {}
}
#endif
