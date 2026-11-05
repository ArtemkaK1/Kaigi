import Foundation
import Observation

@MainActor @Observable final class OnboardingViewModel {
    private let analytics: any AnalyticsTracking
    private let preferences: any OnboardingPreferences
    private let closeWindow: () -> Void
    let accounts: CalendarAccountsViewModel
    private(set) var progress: OnboardingProgress

    init(preferences: any OnboardingPreferences, accounts: CalendarAccountsViewModel, analytics: any AnalyticsTracking, closeWindow: @escaping () -> Void) {
        self.analytics = analytics
        self.preferences = preferences; self.accounts = accounts; self.closeWindow = closeWindow
        progress = preferences.onboardingProgress ?? OnboardingProgress()
    }
    var stage: OnboardingStage { progress.stage }
    var shouldAutomaticallyPresent: Bool { progress.disposition == .inProgress }
    var stepNumber: Int { (OnboardingStage.allCases.firstIndex(of: progress.stage) ?? 0) + 1 }

    func presented() {
        guard !preferences.analyticsOnboardingStarted, progress.disposition == .inProgress else { return }
        preferences.analyticsOnboardingStarted = true
        analytics.track(.onboardingStarted)
    }

    func requestConnection(_ kind: CalendarProviderKind) {
        accounts.requestConnection(kind, fromOnboarding: true)
    }

    func next() {
        switch progress.stage {
        case .welcome: progress.stage = .connect
        case .connect: progress.stage = .selection
        case .selection: progress.stage = .ready
        case .ready:
            let completed = progress.disposition != .completed
            progress.disposition = .completed; persist()
            if completed { analytics.track(.onboardingCompleted) }
            closeWindow(); return
        }
        persist()
    }

    func back() {
        switch progress.stage { case .welcome: return; case .connect: progress.stage = .welcome; case .selection: progress.stage = .connect; case .ready: progress.stage = .selection }
        persist()
    }

    func windowClosed() { if progress.disposition == .inProgress { progress.disposition = .skipped; persist() } }

    func skip() {
        let skipped = progress.disposition != .skipped
        progress.disposition = .skipped; persist()
        if skipped { analytics.track(.onboardingSkipped) }
        closeWindow()
    }

    private func persist() { preferences.onboardingProgress = progress }
}
