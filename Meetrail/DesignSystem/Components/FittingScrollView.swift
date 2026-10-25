import SwiftUI

// Measure rendered content rather than estimating a window height from row counts.
// The viewport grows only up to its cap; longer content remains scrollable.
struct FittingScrollView<Content: View>: View {
    let maximumHeight: CGFloat
    @ViewBuilder var content: () -> Content
    @State private var contentHeight: CGFloat = 1
    var body: some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: {
                    contentHeight = $0
                }
        }
        .frame(height: min(contentHeight, maximumHeight))
    }
}
