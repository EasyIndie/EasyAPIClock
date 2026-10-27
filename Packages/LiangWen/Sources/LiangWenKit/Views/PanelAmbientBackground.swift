import SwiftUI
import LiangWenCore

struct PanelAmbientBackground: View {
    let state: PriceState?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if !reduceTransparency {
            LinearGradient(
                colors: [
                    ClockTheme.brand(scheme).opacity(0.08), .clear,
                    ClockTheme.price(state, scheme: scheme).opacity(0.10),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
