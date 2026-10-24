import SwiftUI

// Synthetic review controls never override a production user's text-size environment.
struct ReviewLayoutModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--large-text") {
            content.environment(\.dynamicTypeSize, .accessibility1)
        } else { content }
        #else
        content
        #endif
    }
}
