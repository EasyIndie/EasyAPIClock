import Foundation

public struct PriceSnapshot: Sendable, Equatable {
    public let evaluatedAt: Date
    public let state: PriceState?
    public let dayKind: DayKind?
    public let weekdayPeriod: WeekdayPeriod?
    /// Start of the current uninterrupted peak or valley run.
    public let stateStartedAt: Date?
    /// The next real state change. `nil` means it could not be confirmed.
    public let nextChangeAt: Date?
    public let nextChangeState: PriceState?
    /// End of the window that begins at `nextChangeAt`, when confirmable.
    public let nextChangeWindowEnd: Date?
    public let comparison: PriceComparison
    public let issue: RuleIssue?

    public var nextChangeIsConfirmed: Bool { nextChangeAt != nil }

    public var currentWindowDuration: TimeInterval? {
        guard let stateStartedAt, let nextChangeAt else { return nil }
        return nextChangeAt.timeIntervalSince(stateStartedAt)
    }

    public var upcomingWindowDuration: TimeInterval? {
        guard let nextChangeAt, let nextChangeWindowEnd else { return nil }
        return nextChangeWindowEnd.timeIntervalSince(nextChangeAt)
    }
}
