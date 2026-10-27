#if os(macOS)
    import SwiftUI

    /// Observe the nested system service independently of the shared clock state.
    struct LoginSettingsContent: View {
        @ObservedObject var controller: LoginItemController

        @ViewBuilder
        var body: some View {
            SettingsRow(ClockText.loginTitle) {
                Toggle(ClockText.loginTitle, isOn: loginBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(controller.state == .unavailable)
            }
            if controller.state == .requiresApproval {
                Text(ClockText.loginApproval).font(.system(size: 11)).foregroundStyle(.secondary)
                Button(ClockText.loginSettings, action: controller.openSettings).controlSize(.small)
            }
            if controller.state == .unavailable {
                Text(ClockText.loginUnavailable).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let message = controller.errorMessage {
                Text(message).font(.system(size: 11)).foregroundStyle(.orange)
            }
        }

        private var loginBinding: Binding<Bool> {
            Binding(
                get: { controller.state == .enabled || controller.state == .requiresApproval },
                set: { controller.setEnabled($0) })
        }

    }
#endif
