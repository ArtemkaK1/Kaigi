import SwiftUI

struct OnboardingView: View {
    @Bindable var model: OnboardingViewModel
    var onStageChange: (OnboardingStage) -> Void = { _ in }
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Label("Meetrail", systemImage: "note.text").appText(.section, weight: .semibold)
                Spacer(minLength: AppSpacing.xs)
                Text("Step \(model.stepNumber) of 4").appText(.caption).foregroundStyle(AppColors.secondary)
            }
            Divider().overlay(AppColors.border)
            Group {
                switch model.stage {
                case .welcome:
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Your meetings. Your notes. All connected.").appText(.title, weight: .semibold).accessibilityAddTraits(.isHeader)
                            Text("Meetings and private notes, together in your menu bar.").appText(.body).foregroundStyle(AppColors.secondary)
                            Label("Open a meeting and write freely", systemImage: "square.and.pencil").appText(.body)
                            Label("Keep context across recurring meetings", systemImage: "text.bubble").appText(.body)
                            Label("Keep your notes on this Mac", systemImage: "lock").appText(.body)
                        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                    }.defaultScrollAnchor(.center, for: .alignment)
                case .connect:
                    ProviderConnectionsView(model: model.accounts)
                case .selection:
                    CalendarSelectionView(model: model.accounts)
                case .ready:
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Label("You're ready", systemImage: "checkmark.circle").appText(.title, weight: .semibold).accessibilityAddTraits(.isHeader)
                            Text("\(model.accounts.selectedCount) calendars selected. Open Meetrail from the note icon in your menu bar.").appText(.body)
                            Text("Manage calendars and preferences in Settings.").appText(.body).foregroundStyle(AppColors.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                    }.defaultScrollAnchor(.center, for: .alignment)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider().overlay(AppColors.border)
            HStack(spacing: AppSpacing.xs) {
                if model.stage != .welcome { SymbolButton(symbol: "chevron.left", label: "Previous step", action: model.back) }
                Button("Skip for now", action: model.skip).appText(.body).buttonStyle(MeetrailButtonStyle())
                Spacer(minLength: AppSpacing.xs)
                Button(model.stage == .ready ? "Open Meetrail" : "Continue", action: model.next).appText(.body, weight: .semibold).buttonStyle(MeetrailButtonStyle(prominent: true)).keyboardShortcut(.defaultAction)
            }
        }.padding(AppSpacing.sm).background(AppColors.background).foregroundStyle(AppColors.primary).tint(AppColors.accent)
            .onChange(of: model.stage) { _, stage in onStageChange(stage) }
    }
}
