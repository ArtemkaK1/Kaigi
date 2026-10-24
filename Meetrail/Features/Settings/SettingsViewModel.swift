import Foundation
import Observation

@MainActor @Observable final class SettingsViewModel {
    private let service: any PreferencesService
    private let actions: any ApplicationActions
    private let onChanged: () -> Void
    private(set) var aiEnabled: Bool
    private(set) var remindersEnabled: Bool
    private(set) var launchAtLogin: Bool
    private(set) var message: String?
    init(service: any PreferencesService, actions: any ApplicationActions, onChanged: @escaping () -> Void) {
        self.service = service; self.actions = actions; self.onChanged = onChanged
        aiEnabled = service.aiEnabled; remindersEnabled = service.remindersEnabled; launchAtLogin = service.launchAtLogin
    }
    func refresh() { aiEnabled = service.aiEnabled; remindersEnabled = service.remindersEnabled; launchAtLogin = service.launchAtLogin; message = service.message }
    func setReminders(_ value: Bool) { Task { await service.setReminders(value); refresh(); onChanged() } }
    func setLaunchAtLogin(_ value: Bool) { service.setLaunchAtLogin(value); refresh() }
    func showAccounts() { actions.showAccounts() }
    func setAIEnabled(_ value: Bool) { service.aiEnabled = value; refresh(); onChanged() }
}
