import AppKit
import SwiftUI
import Testing
@testable import Meetrail

@MainActor struct TimeColumnLayoutTests {
    @Test func sharedColumnFitsRenderedClockStringsAndRecoveredCaption() {
        let times = ["9:00 AM", "11:00 AM", "12:30 PM", "11:00\u{202F}AM", "09:00", "11:00", "12:30", "23:59", "All day"]
        let sizes: [DynamicTypeSize] = [.large, .accessibility1, .accessibility2, .accessibility5]
        for size in sizes {
            for role in [AppTextRole.body, .caption] {
                for time in times {
                    let label = Text(time)
                        .appText(role, weight: .medium)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .environment(\.dynamicTypeSize, size)
                    let measured = NSHostingView(rootView: label).fittingSize
                    #expect(measured.width > 0)
                    #expect(measured.width <= AppLayout.timeColumn * AppTypography.scale(for: size), "\(time), \(size), \(role): \(measured.width) pt")
                }
            }
        }
    }
}
