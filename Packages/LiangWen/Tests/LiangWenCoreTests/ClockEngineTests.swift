import Foundation
import Testing
@testable import LiangWenCore

@Suite("价格时钟引擎")
struct ClockEngineTests {
    private let engine = Fixture.engine()

    @Test("工作日时段边界：09:00 峰、12:00 谷、14:00 峰、18:00 谷")
    func weekdayBoundaries() throws {
        let beforePeak = engine.snapshot(at: Fixture.date("2026-10-21T08:59:00+08:00"))
        #expect(beforePeak.state == .valley)
        #expect(beforePeak.nextChangeAt == Fixture.date("2026-10-21T09:00:00+08:00"))
        #expect(beforePeak.nextChangeState == .peak)
        #expect(beforePeak.nextChangeWindowEnd == Fixture.date("2026-10-21T12:00:00+08:00"))
        #expect(beforePeak.dayKind == .weekday)
        #expect(beforePeak.weekdayPeriod == .early)

        let peakStart = engine.snapshot(at: Fixture.date("2026-10-21T09:00:00+08:00"))
        #expect(peakStart.state == .peak)
        #expect(peakStart.nextChangeAt == Fixture.date("2026-10-21T12:00:00+08:00"))
        #expect(peakStart.nextChangeState == .valley)
        #expect(peakStart.stateStartedAt == Fixture.date("2026-10-21T09:00:00+08:00"))

        let lastPeakSecond = engine.snapshot(at: Fixture.date("2026-10-21T11:59:59+08:00"))
        #expect(lastPeakSecond.state == .peak)
        #expect(lastPeakSecond.nextChangeAt == Fixture.date("2026-10-21T12:00:00+08:00"))

        let noon = engine.snapshot(at: Fixture.date("2026-10-21T12:00:00+08:00"))
        #expect(noon.state == .valley)
        #expect(noon.nextChangeAt == Fixture.date("2026-10-21T14:00:00+08:00"))
        #expect(noon.nextChangeState == .peak)
        #expect(noon.weekdayPeriod == .midday)

        let afternoon = engine.snapshot(at: Fixture.date("2026-10-21T14:00:00+08:00"))
        #expect(afternoon.state == .peak)
        #expect(afternoon.nextChangeAt == Fixture.date("2026-10-21T18:00:00+08:00"))

        let evening = engine.snapshot(at: Fixture.date("2026-10-21T18:00:00+08:00"))
        #expect(evening.state == .valley)
        #expect(evening.nextChangeAt == Fixture.date("2026-10-22T09:00:00+08:00"))
        #expect(evening.stateStartedAt == Fixture.date("2026-10-21T18:00:00+08:00"))
    }

    @Test("周四凌晨不会产生午夜伪切换")
    func noMidnightTransition() {
        let late = engine.snapshot(at: Fixture.date("2026-10-21T23:30:00+08:00"))
        #expect(late.state == .valley)
        #expect(late.nextChangeAt == Fixture.date("2026-10-22T09:00:00+08:00"))

        let midnight = engine.snapshot(at: Fixture.date("2026-10-22T00:00:00+08:00"))
        #expect(midnight.state == .valley)
        #expect(midnight.nextChangeAt == Fixture.date("2026-10-22T09:00:00+08:00"))
    }

    @Test("周五晚间跨周末到周一 09:00")
    func fridayEveningToMonday() {
        let friday = engine.snapshot(at: Fixture.date("2026-10-23T18:00:00+08:00"))
        #expect(friday.state == .valley)
        #expect(friday.nextChangeAt == Fixture.date("2026-10-26T09:00:00+08:00"))
        #expect(friday.nextChangeState == .peak)
        #expect(friday.stateStartedAt == Fixture.date("2026-10-23T18:00:00+08:00"))

        let saturday = engine.snapshot(at: Fixture.date("2026-10-24T10:00:00+08:00"))
        #expect(saturday.state == .valley)
        #expect(saturday.dayKind == .weekend)
        #expect(saturday.weekdayPeriod == nil)
        #expect(saturday.nextChangeAt == Fixture.date("2026-10-26T09:00:00+08:00"))
        #expect(saturday.stateStartedAt == Fixture.date("2026-10-23T18:00:00+08:00"))

        let sundayLate = engine.snapshot(at: Fixture.date("2026-10-25T23:59:00+08:00"))
        #expect(sundayLate.nextChangeAt == Fixture.date("2026-10-26T09:00:00+08:00"))

        let mondayMidnight = engine.snapshot(at: Fixture.date("2026-10-26T00:00:00+08:00"))
        #expect(mondayMidnight.state == .valley)
        #expect(mondayMidnight.nextChangeAt == Fixture.date("2026-10-26T09:00:00+08:00"))
    }

    @Test("周末全天谷，不因午夜重复提醒")
    func weekendHasNoMidnightTransition() {
        for time in ["00:00", "09:00", "12:00", "18:00", "23:59"] {
            let snapshot = engine.snapshot(at: Fixture.date("2026-10-24T\(time):00+08:00"))
            #expect(snapshot.state == .valley, "周六 \(time)")
            #expect(snapshot.nextChangeAt == Fixture.date("2026-10-26T09:00:00+08:00"), "周六 \(time)")
        }
    }

    @Test("调休上班的周六仍为谷")
    func makeupSaturdayStaysValley() {
        let calendar = Fixture.calendar(makeupWorkdays: [Fixture.localDate("2026-10-24")])
        let engine = ClockEngine(rules: Fixture.rules(calendar: calendar))
        let snapshot = engine.snapshot(at: Fixture.date("2026-10-24T10:00:00+08:00"))
        #expect(snapshot.state == .valley)
        #expect(snapshot.dayKind == .weekend)
        #expect(snapshot.nextChangeAt == Fixture.date("2026-10-26T09:00:00+08:00"))
    }

    @Test("法定节假日按日期覆盖为谷")
    func holidayOverridesWeekday() {
        let holiday = Holiday(
            name: "测试节日",
            from: Fixture.localDate("2026-10-26"),
            through: Fixture.localDate("2026-10-26")
        )
        let engine = Fixture.engine(holidays: [holiday])
        let monday = engine.snapshot(at: Fixture.date("2026-10-26T10:00:00+08:00"))
        #expect(monday.state == .valley)
        #expect(monday.dayKind == .holiday(name: "测试节日"))
        #expect(monday.nextChangeAt == Fixture.date("2026-10-27T09:00:00+08:00"))
        #expect(monday.nextChangeWindowEnd == Fixture.date("2026-10-27T12:00:00+08:00"))
        #expect(monday.stateStartedAt == Fixture.date("2026-10-23T18:00:00+08:00"))

        let sunday = engine.snapshot(at: Fixture.date("2026-10-25T23:00:00+08:00"))
        #expect(sunday.nextChangeAt == Fixture.date("2026-10-27T09:00:00+08:00"))
    }

    @Test("节假日覆盖优先于每周规则")
    func holidayOverridesWeeklyWindow() {
        let holiday = Holiday(
            name: "测试节日",
            from: Fixture.localDate("2026-10-21"),
            through: Fixture.localDate("2026-10-21")
        )
        let engine = Fixture.engine(holidays: [holiday])
        let snapshot = engine.snapshot(at: Fixture.date("2026-10-21T10:00:00+08:00"))
        #expect(snapshot.state == .valley)
        #expect(snapshot.nextChangeAt == Fixture.date("2026-10-22T09:00:00+08:00"))
    }

    @Test("连续假期合并为一段谷期")
    func consecutiveHolidaysMerge() {
        let holidays = [
            Holiday(name: "测试节日", from: Fixture.localDate("2026-10-26"), through: Fixture.localDate("2026-10-28"))
        ]
        let engine = Fixture.engine(holidays: holidays)
        let snapshot = engine.snapshot(at: Fixture.date("2026-10-27T12:00:00+08:00"))
        #expect(snapshot.state == .valley)
        #expect(snapshot.nextChangeAt == Fixture.date("2026-10-29T09:00:00+08:00"))
    }

    @Test("跨时区按北京时间判断")
    func timeZoneIsBeijing() {
        // 01:00Z == 09:00 Beijing
        #expect(engine.state(at: Fixture.date("2026-10-21T01:00:00Z")) == .peak)
        let lastSecond = engine.snapshot(at: Fixture.date("2026-10-21T03:59:59Z"))
        #expect(lastSecond.state == .peak)
        #expect(lastSecond.nextChangeAt == Fixture.date("2026-10-21T04:00:00Z"))
        #expect(engine.state(at: Fixture.date("2026-10-21T04:00:00Z")) == .valley)
        // Thursday 00:00 Beijing
        #expect(engine.state(at: Fixture.date("2026-10-21T16:00:00Z")) == .valley)
    }

    @Test("当前窗口与下一窗口时长")
    func windowDurations() {
        let snapshot = engine.snapshot(at: Fixture.date("2026-10-23T19:00:00+08:00"))
        #expect(snapshot.currentWindowDuration == 63 * 3600.0)
        #expect(snapshot.upcomingWindowDuration == 3 * 3600.0)
    }

    @Test("日期覆盖结束后不再给出确定结论")
    func expiredCoverage() {
        let coverage = LocalDateRange(
            from: Fixture.localDate("2026-01-01"),
            through: Fixture.localDate("2026-10-23")
        )
        let engine = Fixture.engine(coverage: coverage)

        let weekday = engine.snapshot(at: Fixture.date("2026-10-29T10:00:00+08:00"))
        #expect(weekday.state == nil)
        #expect(weekday.dayKind == nil)
        #expect(weekday.nextChangeAt == nil)
        #expect(weekday.issue == .calendarExpired(through: Fixture.localDate("2026-10-23")))

        let weekend = engine.snapshot(at: Fixture.date("2026-10-31T12:00:00+08:00"))
        #expect(weekend.state == .valley)
        #expect(weekend.dayKind == .weekend)
        #expect(weekend.nextChangeAt == nil)
        #expect(weekend.issue == .calendarExpired(through: Fixture.localDate("2026-10-23")))

        let friday = engine.snapshot(at: Fixture.date("2026-10-23T19:00:00+08:00"))
        #expect(friday.state == .valley)
        #expect(friday.nextChangeAt == nil)
        #expect(friday.issue == .calendarExpired(through: Fixture.localDate("2026-10-23")))
    }

    @Test("覆盖开始前的星期几无法确认")
    func beforeCoverage() {
        let coverage = LocalDateRange(
            from: Fixture.localDate("2026-10-01"),
            through: Fixture.localDate("2026-12-31")
        )
        let engine = Fixture.engine(coverage: coverage)
        let snapshot = engine.snapshot(at: Fixture.date("2026-09-30T10:00:00+08:00"))
        #expect(snapshot.state == nil)
        #expect(snapshot.issue == .dateUnverified(Fixture.localDate("2026-09-30")))
    }

    @Test("价格倍率由规则计算")
    func priceComparison() {
        let uniform = PriceComparison(models: [
            ModelPrice(
                id: "a", displayName: "a",
                tiers: [
                    Fixture.tier(id: "input", valley: "0.02", peak: "0.04"),
                    Fixture.tier(id: "output", valley: "4", peak: "8"),
                ])
        ])
        #expect(uniform.multiple == 2)
        #expect(uniform.valleyPercentLower == 50)

        let mixed = PriceComparison(models: [
            ModelPrice(
                id: "b", displayName: "b",
                tiers: [
                    Fixture.tier(id: "input", valley: "1", peak: "2"),
                    Fixture.tier(id: "output", valley: "1", peak: "3"),
                ])
        ])
        #expect(mixed.multiple == nil)
        #expect(mixed.valleyPercentLower == nil)
        #expect(mixed.kind == .mixed)

        let equal = PriceComparison(models: [
            ModelPrice(id: "c", displayName: "c", tiers: [Fixture.tier(id: "output", valley: "1", peak: "1")])
        ])
        #expect(equal.multiple == nil)
        #expect(equal.valleyPercentLower == nil)
    }

    @Test("规则校验拒绝周末峰期与重叠假期")
    func validationCatchesBadRules() {
        let weekendWindow = PricingRules(
            schemaVersion: 1,
            version: "bad",
            effectiveFrom: Fixture.date("2026-01-01T00:00:00+08:00"),
            source: Fixture.source,
            timeZone: "Asia/Shanghai",
            weeklyPeakWindows: [PeakWindow(weekday: 6, start: Fixture.minute("09:00"), end: Fixture.minute("12:00"))],
            currency: "CNY",
            unit: "perMillionTokens",
            models: [ModelPrice(id: "m", displayName: "m", tiers: [Fixture.tier()])],
            notes: nil
        )
        #expect(throws: RuleValidationError.self) {
            try RuleValidator.validate(
                RuleSet(
                    pricing: weekendWindow,
                    calendar: Fixture.calendar(),
                    reminderPolicy: Fixture.policy(),
                    bundleVersion: "b",
                    publishedAt: Fixture.date("2026-01-01T00:00:00+08:00"),
                    effectiveFrom: Fixture.date("2026-01-01T00:00:00+08:00")
                )
            )
        }

        let overlapping = [
            Holiday(name: "A", from: Fixture.localDate("2026-10-01"), through: Fixture.localDate("2026-10-05")),
            Holiday(name: "B", from: Fixture.localDate("2026-10-04"), through: Fixture.localDate("2026-10-08")),
        ]
        let rules = Fixture.rules(calendar: Fixture.calendar(holidays: overlapping))
        #expect(throws: RuleValidationError.self) {
            try RuleValidator.validate(rules)
        }
    }
}
