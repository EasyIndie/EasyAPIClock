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
                Text(ClockText.animationsExplanation)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
