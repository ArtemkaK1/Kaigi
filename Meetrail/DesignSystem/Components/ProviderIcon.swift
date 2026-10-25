import SwiftUI
import AppKit

extension EnvironmentValues {
    @Entry var systemCalendarArtwork: Image? = nil
}

// Vendor artwork stays in its original colors/proportions. CalDAV is a protocol,
// not a vendor brand. Missing artwork always has a neutral, local fallback.
struct ProviderIcon: View {
    let kind: CalendarProviderKind
    @Environment(\.systemCalendarArtwork) private var systemArtwork
    @Environment(\.dynamicTypeSize) private var textSize
    private var artwork: Image? {
        if kind == .system { return systemArtwork }
        let name: String
        switch kind {
        case .google: name = "ProviderGoogle"
        case .microsoft: name = "ProviderMicrosoft"
        case .yandex: name = "ProviderYandex"
        case .zoho: name = "ProviderZoho"
        default: return nil
        }
        return NSImage(named: name).map { Image(nsImage: $0) }
    }
    var body: some View {
        Group {
            if let artwork {
                artwork.resizable().renderingMode(.original).scaledToFit()
            } else {
                Image(systemName: kind == .calDAV ? "network" : "calendar")
                    .resizable().scaledToFit().foregroundStyle(AppColors.secondary)
            }
        }.frame(width: AppLayout.providerIconSize * AppTypography.scale(for: textSize), height: AppLayout.providerIconSize * AppTypography.scale(for: textSize))
            .accessibilityHidden(true)
    }
}
