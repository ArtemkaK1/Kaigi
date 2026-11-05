import Foundation

@MainActor protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

struct NoOpAnalyticsTracker: AnalyticsTracking {
    nonisolated init() {}

    func track(_ event: AnalyticsEvent) {}
}
