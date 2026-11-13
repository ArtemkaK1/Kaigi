import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Settings")
                .appText(.section, weight: .semibold)
                .accessibilityAddTraits(.isHeader)
            if model.access.allows(.calendarManagement) {
                Button(action: model.showAccounts) {
                    HStack(spacing: AppSpacing.xs) {
                        Label("Accounts & Calendars", systemImage: "calendar");
                        Spacer(minLength: AppSpacing.xs);
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(KaigiButtonStyle(.tertiary))
            }
            if model.access.allows(.calendarManagement) && (model.hasAI || model.access.allows(.meetingReminders) || model.access.allows(.launchAtLogin)) {
                Divider()
                    .overlay(AppColors.border)
            }
            if model.hasAI {
                Toggle("On-device AI", isOn: Binding(get: { model.aiEnabled }, set: model.setAIEnabled))
                    .appText(.body)
                    .tint(AppColors.accentFill)
            }
            if model.access.allows(.meetingReminders) {
                Toggle("Remind me 5 minutes before meetings", isOn: Binding(get: { model.remindersEnabled }, set: model.setReminders))
                    .appText(.body)
                    .tint(AppColors.accentFill)
            }
            if model.access.allows(.launchAtLogin) {
                Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                    .appText(.body)
                    .tint(AppColors.accentFill)
            }
            if let message = model.message {
                InlineMessage(text: message)
            }
            Divider()
                .overlay(AppColors.border)
            Button(action: model.showPro) {
                HStack(spacing: AppSpacing.xs) {
                    Label("Kaigi Pro", systemImage: "sparkles")
                    Spacer(minLength: AppSpacing.none)
                    Text(proStatus)
                        .appText(.caption)
                        .foregroundStyle(AppColors.secondary)
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(KaigiButtonStyle(.tertiary))
            .accessibilityLabel("Kaigi Pro")
            .accessibilityValue(proStatus)
            .accessibilityIdentifier("settings-kaigi-pro")
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: model.refresh)
    }

    private var proStatus: String {
        switch model.proState {
        case .loading: "Checking access…"
        case .free: "Coming Soon"
        case .pro: "Active"
        }
    }
}
