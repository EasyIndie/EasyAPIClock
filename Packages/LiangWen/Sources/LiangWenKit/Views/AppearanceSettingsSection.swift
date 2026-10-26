import SwiftUI

struct AppearanceSettingsSection: View {
    @AppStorage("gudeng.appearance") private var appearance = "system"
    @AppStorage("gudeng.animations") private var animations = true

    @State private var expanded = false

    var body: some View {
        DisclosureGroup(ClockText.appearanceTitle, isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 4) {
                SettingsRow(ClockText.displayModeTitle) {
                    SettingsSegments(
                        title: ClockText.displayModeTitle,
                        titles: [ClockText.systemAppearance, ClockText.lightAppearance, ClockText.darkAppearance],
                        selection: appearanceBinding)
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

    private var appearanceBinding: Binding<Int> {
        let values = ["system", "light", "dark"]
        return Binding(
            get: { values.firstIndex(of: appearance) ?? 0 },
            set: { index in
                guard values.indices.contains(index) else { return }
                appearance = values[index]
            })
    }

}
