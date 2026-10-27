import SwiftUI
import GudengCore

struct MainPanelContent: View {
    @ObservedObject var model: ClockModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("gudeng.animations") private var animations = true
    @State private var entered = false

    var body: some View {
        let snapshot = model.snapshot
        let countdown = ClockText.countdown(for: snapshot, now: model.now)

        VStack(spacing: 6) {
            ClockBrandHeader().padding(.bottom, 3)
            Text(ClockText.panelStateName(snapshot.state))
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(priceColor)
            CountdownValueView(display: countdown)
            Text(ClockText.panelCountdownLabel(for: snapshot))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text(ClockText.priceLine(for: snapshot))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .scaleEffect(entered ? 1 : 0.97)
        .opacity(entered ? 1 : 0.2)
        .onAppear {
            withAnimation(animations && !reduceMotion ? .spring(response: 0.4, dampingFraction: 0.9) : nil) {
                entered = true
            }
        }
        .onDisappear { entered = false }
        .animation(animations && !reduceMotion ? .easeInOut(duration: 0.3) : nil, value: snapshot.state)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            ClockText.brandTitle + "，" + ClockText.panelAccessibilityLabel(for: snapshot, now: model.now))
    }

    private var priceColor: Color { ClockTheme.price(model.snapshot.state, scheme: colorScheme) }
}
