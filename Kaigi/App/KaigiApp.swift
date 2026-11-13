import SwiftUI

@main struct KaigiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings {
            if let settings = delegate.container?.settings {
                SettingsView(model: settings)
                    .frame(width: AppLayout.notesWidth)
                    .background(AppColors.background)
                    .tint(AppColors.accent)
                    .modifier(ReviewLayoutModifier())
                    .background {
                        WindowPresentationObserver(onPresented: settings.presented, onDismissed: settings.dismissed)
                    }
            }
        }
        .windowResizability(.contentSize)
        #if DEBUG
        .commands {
            if delegate.canSimulateEntitlement {
                CommandMenu("Entitlement QA") {
                    Button("Simulate Loading") { delegate.simulateEntitlement(.loading) }
                    Button("Simulate Free") { delegate.simulateEntitlement(.free) }
                    Button("Simulate Pro") { delegate.simulateEntitlement(.pro) }
                }
            }
        }
        #endif
    }
}
