import SwiftUI

struct PanelIconButtonStyle: ButtonStyle {
    var destructive = false
    var scales = true

    func makeBody(configuration: Configuration) -> some View {
        Feedback(configuration: configuration, destructive: destructive, scales: scales)
    }

    private struct Feedback: View {
        let configuration: ButtonStyleConfiguration
        let destructive: Bool
        let scales: Bool
        @State private var hovered = false
        @AppStorage("gudeng.animations") private var animations = true
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.colorScheme) private var scheme
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            (destructive ? Color.red : ClockTheme.brand(scheme)).opacity(hovered && enabled ? 0.12 : 0))
                )
                .scaleEffect(
                    scales && animations && !reduceMotion && enabled
                        ? (configuration.isPressed ? 0.95 : (hovered ? 1.02 : 1)) : 1
                )
                .opacity(enabled ? 1 : 0.4)
                .animation(animations && !reduceMotion ? .easeOut(duration: 0.16) : nil, value: hovered)
                .animation(animations && !reduceMotion ? .easeOut(duration: 0.12) : nil, value: configuration.isPressed)
                .onHover { hovered = $0 }
        }
    }
}
