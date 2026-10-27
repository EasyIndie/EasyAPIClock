import SwiftUI

/// Give every settings group the same header height and a full-width button target.
struct SettingsDisclosureStyle: DisclosureGroupStyle {
    @AppStorage("gudeng.animations") private var animations = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(animations && !reduceMotion ? .spring(response: 0.28, dampingFraction: 0.9) : nil) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
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
            .buttonStyle(PanelIconButtonStyle(scales: false))
            .accessibilityValue(configuration.isExpanded ? ClockText.groupExpanded : ClockText.groupCollapsed)
            .accessibilityHint(ClockText.groupToggleHint)
            .help(ClockText.groupToggleHint)
            if configuration.isExpanded {
                configuration.content
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
