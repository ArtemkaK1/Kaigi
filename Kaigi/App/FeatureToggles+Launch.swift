extension FeatureToggles {
    /// Overrides are limited to Debug's isolated, synthetic QA sessions.
    static func forLaunch(arguments: [String]) -> FeatureToggles {
        #if DEBUG
        if arguments.contains("--sample") && arguments.contains("--all-features") && !arguments.contains("--marketing-fixtures") {
            return .allEnabled
        }
        #endif
        return .appStoreFree
    }
}
