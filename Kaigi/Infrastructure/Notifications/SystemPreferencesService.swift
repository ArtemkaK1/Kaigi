import Foundation
import UserNotifications
import ServiceManagement

@MainActor protocol NotificationCenterClient {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func removeAllPendingNotificationRequests()
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}
extension UNUserNotificationCenter: NotificationCenterClient {}

@MainActor @Observable final class SystemPreferencesService: PreferencesService {
    private let defaults: UserDefaults
    var remindersEnabled: Bool
    private let notifications: any NotificationCenterClient
    var aiEnabled: Bool { didSet { defaults.set(aiEnabled, forKey: "aiEnabled") } }
    init(defaults: UserDefaults, notifications: any NotificationCenterClient) {
        self.defaults = defaults; self.notifications = notifications
        remindersEnabled = defaults.bool(forKey: "remindersEnabled")
        aiEnabled = defaults.object(forKey: "aiEnabled") as? Bool ?? true
    }
    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }
    var message: String?
    private var scheduleGeneration = 0
    func setLaunchAtLogin(_ value: Bool) {
        do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
        catch { message = "Launch at login: \(error.localizedDescription)" }
    }
    func setReminders(_ enabled: Bool) async {
        scheduleGeneration += 1
        do {
            remindersEnabled = enabled ? try await notifications.requestAuthorization(options: [.alert, .sound]) : false
            defaults.set(remindersEnabled, forKey: "remindersEnabled")
            if !remindersEnabled { notifications.removeAllPendingNotificationRequests() }
            message = enabled && !remindersEnabled ? "Notifications are disabled. Allow them in System Settings." : nil
        } catch { message = error.localizedDescription }
    }
    func schedule(_ meetings: [Meeting], now: Date = .now) async {
        guard remindersEnabled else { return }
        scheduleGeneration += 1
        let generation = scheduleGeneration
        let center = notifications
        center.removeAllPendingNotificationRequests()
        for (index, meeting) in meetings.filter({ !$0.allDay && $0.start > now.addingTimeInterval(300) }).prefix(32).enumerated() {
            guard generation == scheduleGeneration, !Task.isCancelled, remindersEnabled else { return }
            let content = UNMutableNotificationContent()
            // Do not put private meeting titles or notes on the lock screen.
            content.title = "Your meeting starts soon"
            content.body = "Open Kaigi for your meeting and private notes."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, meeting.start.timeIntervalSince(now) - 300), repeats: false)
            let identifier = "kaigi-\(generation)-\(index)"
            do {
                try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
                if generation != scheduleGeneration || Task.isCancelled || !remindersEnabled {
                    center.removePendingNotificationRequests(withIdentifiers: [identifier]); return
                }
            }
            catch { message = "Reminder scheduling failed: \(error.localizedDescription)"; return }
        }
    }
}
