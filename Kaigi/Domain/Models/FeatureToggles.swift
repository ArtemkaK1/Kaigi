nonisolated enum AppFeature: String, CaseIterable, Sendable {
    case meetingHistory
    case recurringContext
    case aiCleanUp
    case aiStructure
    case revisionHistoryUI
    case floatingNotes
    case markdownExport
    case meetingReminders
    case launchAtLogin
    case calendarManagement
}

/// Immutable rollout configuration. Entitlement never changes this value.
nonisolated struct FeatureToggles: Sendable, Equatable {
    private let enabled: Set<AppFeature>

    init(enabled: Set<AppFeature>) { self.enabled = enabled }

    func isEnabled(_ feature: AppFeature) -> Bool { enabled.contains(feature) }

    static let released = FeatureToggles(enabled: [
        .calendarManagement, .meetingReminders, .markdownExport, .launchAtLogin, .revisionHistoryUI,
        .meetingHistory, .recurringContext, .floatingNotes, .aiCleanUp, .aiStructure
    ])
    static let allEnabled = FeatureToggles(enabled: Set(AppFeature.allCases))
}
