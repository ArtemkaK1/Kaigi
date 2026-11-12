import Observation

@MainActor @Observable final class EntitlementStore: EntitlementReading {
    private(set) var state: EntitlementState = .loading
    private let provider: any EntitlementProvider
    @ObservationIgnored private var observers: [() -> Void] = []

    init(provider: any EntitlementProvider) {
        self.provider = provider
        provider.start { [weak self] state in
            guard let self, self.state != state else { return }
            self.state = state
            for observer in self.observers { observer() }
        }
    }

    func observeChanges(_ observer: @escaping () -> Void) { observers.append(observer) }
}
