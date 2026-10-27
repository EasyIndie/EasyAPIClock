import SwiftUI

struct SettingsRuleInfoView: View {
    @ObservedObject var model: ClockModel
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DisclosureGroup(isExpanded: $expanded) {
                RuleMetadataCard(status: model.ruleStatus)
            } label: {
                HStack {
                    Text(ClockText.rulesTitle)
                    Spacer(minLength: 8)
                    Text(model.ruleStatus.bundleVersion)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
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
