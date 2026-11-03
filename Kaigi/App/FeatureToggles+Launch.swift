extension FeatureToggles {
    /// Overrides are limited to Debug's isolated, synthetic QA sessions.
    static func forLaunch(arguments: [String]) -> FeatureToggles {
        #if DEBUG
        if arguments.contains("--sample") && arguments.contains("--all-features") {
            return .allEnabled
        }
        #endif
        return .appStoreFree
    }
}
