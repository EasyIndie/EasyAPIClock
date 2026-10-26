import SwiftUI

struct GeneralSettingsSection: View {
    @ObservedObject var model: ClockModel
    let onQuit: (() -> Void)?

    var body: some View {
        SettingsSection(ClockText.generalTitle) {
            #if os(macOS)
                LoginSettingsContent(controller: model.loginItem)
                SettingsRow(ClockText.automaticUpdatesTitle) {
                    Toggle(ClockText.automaticUpdatesTitle, isOn: automaticUpdatesBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                Text(ClockText.automaticUpdatesExplanation)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            #endif
            SettingsRuleInfoView(model: model)
                .padding(.vertical, 4)
            Button(action: checkRules) {
                Text(model.isCheckingForUpdates ? ClockText.ruleCheckingTitle : ClockText.ruleUpdateTitle)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
            .disabled(model.isCheckingForUpdates)
            .accessibilityHint(ClockText.ruleUpdateHint)
            if !model.updateMessage.isEmpty {
                Text(model.updateMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let onQuit {
                Divider().padding(.vertical, 6)
                Button(ClockText.quitTitle, action: onQuit)
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 24)
                    .accessibilityHint(ClockText.quitHint)
            }
        }
    }

    private func checkRules() { Task { await model.checkForUpdates() } }

    private var automaticUpdatesBinding: Binding<Bool> {
        Binding(get: { model.automaticUpdatesEnabled }, set: { model.setAutomaticUpdatesEnabled($0) })
    }
}
