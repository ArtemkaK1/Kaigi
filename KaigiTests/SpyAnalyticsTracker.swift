import Foundation
@testable import Meetrail

@MainActor final class SpyAnalyticsTracker: AnalyticsTracking {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) { events.append(event) }

    func reset() { events.removeAll() }
}
