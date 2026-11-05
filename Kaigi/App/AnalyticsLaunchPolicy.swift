import Foundation

/// Release ignores QA flags. XCTest hosts are isolated in every configuration.
enum AnalyticsLaunchPolicy {
    static func usesLiveAnalytics(arguments: [String], isTesting: Bool) -> Bool {
        guard !isTesting else { return false }
        #if DEBUG
        let isolated = ["--sample", "--marketing-fixtures", "--all-features", "--test-session"]
        if arguments.contains(where: isolated.contains) { return false }
        #endif
        return true
    }
}
