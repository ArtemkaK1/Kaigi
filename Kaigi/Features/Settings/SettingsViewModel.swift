import Foundation
import Observation

@MainActor @Observable final class SettingsViewModel {
    let features: FeatureToggles
    var hasAI: Bool { features.isEnabled(.aiCleanUp) || features.isEnabled(.aiStructure) }
    private let service: any PreferencesService
    private let actions: any ApplicationActions
    private let onChanged: () -> Void
    private(set) var aiEnabled: Bool
    private(set) var remindersEnabled: Bool
    private(set) var launchAtLogin: Bool
    private(set) var message: String?
    init(service: any PreferencesService, actions: any ApplicationActions, features: FeatureToggles = .appStoreFree, onChanged: @escaping () -> Void) {
        self.features = features
        self.service = service; self.actions = actions; self.onChanged = onChanged
        aiEnabled = service.aiEnabled; remindersEnabled = service.remindersEnabled; launchAtLogin = service.launchAtLogin
    }
    func refresh() { aiEnabled = service.aiEnabled; remindersEnabled = service.remindersEnabled; launchAtLogin = service.launchAtLogin; message = service.message }
    func setReminders(_ value: Bool) { guard features.isEnabled(.meetingReminders) else { return }; Task { await service.setReminders(value); refresh(); onChanged() } }
    func setLaunchAtLogin(_ value: Bool) { guard features.isEnabled(.launchAtLogin) else { return }; service.setLaunchAtLogin(value); refresh() }
    func showAccounts() { guard features.isEnabled(.calendarManagement) else { return }; actions.showAccounts() }
    func setAIEnabled(_ value: Bool) { guard hasAI else { return }; service.aiEnabled = value; refresh(); onChanged() }
}
