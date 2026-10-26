import SwiftUI

struct AppearanceSettingsSection: View {
    @AppStorage("gudeng.appearance") private var appearance = "system"
    @AppStorage("gudeng.animations") private var animations = true

    @State private var expanded = false

    var body: some View {
        DisclosureGroup(ClockText.appearanceTitle, isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 4) {
                SettingsRow(ClockText.displayModeTitle) {
                    Picker(ClockText.displayModeTitle, selection: $appearance) {
                        Text(ClockText.systemAppearance).tag("system")
                        Text(ClockText.lightAppearance).tag("light")
                        Text(ClockText.darkAppearance).tag("dark")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 174)
                }
                SettingsRow(ClockText.animationsTitle) {
                    Toggle(ClockText.animationsTitle, isOn: $animations)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            .padding(.top, 4)
        }
        .frame(minHeight: 24)
    }
}
