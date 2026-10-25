import SwiftUI

@main struct MeetrailApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings {
            if let settings = delegate.container?.settings {
                SettingsView(model: settings)
                    .frame(width: AppLayout.notesWidth)
                    .background(AppColors.background)
                    .tint(AppColors.accent)
            }
        }
        .windowResizability(.contentSize)
    }
}
