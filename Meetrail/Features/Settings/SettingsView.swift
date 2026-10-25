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
            .appText(.body, weight: .medium)
            .buttonStyle(MeetrailButtonStyle(showsBorder: false))
            Divider()
                .overlay(AppColors.border)
            Toggle("On-device AI", isOn: Binding(get: { model.aiEnabled }, set: model.setAIEnabled))
                .appText(.body)
            Toggle("Remind me 5 minutes before meetings", isOn: Binding(get: { model.remindersEnabled }, set: model.setReminders))
                .appText(.body)
            Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                .appText(.body)
            if let message = model.message {
                InlineMessage(text: message)
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: model.refresh)
    }
}
