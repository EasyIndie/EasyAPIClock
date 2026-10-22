import SwiftUI
import LiangWenCore

struct MainPanelContent: View {
    let model: ClockModel

    var body: some View {
        let snapshot = model.snapshot
        let countdown = ClockText.countdown(for: snapshot, now: model.now)

        VStack(spacing: 0) {
            VStack(spacing: 9) {
                Text(ClockText.stateName(snapshot.state))
                    .font(.system(size: 24, weight: .medium))
                    .tracking(2)
                Text(ClockText.priceLine(for: snapshot))
                    .font(.system(size: 13))
                    .foregroundStyle(priceColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 26)
            .padding(.horizontal, 16)

            VStack(spacing: 7) {
                Text(ClockText.countdownLabel(for: snapshot))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(countdown.value)
                    .font(.system(size: countdown.isExtended ? 36 : 54, weight: .regular))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(transitionCaption(countdown))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 24)
            .padding(.bottom, 28)
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(countdown))
    }

    private var priceColor: Color {
        switch model.snapshot.state {
        case .peak: .orange
        case .valley: .green
        case nil: .secondary
        }
    }

    private func transitionCaption(_ countdown: ClockText.CountdownDisplay) -> String {
        let line = ClockText.nextTransitionLine(for: model.snapshot, now: model.now)
        guard !countdown.isExtended, let caption = countdown.unitCaption else {
            return line
        }
        return "\(caption) · \(line)"
    }

    private func accessibilityLabel(_ countdown: ClockText.CountdownDisplay) -> String {
        let snapshot = model.snapshot
        guard let state = snapshot.state else {
            return "价格状态待确认。\(ClockText.issueText(snapshot.issue ?? .nextChangeUnconfirmed))"
        }
        let name = state == .peak ? "高峰" : "低价"
        let comparison = ClockText.priceLine(for: snapshot)
        guard snapshot.nextChangeAt != nil else {
            return "当前\(name)时段。\(comparison)。下次切换待确认。"
        }
        return "当前\(name)时段。\(comparison)。距离下次切换 \(countdown.value)。"
    }
}
