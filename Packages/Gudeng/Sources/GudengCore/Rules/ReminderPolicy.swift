import Foundation

public enum ReminderIntensity: String, Sendable, Codable, CaseIterable, Comparable {
    case off
    case medium
    case strong

    public var rank: Int {
        switch self {
        case .off: 0
        case .medium: 1
        case .strong: 2
        }
    }

    public static func < (lhs: ReminderIntensity, rhs: ReminderIntensity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Remote-tunable reminder policy. User preferences always win over these values.
public struct ReminderPolicy: Sendable, Equatable, Codable {
    public let schemaVersion: Int
    public let version: String
    public let defaultIntensity: ReminderIntensity
    public let advanceOptionsSeconds: [Int]
    public let strongRepeatIntervalSeconds: Int
    public let strongMaxRepeats: Int
    public let soundEnabled: Bool
    public let notes: [String]?

    /// The first configured advance offset. Version 0.1 exposes a single option.
    public var advanceLeadSeconds: Int? { advanceOptionsSeconds.first }
}

/// User-owned preferences. Rule updates must never overwrite this value.
public struct UserPreferences: Sendable, Equatable, Codable {
    public var intensity: ReminderIntensity
    public var earlyReminderEnabled: Bool

    public init(intensity: ReminderIntensity = .medium, earlyReminderEnabled: Bool = false) {
        self.intensity = intensity
        self.earlyReminderEnabled = earlyReminderEnabled
    }

    public static func initial(policy: ReminderPolicy) -> UserPreferences {
        UserPreferences(intensity: policy.defaultIntensity, earlyReminderEnabled: false)
    }
}
