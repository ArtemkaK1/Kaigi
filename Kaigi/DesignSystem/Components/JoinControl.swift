import SwiftUI

struct JoinControl: View {
    let links: [MeetingLink]
    let action: (MeetingLink) -> Void
    var body: some View {
        Group {
            if links.count == 1, let link = links.first, link.recognized {
                Button("Join") {
                    action(link)
                }
                .accessibilityLabel("Join \(link.provider)")
            } else if !links.isEmpty {
                Menu("Links") {
                    ForEach(links) { link in
                        Button("\(link.provider) · \(link.url.host ?? "")") {
                            action(link)
                        }
                    }
                }
                .menuIndicator(.hidden)
                .help("Choose a calendar link and verify its destination")
            }
        }
        .buttonStyle(KaigiButtonStyle(.primary, size: .conference))
        .controlSize(.small)
    }
}
struct SymbolButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(KaigiButtonStyle(.tertiary, size: .icon))
        .accessibilityLabel(label)
        .help(label)
    }
}
struct InlineMessage: View {
    let text: String
    var isError = false
    var body: some View {
        Label(text, systemImage: isError ? "exclamationmark.circle" : "info.circle")
            .appText(.caption)
            .foregroundStyle(isError ? AppColors.error : AppColors.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
extension AppColors {
    static func calendar(_ value: CalendarColor) -> Color { Color(red: value.red, green: value.green, blue: value.blue) }
}

enum KaigiButtonLevel { case primary, secondary, tertiary }

struct KaigiButtonStyle: ButtonStyle {
    var level: KaigiButtonLevel = .secondary
    var size: AppButtonSize = .regular
    init(_ level: KaigiButtonLevel = .secondary, size: AppButtonSize = .regular) {
        self.level = level; self.size = size
    }
    func makeBody(configuration: Configuration) -> some View {
        KaigiButtonBody(configuration: configuration, level: level, size: size)
    }
}

private struct KaigiButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let level: KaigiButtonLevel
    let size: AppButtonSize
    @State private var hovering = false
    @ScaledMetric(relativeTo: .body) private var nativeScale = 100
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    private var scale: CGFloat { max(nativeScale / 100, AppTypography.scale(for: dynamicTypeSize)) }
    private var fill: Color {
        guard enabled else { return level == .tertiary ? .clear : AppColors.disabledControl }
        switch level {
        case .primary:
            return configuration.isPressed ? AppColors.accentPressed : hovering ? AppColors.accentHover : AppColors.accentFill
        case .secondary:
            return configuration.isPressed ? AppColors.controlPressed : hovering ? AppColors.controlHover : AppColors.control
        case .tertiary:
            return configuration.isPressed ? AppColors.controlPressed : hovering ? AppColors.controlHover : .clear
        }
    }
    var body: some View {
        configuration.label
            .appText(AppTypography.buttonRole, weight: AppTypography.buttonWeight)
            .padding(.horizontal, size == .icon ? AppSpacing.none : AppSpacing.xs)
            .padding(.vertical, size == .icon ? AppSpacing.none : AppSpacing.xs)
            .frame(minWidth: size.width * scale, maxWidth: size.hasFixedWidth ? size.width * scale : nil, minHeight: size.height * scale)
            .foregroundStyle(enabled ? (level == .primary ? AppColors.onAccent : AppColors.primary) : AppColors.disabled)
            .background(fill, in: RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
            .overlay {
                if focused {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadius)
                        .strokeBorder(AppColors.accent, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
            .onHover { hovering = $0 }
    }
}
