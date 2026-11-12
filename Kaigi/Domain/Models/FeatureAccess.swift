nonisolated enum EntitlementState: Equatable, Sendable {
    case loading, free, pro
}

@MainActor protocol EntitlementReading: AnyObject {
    var state: EntitlementState { get }

    func observeChanges(_ observer: @escaping () -> Void)
}

@MainActor protocol EntitlementProvider: AnyObject {
    /// Publishes the initial resolution and subsequent changes on the main actor.
    /// Providers may resolve asynchronously and should release the callback on teardown.
    func start(deliver: @escaping @MainActor (EntitlementState) -> Void)
}

nonisolated enum FeatureAccessStatus: Equatable, Sendable {
    case unavailable, loading, requiresPro, available
}

@MainActor struct FeatureAccess {
    let toggles: FeatureToggles
    private let entitlement: any EntitlementReading

    init(toggles: FeatureToggles, entitlement: any EntitlementReading) {
        self.toggles = toggles
        self.entitlement = entitlement
    }

    func status(of feature: AppFeature) -> FeatureAccessStatus {
        guard toggles.isEnabled(feature) else { return .unavailable }
        switch feature {
        case .calendarManagement, .meetingReminders, .markdownExport, .launchAtLogin, .revisionHistoryUI:
            return .available
        case .meetingHistory, .recurringContext, .floatingNotes, .aiCleanUp, .aiStructure:
            switch entitlement.state {
            case .loading: return .loading
            case .free: return .requiresPro
            case .pro: return .available
            }
        }
    }

    func allows(_ feature: AppFeature) -> Bool { status(of: feature) == .available }

    func observeChanges(_ observer: @escaping () -> Void) { entitlement.observeChanges(observer) }

    var allowsMeetingContextWindow: Bool { allows(.meetingHistory) || allows(.recurringContext) }
}
