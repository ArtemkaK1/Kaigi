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
    // Intrinsic symbol geometry, separate from layout spacing.
    static let menuBarSymbolSize: CGFloat = 18
    static let brandSymbolSize: CGFloat = 24
    static let panelWidth: CGFloat = 344
    static let maximumPanelWidth: CGFloat = 380
    static let rowHeight: CGFloat = 64
    static let agendaScrollHeight: CGFloat = 320
    static let emptyHeight: CGFloat = 160
    static let detailHeight: CGFloat = 440
    static let notesWidth: CGFloat = 360
    static let editorIdeal: CGFloat = 176
    // Fits 13 pt medium monospaced times ("11:00 AM" measures about 61.1 pt).
    static let timeColumn: CGFloat = 64
    static let cornerRadius: CGFloat = 8
    static let providerCardHeight: CGFloat = 80
    static let providerIconSize: CGFloat = 24
    static let providerIconColumn: CGFloat = 32
    static let onboardingWidth: CGFloat = 560
    static let onboardingWelcomeHeight: CGFloat = 320
    static let onboardingReadyHeight: CGFloat = 256
    static let onboardingHeight: CGFloat = 440
    static let reviewHeight: CGFloat = 480 // Debug-only constrained-display fixture.
    static let contextWidth: CGFloat = 720
    static let contextHeight: CGFloat = 560
    static let contextMinimumWidth: CGFloat = 600
    static let contextMinimumHeight: CGFloat = 400
    static let contextSidebarMinimum: CGFloat = 160
    static let contextSidebarIdeal: CGFloat = 192
    static let contextSidebarMaximum: CGFloat = 240
}

// Shared button geometry. Widths/heights are minimums except equal-width
// conference and square icon controls; all dimensions grow with text scaling.
enum AppButtonSize {
    case regular, icon, conference
    var width: CGFloat { switch self { case .regular, .conference: 64; case .icon: 24 } }
    var height: CGFloat { switch self { case .regular, .conference: 32; case .icon: 24 } }
    var hasFixedWidth: Bool { self != .regular }
}

// sRGB pairs are intentional palettes, independent of the user's system accent.
// Materials remain native at the NSPopover/window shell; content uses opaque tokens.
enum AppColors {
    static let primary = adaptive(0x211E27, 0xF4F1F8)
    static let secondary = adaptive(0x66616F, 0xB6B0C0)
    static let disabled = adaptive(0x807A89, 0x938B9F)
    static let background = adaptive(0xF7F7FA, 0x1C1A20)
    static let popoverBackground = background
    static let surface = adaptive(0xFFFFFF, 0x27242D)
    static let elevatedSurface = adaptive(0xFFFFFF, 0x302B37)
    static let editor = surface
    static let border = adaptive(0xD9D5E1, 0x4C4557)
    static let accent = adaptive(0x713BD1, 0xBE9AF6)
    static let accentFill = adaptive(0x713BD1, 0x8146CC)
    static let accentHover = adaptive(0x6430BF, 0x8B50D7)
    static let accentPressed = adaptive(0x5727AA, 0x7138B9)
    static let onAccent = Color.white
    static let selected = adaptive(0xEDE5FA, 0x3B2D51)
    static let control = adaptive(0xE9E6EF, 0x3A3444)
    static let controlHover = adaptive(0xDFDAE9, 0x484052)
    static let controlPressed = adaptive(0xD4CCE2, 0x53485F)
    static let disabledControl = adaptive(0xEEECF2, 0x302B37)
    static let error = adaptive(0xB32636, 0xFF929C)
    static let warning = adaptive(0x865500, 0xE9BD6C)
    static let calendarFallback = secondary

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((value >> 16) & 255) / 255,
                           green: Double((value >> 8) & 255) / 255,
                           blue: Double(value & 255) / 255, alpha: 1)
        })
    }
}

enum AppTextRole {
    case caption, body, section, title
    var baseSize: Double { switch self { case .caption: 11; case .body: 13; case .section: 16; case .title: 20 } }
}
enum AppTypography {
    static let buttonRole = AppTextRole.body
    static let buttonWeight = AppFontWeight.medium
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
