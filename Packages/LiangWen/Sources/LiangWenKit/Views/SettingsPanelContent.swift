import SwiftUI

struct SettingsPanelContent: View {
    @ObservedObject var model: ClockModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReminderSettingsSection(model: model)
            Divider().padding(.vertical, 5)
            AppearanceSettingsSection()
            GeneralSettingsSection(model: model)
            SettingsRuleInfoView(model: model)
            Divider().padding(.vertical, 5)
            RuleUpdateRow(model: model)
        }
        .disclosureGroupStyle(SettingsDisclosureStyle())
        .font(.system(size: 12))
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .onAppear { model.loginItem.refresh() }
        .onDisappear { model.stopPreview() }
    }
}
