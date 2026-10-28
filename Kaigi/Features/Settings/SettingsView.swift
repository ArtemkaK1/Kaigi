import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Settings")
                .appText(.section, weight: .semibold)
                .accessibilityAddTraits(.isHeader)
            Button(action: model.showAccounts) {
                HStack(spacing: AppSpacing.xs) {
                    Label("Accounts & Calendars", systemImage: "calendar");
                    Spacer(minLength: AppSpacing.xs);
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(KaigiButtonStyle(.tertiary))
            Divider()
                .overlay(AppColors.border)
            Toggle("On-device AI", isOn: Binding(get: { model.aiEnabled }, set: model.setAIEnabled))
                .appText(.body)
                .tint(AppColors.accentFill)
            Toggle("Remind me 5 minutes before meetings", isOn: Binding(get: { model.remindersEnabled }, set: model.setReminders))
                .appText(.body)
                .tint(AppColors.accentFill)
            Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                .appText(.body)
                .tint(AppColors.accentFill)
            if let message = model.message {
                InlineMessage(text: message)
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: model.refresh)
    }
}
