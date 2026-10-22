import Foundation

/// A complete, validated rule bundle: pricing + datetime calendar + reminder policy.
public struct RuleSet: Sendable, Equatable {
    public let pricing: PricingRules
    public let calendar: CalendarRules
    public let reminderPolicy: ReminderPolicy
    public let bundleVersion: String
    public let publishedAt: Date
    public let effectiveFrom: Date

    public init(
        pricing: PricingRules,
        calendar: CalendarRules,
        reminderPolicy: ReminderPolicy,
        bundleVersion: String,
        publishedAt: Date,
        effectiveFrom: Date
    ) {
        self.pricing = pricing
        self.calendar = calendar
        self.reminderPolicy = reminderPolicy
        self.bundleVersion = bundleVersion
        self.publishedAt = publishedAt
        self.effectiveFrom = effectiveFrom
    }
}
