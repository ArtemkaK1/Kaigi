extension FeatureToggles {
    /// Rollout overrides are limited to Debug's isolated, synthetic QA sessions.
    static func forLaunch(arguments: [String]) -> FeatureToggles {
        #if DEBUG
        if EntitlementLaunchPolicy.allowsSimulation(arguments), arguments.contains("--all-features") {
            return .allEnabled
        }
        #endif
        return .released
    }
}

@MainActor enum EntitlementLaunchPolicy {
    static func makeProvider(arguments: [String]) -> any EntitlementProvider {
        #if DEBUG
        if allowsSimulation(arguments) {
            if arguments.contains("--all-features") { return SimulatedEntitlementProvider(initial: .pro) }
            if arguments.contains("--simulate-entitlement") { return SimulatedEntitlementProvider(initial: .loading) }
        }
        #endif
        return FreeEntitlementProvider()
    }

    #if DEBUG
    nonisolated static func allowsSimulation(_ arguments: [String]) -> Bool {
        arguments.contains("--sample") && !arguments.contains("--marketing-fixtures")
    }
    #endif
}

@MainActor private final class FreeEntitlementProvider: EntitlementProvider {
    func start(deliver: @escaping @MainActor (EntitlementState) -> Void) { deliver(.free) }
}

#if DEBUG
@MainActor final class SimulatedEntitlementProvider: EntitlementProvider {
    private let initial: EntitlementState
    private var deliver: (@MainActor (EntitlementState) -> Void)?

    init(initial: EntitlementState) { self.initial = initial }

    func start(deliver: @escaping @MainActor (EntitlementState) -> Void) {
        self.deliver = deliver
        deliver(initial)
    }

    func simulate(_ state: EntitlementState) { deliver?(state) }
}
#endif

extension ProPresentationPolicy {
    static func forLaunch(arguments: [String]) -> ProPresentationPolicy {
        #if DEBUG
        return ProPresentationPolicy(contextualEntryPointsEnabled:
            EntitlementLaunchPolicy.allowsSimulation(arguments) && arguments.contains("--simulate-entitlement"))
        #else
        return ProPresentationPolicy()
        #endif
    }
}
