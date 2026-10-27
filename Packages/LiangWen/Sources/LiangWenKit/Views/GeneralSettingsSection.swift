import SwiftUI

struct GeneralSettingsSection: View {
    @ObservedObject var model: ClockModel
    @ObservedObject private var loginItem: LoginItemController
    @State private var expanded = false

    init(model: ClockModel) {
        self.model = model
        self.loginItem = model.loginItem
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DisclosureGroup(ClockText.generalTitle, isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 4) {
                    #if os(macOS)
                        LoginSettingsContent(controller: model.loginItem)
                        SettingsRow(ClockText.automaticUpdatesTitle) {
                            Toggle(ClockText.automaticUpdatesTitle, isOn: automaticUpdatesBinding)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .help(ClockText.automaticUpdatesExplanation)
                        }
                        Text(ClockText.lastAutomaticAttemptText(model.lastAutomaticAttemptAt))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(ClockText.automaticUpdatesExplanation)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    #endif
                }
            }
            if !expanded {
                if let error = loginItem.errorMessage {
                    Text(error).font(.system(size: 11)).foregroundStyle(.orange)
                } else if loginItem.state == .requiresApproval {
                    Text(ClockText.loginApproval).font(.system(size: 11)).foregroundStyle(.orange)
                }
            }
        }
    }

    private var automaticUpdatesBinding: Binding<Bool> {
        Binding(get: { model.automaticUpdatesEnabled }, set: { model.setAutomaticUpdatesEnabled($0) })
    }
}
