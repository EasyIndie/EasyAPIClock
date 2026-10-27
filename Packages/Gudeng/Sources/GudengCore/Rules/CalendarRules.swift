import Foundation

public struct Holiday: Sendable, Equatable, Codable {
    public let name: String
    public let from: LocalDate
    public let through: LocalDate

    public func contains(_ date: LocalDate) -> Bool {
        from <= date && date <= through
    }
}

/// The verified date calendar. Coverage is inclusive on both ends.
///
/// `makeupWorkdays` is informational only. DeepSeek prices every weekend,
/// including make-up working weekends, as valley time, so these dates never
/// change the computed price state.
public struct CalendarRules: Sendable, Equatable, Codable {
    public let schemaVersion: Int
    public let version: String
    public let timeZone: String
    public let source: RuleSource
    public let coverage: LocalDateRange
    public let holidays: [Holiday]
    public let makeupWorkdays: [LocalDate]
    public let notes: [String]?
}
