import Foundation
import Observation

enum ProCapability: CaseIterable, Identifiable {
    case history, context, floatingNotes, ai

    var id: Self { self }
}

@MainActor @Observable final class ProViewModel {
    private let access: FeatureAccess
    var state: EntitlementState { access.entitlementState }
    var capabilities: [ProCapability] {
        ProCapability.allCases.filter { capability in
            switch capability {
            case .history: access.status(of: .meetingHistory) != .unavailable
            case .context: access.status(of: .recurringContext) != .unavailable
            case .floatingNotes: access.status(of: .floatingNotes) != .unavailable
            case .ai: offersCleanUp || offersStructure
            }
        }
    }
    var offersCleanUp: Bool { access.status(of: .aiCleanUp) != .unavailable }
    var offersStructure: Bool { access.status(of: .aiStructure) != .unavailable }

    init(access: FeatureAccess) { self.access = access }
}
