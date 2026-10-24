import SwiftUI

struct JoinControl: View {
    let links: [MeetingLink]
    let action: (MeetingLink) -> Void
    var body: some View {
        Group {
            if links.count == 1, let link = links.first, link.recognized {
                Button("Join") { action(link) }.accessibilityLabel("Join \(link.provider)")
            } else if !links.isEmpty {
                Menu("Links") { ForEach(links) { link in Button("\(link.provider) · \(link.url.host ?? "")") { action(link) } } }
                    .menuIndicator(.hidden).help("Choose a calendar link and verify its destination")
            }
        }.buttonStyle(MeetrailButtonStyle(prominent: true, size: .conference)).controlSize(.small).appText(.caption, weight: .medium)
    }
}
struct SymbolButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(MeetrailButtonStyle(size: .icon)).appText(.body, weight: .medium).accessibilityLabel(label).help(label)
    }
}
struct InlineMessage: View {
    let text: String
    var isError = false
    var body: some View {
        Label(text, systemImage: isError ? "exclamationmark.circle" : "info.circle")
            .appText(.caption).foregroundStyle(isError ? AppColors.error : AppColors.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
extension AppColors {
    static func calendar(_ value: CalendarColor) -> Color { Color(red: value.red, green: value.green, blue: value.blue) }
}

struct MeetrailButtonStyle: ButtonStyle {
    var prominent = false
    var size: AppButtonSize = .regular
    @ScaledMetric(relativeTo: .body) private var nativeScale = 100
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var scale: CGFloat { max(nativeScale / 100, AppTypography.scale(for: dynamicTypeSize)) }
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, size == .icon ? AppSpacing.none : AppSpacing.xs)
            .padding(.vertical, size == .icon ? AppSpacing.none : AppSpacing.xs)
            .frame(minWidth: size.width * scale, maxWidth: size.hasFixedWidth ? size.width * scale : nil, minHeight: size.height * scale)
            .foregroundStyle(enabled ? (prominent ? AppColors.onAccent : AppColors.accent) : AppColors.disabled)
            .background(prominent && enabled ? AppColors.accent : (configuration.isPressed ? AppColors.selected : AppColors.surface), in: RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
            .overlay { RoundedRectangle(cornerRadius: AppLayout.cornerRadius).strokeBorder(AppColors.border, lineWidth: 1).allowsHitTesting(false) }
            .contentShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
