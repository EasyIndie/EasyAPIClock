import Foundation
import LiangWenCore

/// UI-independent value snapshot shared by device-specific presentation adapters.
public struct ClockSessionState: Sendable, Equatable {
    public let rules: RuleSet
    public let snapshot: PriceSnapshot
    public let preferences: UserPreferences
    public let now: Date
    public let authorization: ReminderAuthorization
    public let ruleStatus: RuleStatus
    public let updateState: UpdateState
    public let isCheckingForUpdates: Bool
    public let automaticUpdatesEnabled: Bool
    public let isPreviewing: Bool
    public let previewOutcome: PreviewOutcome
}
