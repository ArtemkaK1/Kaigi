import AppKit
import SwiftUI

/// Observe the existing Settings scene's native window, including close/reopen.
/// Refocusing an already-open window does not start another presentation.
struct WindowPresentationObserver: NSViewRepresentable {
    let onPresented: () -> Void
    let onDismissed: () -> Void

    func makeNSView(context: Context) -> ObserverView {
        ObserverView(onPresented: onPresented, onDismissed: onDismissed)
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {}

    static func dismantleNSView(_ nsView: ObserverView, coordinator: ()) { nsView.stopObserving() }

    final class ObserverView: NSView {
        private let onPresented: () -> Void
        private let onDismissed: () -> Void
        private var tokens: [NSObjectProtocol] = []

        init(onPresented: @escaping () -> Void, onDismissed: @escaping () -> Void) {
            self.onPresented = onPresented; self.onDismissed = onDismissed
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopObserving()
            guard let window else { return }
            let center = NotificationCenter.default
            tokens.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onPresented() }
            })
            tokens.append(center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onDismissed() }
            })
            if window.isVisible { onPresented() }
        }

        func stopObserving() {
            for token in tokens { NotificationCenter.default.removeObserver(token) }
            tokens.removeAll()
            onDismissed()
        }

        deinit {
            for token in tokens { NotificationCenter.default.removeObserver(token) }
        }
    }
}
