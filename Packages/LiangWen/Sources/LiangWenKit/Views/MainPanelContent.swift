import SwiftUI
import LiangWenCore

struct MainPanelContent: View {
    @ObservedObject var model: ClockModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let snapshot = model.snapshot
        let countdown = ClockText.countdown(for: snapshot, now: model.now)

        VStack(spacing: 5) {
            Text(ClockText.panelStateName(snapshot.state))
                .font(.system(size: 56, weight: .bold))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ClockText.panelAccessibilityLabel(for: snapshot, now: model.now))
    }

    private var priceColor: Color {
        switch model.snapshot.state {
        case .peak:
            colorScheme == .dark ? Color(red: 1, green: 0.76, blue: 0.24) : Color(red: 0.61, green: 0.31, blue: 0.02)
        case .valley:
            colorScheme == .dark ? Color(red: 0.42, green: 0.94, blue: 0.73) : Color(red: 0.02, green: 0.39, blue: 0.21)
        case nil: .secondary
        }
    }

}
