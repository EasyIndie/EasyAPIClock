import Foundation

/// Minutes elapsed since local midnight, in the range `0...1440`.
///
/// `1440` is only meaningful as an exclusive window end (24:00).
public struct MinuteOfDay: Sendable, Hashable, Comparable, Codable, CustomStringConvertible {
    public let minutes: Int

    public init?(minutes: Int) {
        guard (0...1440).contains(minutes) else { return nil }
        self.minutes = minutes
    }

    public init?(iso8601 string: String) {
        let parts = string.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
            parts[0].count == 2, parts[1].count == 2,
            let hour = Int(parts[0]), let minute = Int(parts[1]),
            (0...24).contains(hour), (0...59).contains(minute),
            let value = MinuteOfDay(minutes: hour * 60 + minute)
        else {
            return nil
        }
        self = value
    }

    public var hour: Int { minutes / 60 }
    public var minute: Int { minutes % 60 }

    public var description: String {
        String(format: "%02d:%02d", hour, minute)
    }

    public static func < (lhs: MinuteOfDay, rhs: MinuteOfDay) -> Bool {
        lhs.minutes < rhs.minutes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = MinuteOfDay(iso8601: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid time of day '\(raw)'. Expected HH:mm."
            )
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
