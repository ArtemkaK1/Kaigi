import Foundation
import Observation

@MainActor @Observable final class SettingsViewModel {
    private let analytics: any AnalyticsTracking
    private var isPresented = false
    let access: FeatureAccess
    var hasAI: Bool { access.allows(.aiCleanUp) || access.allows(.aiStructure) }
    private let service: any PreferencesService
    private let actions: any ApplicationActions
    private let onChanged: () -> Void
    private(set) var aiEnabled: Bool
    private(set) var remindersEnabled: Bool
    private(set) var launchAtLogin: Bool
    private(set) var message: String?

    init(service: any PreferencesService, actions: any ApplicationActions, access: FeatureAccess, analytics: any AnalyticsTracking, onChanged: @escaping () -> Void) {
        self.analytics = analytics
        self.access = access
        self.service = service; self.actions = actions; self.onChanged = onChanged
        aiEnabled = service.aiEnabled; remindersEnabled = service.remindersEnabled; launchAtLogin = service.launchAtLogin
    }

    func presented() {
        guard !isPresented else { return }
        isPresented = true; analytics.track(.settingsOpened); refresh()
    }

    func dismissed() { isPresented = false }

    func refresh() { aiEnabled = service.aiEnabled; remindersEnabled = service.remindersEnabled; launchAtLogin = service.launchAtLogin; message = service.message }

    func setReminders(_ value: Bool) { guard access.allows(.meetingReminders) else { return }; Task { await changeReminders(value) } }

    func setLaunchAtLogin(_ value: Bool) { guard access.allows(.launchAtLogin) else { return }; let before = service.launchAtLogin; service.setLaunchAtLogin(value); refresh(); if before != launchAtLogin { analytics.track(.settingsLaunchAtLoginChanged(launchAtLogin)) } }

    func changeReminders(_ value: Bool) async {
        guard access.allows(.meetingReminders) else { return }
        await service.setReminders(value)
        let before = remindersEnabled
        refresh(); onChanged()
        if before != remindersEnabled { analytics.track(.settingsRemindersChanged(remindersEnabled)) }
    }

    func showAccounts() { guard access.allows(.calendarManagement) else { return }; actions.showAccounts() }

    func setAIEnabled(_ value: Bool) { guard hasAI else { return }; service.aiEnabled = value; refresh(); onChanged() }
}
