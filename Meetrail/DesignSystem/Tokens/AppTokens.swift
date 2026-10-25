import SwiftUI
import AppKit

// All authored padding and stack spacing use these seven 8-point-grid values.
enum AppSpacing {
    static let none: CGFloat = 0
    static let xs: CGFloat = 8
    static let sm: CGFloat = 16
    static let md: CGFloat = 24
    static let lg: CGFloat = 32
    static let xl: CGFloat = 40
    static let xxl: CGFloat = 48
}

enum AppLayout {
    static let panelWidth: CGFloat = 344
    static let maximumPanelWidth: CGFloat = 380
    static let rowHeight: CGFloat = 64
    static let agendaScrollHeight: CGFloat = 320
    static let emptyHeight: CGFloat = 160
    static let detailHeight: CGFloat = 440
    static let notesWidth: CGFloat = 360
    static let editorIdeal: CGFloat = 176
    static let timeColumn: CGFloat = 56
    static let cornerRadius: CGFloat = 8
    static let providerCardHeight: CGFloat = 80
    static let providerIconSize: CGFloat = 24
    static let providerIconColumn: CGFloat = 32
    static let onboardingWidth: CGFloat = 560
    static let onboardingWelcomeHeight: CGFloat = 320
    static let onboardingReadyHeight: CGFloat = 256
    static let onboardingHeight: CGFloat = 440
    static let reviewHeight: CGFloat = 480 // Debug-only constrained-display fixture.
}

// Shared button geometry. Widths/heights are minimums except equal-width
// conference and square icon controls; all dimensions grow with text scaling.
enum AppButtonSize {
    case regular, icon, conference
    var width: CGFloat { switch self { case .regular, .conference: 64; case .icon: 24 } }
    var height: CGFloat { switch self { case .regular, .conference: 32; case .icon: 24 } }
    var hasFixedWidth: Bool { self != .regular }
}

enum AppColors {
    static let primary = Color(nsColor: .labelColor)
    static let secondary = Color(nsColor: .secondaryLabelColor)
    static let disabled = Color(nsColor: .tertiaryLabelColor)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let editor = Color(nsColor: .textBackgroundColor)
    static let border = Color(nsColor: .separatorColor)
    static let accent = Color.accentColor
    static let onAccent = background
    static let error = Color(nsColor: .systemRed)
    static let warning = Color(nsColor: .systemOrange)
    static let selected = accent.opacity(0.16)
    static let calendarFallback = Color(nsColor: .secondaryLabelColor)
}

enum AppTextRole {
    case caption, body, section, title
    var baseSize: Double { switch self { case .caption: 11; case .body: 13; case .section: 16; case .title: 20 } }
}
enum AppTypography {
    // macOS can leave ScaledMetric unchanged for an explicit Dynamic Type environment.
    // Keep native scaling when it is larger, and honor the requested size as a floor.
    static func scale(for size: DynamicTypeSize) -> Double {
        switch size {
        case .xSmall: 0.88
        case .small: 0.94
        case .medium, .large: 1
        case .xLarge: 1.12
        case .xxLarge: 1.24
        case .xxxLarge: 1.4
        case .accessibility1: 1.64
        case .accessibility2: 1.96
        case .accessibility3: 2.36
        case .accessibility4: 2.76
        case .accessibility5: 3.12
        @unknown default: 1
        }
    }
}
enum AppFontWeight {
    case regular, medium, semibold
    var fontWeight: Font.Weight {
        switch self { case .regular: .regular; case .medium: .medium; case .semibold: .semibold }
    }
}
private struct AppTextModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let role: AppTextRole
    let weight: AppFontWeight
    @ScaledMetric(relativeTo: .caption) private var caption = 11
    @ScaledMetric(relativeTo: .body) private var body = 13
    @ScaledMetric(relativeTo: .headline) private var section = 16
    @ScaledMetric(relativeTo: .title) private var title = 20
    private var size: Double { switch role { case .caption: caption; case .body: body; case .section: section; case .title: title } }
    func body(content: Content) -> some View {
        content
            .font(.system(size: max(size, role.baseSize * AppTypography.scale(for: dynamicTypeSize)), weight: weight.fontWeight))
    }
}
extension View {
    func appText(_ role: AppTextRole = .body, weight: AppFontWeight = .regular) -> some View {
        modifier(AppTextModifier(role: role, weight: weight))
    }
}
