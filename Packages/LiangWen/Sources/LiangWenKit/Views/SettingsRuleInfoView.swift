import SwiftUI

struct SettingsRuleInfoView: View {
    @ObservedObject var model: ClockModel
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(ClockText.officialRulesTitle)
                    Text(ClockText.ruleVersions(model.ruleStatus))
                    Text(ClockText.ruleCoverage(model.ruleStatus))
                    Text(ClockText.priceVerification(model.ruleStatus))
                    Text(ClockText.calendarVerification(model.ruleStatus))
                    HStack(spacing: 14) {
                        Link(ClockText.priceSourceTitle, destination: model.ruleStatus.sourceURL)
                        Link(ClockText.calendarSourceTitle, destination: model.ruleStatus.calendarSourceURL)
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            } label: {
                HStack {
                    Text(ClockText.rulesTitle)
                    Spacer(minLength: 8)
                    Text(model.ruleStatus.bundleVersion)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 24)
            }
            // Problems remain visible even while the metadata is collapsed.
            if let issue = model.snapshot.issue {
                Text(ClockText.issueText(issue)).foregroundStyle(.orange)
            }
            if let pending = model.ruleStatus.pendingVersion {
                Text(ClockText.pendingRules(pending)).foregroundStyle(.secondary)
            }
            if model.ruleStatus.installedError != nil {
                Text(ClockText.invalidDownloadedRules).foregroundStyle(.orange)
            }
        }
        .font(.system(size: 11))
        .fixedSize(horizontal: false, vertical: true)
    }
}
