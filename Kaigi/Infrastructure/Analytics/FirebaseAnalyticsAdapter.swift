import FirebaseAnalytics

/// Construction is inert: composition precedes Firebase configuration in AppDelegate.
@MainActor final class FirebaseAnalyticsAdapter: AnalyticsTracking {
    private var configured = false

    func configurationDidComplete() { configured = true }

    func track(_ event: AnalyticsEvent) {
        guard configured else { return }
        let parameters: [String: Any] = event.parameters.mapValues { value in
            switch value {
            case .string(let string): return string
            case .integer(let integer): return integer
            }
        }
        Analytics.logEvent(event.name, parameters: parameters.isEmpty ? nil : parameters)
    }
}
