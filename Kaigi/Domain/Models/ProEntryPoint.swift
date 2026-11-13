nonisolated enum ProEntryPoint: Equatable, Sendable {
    case settings
    case meetingContext
    case floatingNotes
    case ai(RefinementAction)
}

nonisolated struct ProPresentationPolicy: Sendable {
    let contextualEntryPointsEnabled: Bool

    init(contextualEntryPointsEnabled: Bool = false) {
        self.contextualEntryPointsEnabled = contextualEntryPointsEnabled
    }

    @MainActor func canPresent(from entry: ProEntryPoint, access: FeatureAccess) -> Bool {
        switch entry {
        case .settings:
            return true
        case .meetingContext:
            return contextualEntryPointsEnabled && !access.allowsMeetingContextWindow &&
                (access.status(of: .meetingHistory) == .requiresPro || access.status(of: .recurringContext) == .requiresPro)
        case .floatingNotes:
            return contextualEntryPointsEnabled && access.status(of: .floatingNotes) == .requiresPro
        case .ai(let action):
            return contextualEntryPointsEnabled && access.status(of: action.feature) == .requiresPro
        }
    }
}
