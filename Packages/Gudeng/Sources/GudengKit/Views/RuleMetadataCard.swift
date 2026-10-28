import SwiftUI
import GudengRuntime

struct RuleMetadataCard: View {
    let status: RuleStatus
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 10) {
            ClockBrandHeader()
            VStack(spacing: 7) {
                SettingsFactRow(title: ClockText.bundleVersionLabel, value: status.bundleVersion)
                SettingsFactRow(
                    title: ClockText.versionsLabel, value: "\(status.pricingVersion) / \(status.calendarVersion)")
                SettingsFactRow(title: ClockText.coverageLabel, value: ClockText.coverageText(status.coverage))
                SettingsFactRow(title: ClockText.originLabel, value: status.originText)
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ClockText.priceCheckLabel).foregroundStyle(.secondary)
                    Text(ClockText.checkedAtText(status.checkedAt)).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(ClockText.calendarCheckLabel).foregroundStyle(.secondary)
                    Text(ClockText.checkedAtText(status.calendarCheckedAt)).monospacedDigit()
                }
            }
            .font(.system(size: 10))
            HStack(spacing: 20) {
                Link(ClockText.priceSourceTitle, destination: status.sourceURL)
                Link(ClockText.calendarSourceTitle, destination: status.calendarSourceURL)
            }
            .font(.system(size: 11))
            .frame(maxWidth: .infinity, minHeight: 28)
            Text(ClockText.communityNotice)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(ClockTheme.brand(scheme).opacity(0.06)))
    }
}
