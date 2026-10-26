import Foundation

/// Persist attempts, including failures, so wakeups cannot create a retry storm.
public struct AutomaticUpdateSchedule: Sendable {
    public static let interval: TimeInterval = 6 * 60 * 60
    public private(set) var lastAttempt: Date?

    public init(lastAttempt: Date? = nil) { self.lastAttempt = lastAttempt }

    public func isDue(at now: Date, enabled: Bool) -> Bool {
        guard enabled else { return false }
        guard let lastAttempt else { return true }
        return now < lastAttempt || now.timeIntervalSince(lastAttempt) >= Self.interval
    }

    public mutating func recordAttempt(at now: Date) { lastAttempt = now }
}
