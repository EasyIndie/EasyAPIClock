import Foundation

/// A calendar date without a time or time zone.
///
/// Rule data uses this type for holiday ranges and coverage windows so that
/// decoding never depends on the device locale or time zone.
public struct LocalDate: Sendable, Hashable, Comparable, Codable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(year: Int, month: Int, day: Int) {
        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day) else {
            return nil
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        let calendar = RuleTime.makeCalendar()
        guard let date = calendar.date(from: components),
            calendar.component(.year, from: date) == year,
            calendar.component(.month, from: date) == month,
            calendar.component(.day, from: date) == day
        else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    public init?(iso8601 string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
            parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
            let value = LocalDate(year: year, month: month, day: day)
        else {
            return nil
        }
        self = value
    }

    public init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        // A Gregorian calendar always yields these components for a valid Date.
        self.year = components.year ?? 1970
        self.month = components.month ?? 1
        self.day = components.day ?? 1
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public func startDate(in calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }

    public func adding(days: Int, in calendar: Calendar) -> LocalDate? {
        guard let start = startDate(in: calendar),
            let result = calendar.date(byAdding: .day, value: days, to: start)
        else {
            return nil
        }
        return LocalDate(date: result, calendar: calendar)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = LocalDate(iso8601: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid local date '\(raw)'. Expected YYYY-MM-DD."
            )
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

public struct LocalDateRange: Sendable, Hashable, Codable {
    public let from: LocalDate
    public let through: LocalDate

    public init(from: LocalDate, through: LocalDate) {
        self.from = from
        self.through = through
    }

    public var isValid: Bool { from <= through }

    public func contains(_ date: LocalDate) -> Bool {
        from <= date && date <= through
    }
}
