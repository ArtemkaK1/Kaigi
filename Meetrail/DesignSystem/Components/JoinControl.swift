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
                    .help("Choose a calendar link and verify its destination")
            }
        }.buttonStyle(MeetrailButtonStyle(prominent: true)).controlSize(.small).appText(.caption, weight: .medium)
    }
}
struct SymbolButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: symbol).frame(width: AppLayout.iconTarget, height: AppLayout.iconTarget) }
            .buttonStyle(MeetrailButtonStyle(compact: true)).appText(.body, weight: .medium).accessibilityLabel(label).help(label)
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
    var compact = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, compact ? AppSpacing.none : AppSpacing.xs)
            .padding(.vertical, compact ? AppSpacing.none : AppSpacing.xs)
            .foregroundStyle(enabled ? (prominent ? AppColors.background : AppColors.primary) : AppColors.disabled)
            .background(prominent && enabled ? AppColors.primary : (configuration.isPressed ? AppColors.selected : AppColors.surface), in: RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
            .overlay { RoundedRectangle(cornerRadius: AppLayout.cornerRadius).strokeBorder(AppColors.border, lineWidth: 1).allowsHitTesting(false) }
            .contentShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
