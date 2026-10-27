import Foundation

public struct RuleSource: Sendable, Equatable, Codable {
    public let name: String
    public let url: URL
    public let checkedAt: Date
}

/// A recurring peak window on a weekday, using ISO weekdays (Monday = 1).
///
/// Intervals are left-closed and right-open: `[start, end)`.
public struct PeakWindow: Sendable, Equatable, Codable {
    public let weekday: Int
    public let start: MinuteOfDay
    public let end: MinuteOfDay

    public func contains(minuteOfDay: Int) -> Bool {
        start.minutes <= minuteOfDay && minuteOfDay < end.minutes
    }
}

public struct PriceTier: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let label: String
    public let valley: DecimalAmount
    public let peak: DecimalAmount
}

public struct ModelPrice: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let displayName: String
    public let tiers: [PriceTier]
}

/// Verified model token pricing plus the recurring weekly peak windows.
public struct PricingRules: Sendable, Equatable, Codable {
    public let schemaVersion: Int
    public let version: String
    public let effectiveFrom: Date
    public let source: RuleSource
    public let timeZone: String
    public let weeklyPeakWindows: [PeakWindow]
    public let currency: String
    public let unit: String
    public let models: [ModelPrice]
    public let notes: [String]?
}
