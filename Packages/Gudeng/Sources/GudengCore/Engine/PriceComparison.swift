import Foundation

/// A price relationship derived from rule data, never hard-coded.
public struct PriceComparison: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// Every billable tier has the same peak/valley ratio.
        case uniform(multiple: Decimal)
        /// Tier ratios differ, so no single multiplier can be shown.
        case mixed
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }

    public init(models: [ModelPrice]) {
        var ratio: Decimal?
        for tier in models.flatMap(\.tiers) {
            let valley = tier.valley.value
            let peak = tier.peak.value
            if valley == 0 {
                if peak == 0 { continue }
                self.init(kind: .mixed)
                return
            }
            if valley < 0 || peak < 0 {
                self.init(kind: .mixed)
                return
            }
            let current = PriceComparison.normalized(peak / valley)
            if let ratio, ratio != current {
                self.init(kind: .mixed)
                return
            }
            ratio = current
        }
        if let ratio {
            self.init(kind: .uniform(multiple: ratio))
        } else {
            self.init(kind: .mixed)
        }
    }

    /// The peak/valley multiplier when one applies and is meaningful.
    public var multiple: Decimal? {
        guard case .uniform(let multiple) = kind, multiple > 1 else { return nil }
        return multiple
    }

    /// By how many percent valley prices are below peak prices, e.g. 50.
    public var valleyPercentLower: Decimal? {
        guard case .uniform(let multiple) = kind, multiple > 1 else { return nil }
        var raw = (1 - 1 / multiple) * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 1, .plain)
        return rounded
    }

    public static let mixed = PriceComparison(kind: .mixed)

    private static func normalized(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 6, .plain)
        return output
    }
}
