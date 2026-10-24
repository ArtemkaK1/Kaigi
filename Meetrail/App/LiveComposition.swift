import Foundation
import UserNotifications

extension DependencyContainer {
    static func makeLive(actions: any ApplicationActions, closeOnboarding: @escaping () -> Void) throws -> DependencyContainer {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let sample = arguments.contains("--sample")
        let firstRun = arguments.contains("--onboarding")
        let defaults: UserDefaults
        if sample {
            let session = arguments.firstIndex(of: "--test-session").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } ?? UUID().uuidString
            defaults = UserDefaults(suiteName: "com.volrik.meetrail.qa.\(session)")!
        } else { defaults = .standard }
        let provider: any CalendarProvider
        if sample {
            let fixture = SampleCalendarGateway(empty: arguments.contains("--empty"), meetingCount: arguments.contains("--fifteen-meetings") ? 15 : arguments.contains("--one-meeting") ? 1 : 3, calendarCount: arguments.contains("--fifty-calendars") ? 50 : 1, longTitles: arguments.contains("--long-titles"))
            if firstRun && !arguments.contains("--connected") { fixture.access = .unknown }
            provider = fixture
        } else { provider = EventKitCalendarGateway() }
        let system: any PreferencesService = sample ? PreviewPreferencesService() : SystemPreferencesService(defaults: defaults, notifications: UNUserNotificationCenter.current())
        let ai: any AIRefinementService = arguments.contains("--mock-ai") && sample ? MockAIRefinementService(result: "Reviewed synthetic suggestion.") : AIServiceFactory.make()
        #else
        let sample = false; let firstRun = false
        let defaults = UserDefaults.standard
        let provider: any CalendarProvider = EventKitCalendarGateway()
        let system: any PreferencesService = SystemPreferencesService(defaults: defaults, notifications: UNUserNotificationCenter.current())
        let ai: any AIRefinementService = AIServiceFactory.make()
        #endif
        return try DependencyContainer(providers: [provider], store: NoteRepository(inMemory: sample), preferences: AppPreferencesStore(defaults: defaults), systemPreferences: system, ai: ai, opener: WorkspaceLinkOpener(), permissionSettings: WorkspacePermissionSettings(), actions: actions, sample: sample, suppressOnboarding: sample && !firstRun, closeOnboarding: closeOnboarding)
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
