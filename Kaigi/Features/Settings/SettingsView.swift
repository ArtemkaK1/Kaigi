import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Settings")
                .appText(.section, weight: .semibold)
                .accessibilityAddTraits(.isHeader)
            if model.features.isEnabled(.calendarManagement) {
                Button(action: model.showAccounts) {
                    HStack(spacing: AppSpacing.xs) {
                        Label("Accounts & Calendars", systemImage: "calendar");
                        Spacer(minLength: AppSpacing.xs);
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(KaigiButtonStyle(.tertiary))
            }
            if model.features.isEnabled(.calendarManagement) && (model.hasAI || model.features.isEnabled(.meetingReminders) || model.features.isEnabled(.launchAtLogin)) {
                Divider()
                    .overlay(AppColors.border)
            }
            if model.hasAI {
                Toggle("On-device AI", isOn: Binding(get: { model.aiEnabled }, set: model.setAIEnabled))
                    .appText(.body)
                    .tint(AppColors.accentFill)
            }
            if model.features.isEnabled(.meetingReminders) {
                Toggle("Remind me 5 minutes before meetings", isOn: Binding(get: { model.remindersEnabled }, set: model.setReminders))
                    .appText(.body)
                    .tint(AppColors.accentFill)
            }
            if model.features.isEnabled(.launchAtLogin) {
                Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                    .appText(.body)
                    .tint(AppColors.accentFill)
            }
            if let message = model.message {
                InlineMessage(text: message)
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: model.refresh)
    }
}
