import Foundation
@testable import GudengCore

enum Fixture {
    static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso) else {
            fatalError("Invalid test date: \(iso)")
        }
        return date
    }

    static func localDate(_ value: String) -> LocalDate {
        guard let date = LocalDate(iso8601: value) else {
            fatalError("Invalid local date: \(value)")
        }
        return date
    }

    static func minute(_ value: String) -> MinuteOfDay {
        guard let minute = MinuteOfDay(iso8601: value) else {
            fatalError("Invalid minute: \(value)")
        }
        return minute
    }

    static let source = RuleSource(
        name: "测试价格来源",
        url: URL(string: "https://example.com/pricing")!,
        checkedAt: date("2026-01-01T00:00:00+08:00")
    )

    static func peakWindows() -> [PeakWindow] {
        (1...5).flatMap { weekday in
            [
                PeakWindow(weekday: weekday, start: minute("09:00"), end: minute("12:00")),
                PeakWindow(weekday: weekday, start: minute("14:00"), end: minute("18:00")),
            ]
        }
    }

    static func tier(
        id: String = "output",
        valley: String = "1",
        peak: String = "2"
    ) -> PriceTier {
        PriceTier(
            id: id,
            label: id,
            valley: DecimalAmount(Decimal(string: valley)!),
            peak: DecimalAmount(Decimal(string: peak)!)
        )
    }

    static func pricing(
        windows: [PeakWindow]? = nil,
        tiers: [PriceTier]? = nil
    ) -> PricingRules {
        let models = [
            ModelPrice(
                id: "test-model",
                displayName: "test-model",
                tiers: tiers ?? [tier()]
            )
        ]
        return PricingRules(
            schemaVersion: 1,
            version: "pricing-test-1",
            effectiveFrom: date("2026-01-01T00:00:00+08:00"),
            source: source,
            timeZone: "Asia/Shanghai",
            weeklyPeakWindows: windows ?? peakWindows(),
            currency: "CNY",
            unit: "perMillionTokens",
            models: models,
            notes: nil
        )
    }

    static func calendar(
        holidays: [Holiday] = [],
        coverage: LocalDateRange? = nil,
        makeupWorkdays: [LocalDate] = []
    ) -> CalendarRules {
        CalendarRules(
            schemaVersion: 1,
            version: "calendar-test-1",
            timeZone: "Asia/Shanghai",
            source: source,
            coverage: coverage
                ?? LocalDateRange(
                    from: localDate("2026-01-01"),
                    through: localDate("2026-12-31")
                ),
            holidays: holidays,
            makeupWorkdays: makeupWorkdays,
            notes: nil
        )
    }

    static func policy(
        defaultIntensity: ReminderIntensity = .medium,
        advanceSeconds: [Int] = [300],
        repeatInterval: Int = 30,
        maxRepeats: Int = 10
    ) -> ReminderPolicy {
        ReminderPolicy(
            schemaVersion: 1,
            version: "policy-test-1",
            defaultIntensity: defaultIntensity,
            advanceOptionsSeconds: advanceSeconds,
            strongRepeatIntervalSeconds: repeatInterval,
            strongMaxRepeats: maxRepeats,
            soundEnabled: true,
            notes: nil
        )
    }

    static func rules(
        pricing: PricingRules? = nil,
        calendar: CalendarRules? = nil,
        policy: ReminderPolicy? = nil
    ) -> RuleSet {
        RuleSet(
            pricing: pricing ?? Self.pricing(),
            calendar: calendar ?? Self.calendar(),
            reminderPolicy: policy ?? Self.policy(),
            bundleVersion: "test-bundle-1",
            publishedAt: date("2026-01-01T00:00:00+08:00"),
            effectiveFrom: date("2026-01-01T00:00:00+08:00")
        )
    }

    static func engine(
        holidays: [Holiday] = [],
        coverage: LocalDateRange? = nil
    ) -> ClockEngine {
        ClockEngine(rules: rules(calendar: calendar(holidays: holidays, coverage: coverage)))
    }
}
