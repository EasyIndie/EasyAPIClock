import SwiftUI

struct RuleUpdateRow: View {
    @ObservedObject var model: ClockModel
    @State private var showingDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button(action: checkRules) {
                    Text(model.isCheckingForUpdates ? ClockText.ruleCheckingTitle : ClockText.ruleUpdateTitle)
                }
                .controlSize(.small)
                .fixedSize()
                .disabled(model.isCheckingForUpdates)
                .accessibilityHint(ClockText.ruleUpdateHint)
                Spacer(minLength: 0)
                if !ClockText.ruleUpdateSummary(for: model.updateState).isEmpty {
                    Button {
                        showingDetails = true
                    } label: {
                        Text(ClockText.ruleUpdateSummary(for: model.updateState))
                            .font(.system(size: 11))
                            .foregroundStyle(isFailure ? Color.orange : Color.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 28, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(model.updateMessage)
                    .accessibilityHint(ClockText.ruleResultHint)
                    .help(model.updateMessage)
                    .popover(isPresented: $showingDetails) {
                        Text(model.updateMessage)
                            .font(.system(size: 12))
                            .textSelection(.enabled)
                            .frame(width: 240, alignment: .leading)
                            .padding(12)
                    }
                }
            }
            Text(ClockText.lastAutomaticAttemptText(model.lastAutomaticAttemptAt))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 28)
    }

    private var isFailure: Bool {
        switch model.updateState {
        case .failed, .notConfigured: true
        default: false
        }
    }

    private func checkRules() { Task { await model.checkForUpdates() } }
}
