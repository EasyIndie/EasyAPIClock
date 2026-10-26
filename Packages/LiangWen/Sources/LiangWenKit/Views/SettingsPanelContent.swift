import SwiftUI

struct SettingsPanelContent: View {
    @ObservedObject var model: ClockModel
    let onQuit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReminderSettingsSection(model: model)
            Divider()
            AppearanceSettingsSection()
            Divider()
            GeneralSettingsSection(model: model, onQuit: onQuit)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .onAppear { model.loginItem.refresh() }
        .onDisappear { model.stopPreview() }
    }
}
