import SwiftUI
import LiangWenCore
import LiangWenKit

@main
struct LiangWeniOSApp: App {
    var body: some Scene {
        WindowGroup {
            IOSShellView()
        }
    }
}

/// Deliberately minimal shell: the iOS interaction design has not been approved.
/// It exercises the shared rules engine and presentation helpers only.
struct IOSShellView: View {
    private let engine: ClockEngine

    init() {
        do {
            engine = ClockEngine(rules: try BundledRules.load().ruleSet)
        } catch {
            fatalError("内置规则无效：\(error)")
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
        .padding(24)
    }

    private func content(now: Date) -> some View {
        let snapshot = engine.snapshot(at: now)
        let countdown = ClockText.countdown(for: snapshot, now: now)
        return VStack(spacing: 0) {
            Text("谷蹬")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 24)

            Text(ClockText.stateName(snapshot.state))
                .font(.system(size: 32, weight: .medium))
                .tracking(2)
            Text(ClockText.priceLine(for: snapshot))
                .font(.system(size: 14))
                .foregroundStyle(priceColor(snapshot))
                .multilineTextAlignment(.center)

            Spacer(minLength: 28)

            Text(ClockText.countdownLabel(for: snapshot))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(countdown.value)
                .font(.system(size: countdown.isExtended ? 44 : 64, weight: .regular))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(ClockText.nextTransitionLine(for: snapshot, now: now))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 28)

            Text(ClockText.daySummary(for: snapshot))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 16)

            Text("iOS 页面尚未设计确认。\n当前外壳仅用于验证共享规则引擎，不包含通知与设置。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func priceColor(_ snapshot: PriceSnapshot) -> Color {
        switch snapshot.state {
        case .peak: .orange
        case .valley: .green
        case nil: .secondary
        }
    }
}
