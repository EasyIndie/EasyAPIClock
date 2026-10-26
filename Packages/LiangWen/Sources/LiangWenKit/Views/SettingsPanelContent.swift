import SwiftUI

struct SettingsPanelContent: View {
    @ObservedObject var model: ClockModel
    let onQuit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ReminderSettingsSection(model: model)
            Divider().padding(.vertical, 2)
            AppearanceSettingsSection()
            GeneralSettingsSection(model: model)
            SettingsRuleInfoView(model: model)
            Divider().padding(.vertical, 2)
            HStack {
                Button(action: checkRules) {
                    Text(model.isCheckingForUpdates ? ClockText.ruleCheckingTitle : ClockText.ruleUpdateTitle)
                }
                .controlSize(.small)
                .disabled(model.isCheckingForUpdates)
                .accessibilityHint(ClockText.ruleUpdateHint)
                Spacer()
                if let onQuit {
                    Button(ClockText.quitTitle, action: onQuit)
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 24)
                        .accessibilityHint(ClockText.quitHint)
                }
            }
            if !model.updateMessage.isEmpty {
                Text(model.updateMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .onAppear { model.loginItem.refresh() }
        .onDisappear { model.stopPreview() }
    }

    private func checkRules() { Task { await model.checkForUpdates() } }
}
