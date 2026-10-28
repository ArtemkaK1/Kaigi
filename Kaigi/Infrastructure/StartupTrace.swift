import Foundation

// Opt-in diagnostics only. Never records calendar identifiers, titles or note text.
nonisolated enum StartupTrace {
    static func mark(_ stage: String) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--startup-timing") else { return }
        NSLog("KAIGI_STARTUP %@ uptime=%.6f main=%d", stage, ProcessInfo.processInfo.systemUptime, Thread.isMainThread ? 1 : 0)
        #endif
    }
}
