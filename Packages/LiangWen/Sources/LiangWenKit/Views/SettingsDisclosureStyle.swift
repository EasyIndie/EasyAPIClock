import SwiftUI

/// Give every settings group the same header height and a full-width button target.
struct SettingsDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                configuration.isExpanded.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 12)
                        .accessibilityHidden(true)
                    configuration.label
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isExpanded ? ClockText.groupExpanded : ClockText.groupCollapsed)
            .accessibilityHint(ClockText.groupToggleHint)
            .help(ClockText.groupToggleHint)
            if configuration.isExpanded {
                configuration.content
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
        }
    }
}
