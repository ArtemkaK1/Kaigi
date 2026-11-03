enum AppFeature: String, CaseIterable, Sendable {
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

/// Immutable availability only. No preferences, account state or network configuration.
struct FeatureToggles: Sendable, Equatable {
    private let enabled: Set<AppFeature>

    init(enabled: Set<AppFeature>) { self.enabled = enabled }

    func isEnabled(_ feature: AppFeature) -> Bool { enabled.contains(feature) }

    static let appStoreFree = FeatureToggles(enabled: [
        .calendarManagement, .meetingReminders, .markdownExport, .launchAtLogin
    ])
    static let allEnabled = FeatureToggles(enabled: Set(AppFeature.allCases))
}
