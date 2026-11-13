import SwiftUI

struct ProView: View {
    let model: ProViewModel
    let maximumHeight: CGFloat
    let onHeightChange: (CGFloat) -> Void
    let close: () -> Void
    @State private var footerHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: AppSpacing.none) {
            FittingScrollView(maximumHeight: max(1, maximumHeight - footerHeight)) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Kaigi Pro")
                            .appText(.title, weight: .semibold)
                            .accessibilityAddTraits(.isHeader)
                        Text("Advanced tools for recurring meetings and notes.")
                            .appText(.body)
                            .foregroundStyle(AppColors.secondary)
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        ForEach(model.capabilities) { capability in
                            capabilityRow(capability)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            footer
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    footerHeight = height
                }
        }
        .foregroundStyle(AppColors.primary)
        .background(AppColors.background)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            onHeightChange(height)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Divider()
                .overlay(AppColors.border)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: AppSpacing.sm) {
                    status
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: AppSpacing.none)
                    closeButton
                }
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    status
                    HStack(spacing: AppSpacing.none) {
                        Spacer(minLength: AppSpacing.none)
                        closeButton
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(statusTitle)
                .appText(.body, weight: .semibold)
                .accessibilityIdentifier("pro-window-status")
            if model.state == .free {
                Text("One-time purchase planned. No subscription.")
                    .appText(.caption)
                    .foregroundStyle(AppColors.secondary)
                    .accessibilityIdentifier("pro-purchase-plan")
                Text("Purchasing is currently unavailable.")
                    .appText(.caption)
                    .foregroundStyle(AppColors.secondary)
                    .accessibilityIdentifier("pro-purchase-unavailable")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusTitle: String {
        switch model.state {
        case .loading: "Checking access…"
        case .free: "Coming Soon"
        case .pro: "Kaigi Pro is active"
        }
    }

    private var closeButton: some View {
        Button("Close", action: close)
            .buttonStyle(KaigiButtonStyle())
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("close-pro-window")
    }

    private func capabilityRow(_ capability: ProCapability) -> some View {
        let row = content(for: capability)
        return HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            Image(systemName: row.symbol)
                .appText(.section)
                .foregroundStyle(AppColors.accent)
                .frame(width: AppLayout.brandSymbolSize)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.none) {
                Text(row.title)
                    .appText(.section, weight: .semibold)
                    .accessibilityAddTraits(.isHeader)
                Text(row.description)
                    .appText(.body)
                    .foregroundStyle(AppColors.secondary)
                if capability == .ai {
                    Text("Requires macOS 26+ and a compatible Mac with Apple Intelligence enabled, its model ready, and a supported language.")
                        .appText(.caption)
                        .foregroundStyle(AppColors.secondary)
                        .padding(.top, AppSpacing.xs)
                        .accessibilityIdentifier("pro-ai-requirements")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func content(for capability: ProCapability) -> (symbol: String, title: String, description: String) {
        switch capability {
        case .history:
            ("clock.arrow.circlepath", "Meeting History", "Find notes from previous meetings in the same series.")
        case .context:
            ("repeat", "Recurring Context", "Keep important context between recurring meetings.")
        case .floatingNotes:
            ("pin", "Floating Notes", "Keep your notes visible while you work in other apps.")
        case .ai:
            ("sparkles", "On-device AI", aiDescription)
        }
    }

    private var aiDescription: String {
        if model.offersCleanUp && model.offersStructure { return "Clean up and organize notes locally." }
        if model.offersCleanUp { return "Clean up notes locally." }
        return "Organize notes locally."
    }
}
