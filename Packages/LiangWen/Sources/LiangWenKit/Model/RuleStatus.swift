import Foundation
import LiangWenCore

public struct RuleStatus: Sendable, Equatable {
    public let bundleVersion: String
    public let pricingVersion: String
    public let calendarVersion: String
    public let coverage: LocalDateRange
    public let sourceName: String
    public let sourceURL: URL
    public let checkedAt: Date
    public let calendarSourceURL: URL
    public let calendarCheckedAt: Date
    public let origin: RuleRepository.Origin
    public let pendingVersion: String?
    public let installedError: String?

    public var originText: String {
        origin == .bundled ? "内置规则" : "已下载规则"
    }
}

public enum UpdateState: Sendable, Equatable {
    case idle
    case notConfigured
    case checking
    case upToDate(String)
    case updated(String)
    case failed(String)
}
