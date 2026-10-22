import Foundation

/// An exact decimal amount decoded from either a JSON string or number.
///
/// Rule files use strings (`"0.02"`) so that binary floating point never
/// changes a published price. Numbers are accepted for hand-written fixtures.
public struct DecimalAmount: Sendable, Hashable, Comparable, Codable, CustomStringConvertible {
    public let value: Decimal

    public init(_ value: Decimal) {
        self.value = value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let raw = try? container.decode(String.self) {
            guard let decimal = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid decimal amount '\(raw)'."
                )
            }
            self.value = decimal
        } else {
            self.value = try container.decode(Decimal.self)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public var description: String {
        NSDecimalNumber(decimal: value).stringValue
    }

    public static func < (lhs: DecimalAmount, rhs: DecimalAmount) -> Bool {
        lhs.value < rhs.value
    }
}
