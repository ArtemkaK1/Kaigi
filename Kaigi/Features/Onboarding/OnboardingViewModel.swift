import Foundation
import Observation

@MainActor @Observable final class OnboardingViewModel {
    private let preferences: any OnboardingPreferences
    private let closeWindow: () -> Void
    let accounts: CalendarAccountsViewModel
    private(set) var progress: OnboardingProgress
    init(preferences: any OnboardingPreferences, accounts: CalendarAccountsViewModel, closeWindow: @escaping () -> Void) {
        self.preferences = preferences; self.accounts = accounts; self.closeWindow = closeWindow
        progress = preferences.onboardingProgress ?? OnboardingProgress()
    }
    var stage: OnboardingStage { progress.stage }
    var shouldAutomaticallyPresent: Bool { progress.disposition == .inProgress }
    var stepNumber: Int { (OnboardingStage.allCases.firstIndex(of: progress.stage) ?? 0) + 1 }
    func next() {
        switch progress.stage {
        case .welcome: progress.stage = .connect
        case .connect: progress.stage = .selection
        case .selection: progress.stage = .ready
        case .ready: progress.disposition = .completed; persist(); closeWindow(); return
        }
        persist()
    }
    func back() {
        switch progress.stage { case .welcome: return; case .connect: progress.stage = .welcome; case .selection: progress.stage = .connect; case .ready: progress.stage = .selection }
        persist()
    }
    func windowClosed() { if progress.disposition == .inProgress { progress.disposition = .skipped; persist() } }
    func skip() { progress.disposition = .skipped; persist(); closeWindow() }
    private func persist() { preferences.onboardingProgress = progress }
}
