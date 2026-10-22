import Foundation

/// Semantic reminder content. The UI layer turns these facts into localized copy.
public struct ReminderFacts: Sendable, Equatable {
    public let targetState: PriceState
    public let comparison: PriceComparison
    /// Duration of the window that starts at the transition, when known.
    public let upcomingWindowDuration: TimeInterval?
    public let leadSeconds: Int?
}

public struct PlannedReminder: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        case transition
        case advance(leadSeconds: Int)
    }

    public let id: String
    public let kind: Kind
    public let fireDate: Date
    public let transitionDate: Date
    public let targetState: PriceState
    public let intensity: ReminderIntensity
    public let facts: ReminderFacts
    /// Extra fire dates for a strong, repeating alert. Always empty for medium.
    public let repeatDates: [Date]

    public var allFireDates: [Date] { [fireDate] + repeatDates }

    /// Stable identity of everything that affects the delivered notification.
    public var signature: String {
        let kindText: String
        switch kind {
        case .transition: kindText = "t"
        case .advance(let lead): kindText = "a\(lead)"
        }
        let multiple = facts.comparison.multiple.map { NSDecimalNumber(decimal: $0).stringValue } ?? "mixed"
        let duration = facts.upcomingWindowDuration.map { String(Int($0.rounded())) } ?? "-"
        return [
            id,
            kindText,
            String(Int(fireDate.timeIntervalSince1970.rounded())),
            intensity.rawValue,
            targetState.rawValue,
            multiple,
            duration,
            String(repeatDates.count),
        ].joined(separator: "|")
    }
}

/// Turns a snapshot into the reminders that should be pending right now.
///
/// Only future fire dates are planned. Nothing is replayed after wake or launch,
/// and deterministic IDs let the scheduler replace (not duplicate) pending work.
public struct ReminderPlanner: Sendable {
    public let now: Date
    public let preferences: UserPreferences
    public let policy: ReminderPolicy

    public init(now: Date, preferences: UserPreferences, policy: ReminderPolicy) {
        self.now = now
        self.preferences = preferences
        self.policy = policy
    }

    public func plan(for snapshot: PriceSnapshot) -> [PlannedReminder] {
        guard preferences.intensity != .off,
            snapshot.state != nil,
            let transitionDate = snapshot.nextChangeAt,
            let targetState = snapshot.nextChangeState,
            transitionDate > now
        else {
            return []
        }

        let facts = ReminderFacts(
            targetState: targetState,
            comparison: snapshot.comparison,
            upcomingWindowDuration: snapshot.upcomingWindowDuration,
            leadSeconds: nil
        )
        let transitionID = "t:\(Int(transitionDate.timeIntervalSince1970.rounded()))"

        var repeatDates: [Date] = []
        if preferences.intensity == .strong, policy.strongMaxRepeats > 0 {
            repeatDates = (1...policy.strongMaxRepeats).map { index in
                transitionDate.addingTimeInterval(
                    Double(index * policy.strongRepeatIntervalSeconds)
                )
            }
        }

        var result = [
            PlannedReminder(
                id: transitionID,
                kind: .transition,
                fireDate: transitionDate,
                transitionDate: transitionDate,
                targetState: targetState,
                intensity: preferences.intensity,
                facts: facts,
                repeatDates: repeatDates
            )
        ]

        if preferences.earlyReminderEnabled, let lead = policy.advanceLeadSeconds {
            let fireDate = transitionDate.addingTimeInterval(-Double(lead))
            if fireDate > now {
                let advanceFacts = ReminderFacts(
                    targetState: targetState,
                    comparison: snapshot.comparison,
                    upcomingWindowDuration: snapshot.upcomingWindowDuration,
                    leadSeconds: lead
                )
                result.append(
                    PlannedReminder(
                        id: "a:\(lead):\(Int(transitionDate.timeIntervalSince1970.rounded()))",
                        kind: .advance(leadSeconds: lead),
                        fireDate: fireDate,
                        transitionDate: transitionDate,
                        targetState: targetState,
                        intensity: preferences.intensity,
                        facts: advanceFacts,
                        repeatDates: []
                    )
                )
            }
        }

        return result.sorted { $0.fireDate < $1.fireDate }
    }
}
