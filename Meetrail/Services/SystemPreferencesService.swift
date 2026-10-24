import Foundation
import UserNotifications
import ServiceManagement

@MainActor @Observable final class SystemPreferencesService {
    var remindersEnabled = UserDefaults.standard.bool(forKey: "remindersEnabled")
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
            remindersEnabled = enabled ? try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) : false
            UserDefaults.standard.set(remindersEnabled, forKey: "remindersEnabled")
            if !remindersEnabled { UNUserNotificationCenter.current().removeAllPendingNotificationRequests() }
            message = enabled && !remindersEnabled ? "Notifications are disabled. Allow them in System Settings." : nil
        } catch { message = error.localizedDescription }
    }
    func schedule(_ meetings: [Meeting], now: Date = .now) async {
        guard remindersEnabled else { return }
        scheduleGeneration += 1
        let generation = scheduleGeneration
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for (index, meeting) in meetings.filter({ !$0.allDay && $0.start > now.addingTimeInterval(60) }).prefix(32).enumerated() {
            guard generation == scheduleGeneration, !Task.isCancelled, remindersEnabled else { return }
            let content = UNMutableNotificationContent()
            // Do not put private meeting titles or notes on the lock screen.
            content.title = "Your meeting starts soon"
            content.body = "Open Meetrail for your meeting and private notes."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, meeting.start.timeIntervalSince(now) - 60), repeats: false)
            let identifier = "meetrail-\(generation)-\(index)"
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
