import Foundation

/// Pure, deterministic price-clock engine.
///
/// The engine never reads the network, the system time zone, or user defaults.
/// Every answer is derived from the validated `RuleSet` and the instant passed in.
public struct ClockEngine: Sendable {
    public static let searchHorizonDays = 400

    public let rules: RuleSet
    public let comparison: PriceComparison

    private let calendar: Calendar
    private let holidayNames: [LocalDate: String]
    private let windowsByWeekday: [Int: [PeakWindow]]

    public init(rules: RuleSet) {
        self.rules = rules
        self.calendar = RuleTime.makeCalendar()
        self.comparison = PriceComparison(models: rules.pricing.models)
        self.windowsByWeekday = Dictionary(grouping: rules.pricing.weeklyPeakWindows, by: \.weekday)

        var names: [LocalDate: String] = [:]
        for holiday in rules.calendar.holidays {
            var date = holiday.from
            var steps = 0
            while date <= holiday.through && steps <= RuleValidator.maximumHolidayLengthInDays {
                names[date] = holiday.name
                guard let next = date.adding(days: 1, in: calendar) else { break }
                date = next
                steps += 1
            }
        }
        self.holidayNames = names
    }

    // MARK: - Public queries

    public func dayKind(for date: LocalDate) -> DayKind? {
        if let holiday = holidayNames[date] {
            return .holiday(name: holiday)
        }
        guard let start = date.startDate(in: calendar) else { return nil }
        let weekday = isoWeekday(for: start)
        if weekday >= 6 {
            return .weekend
        }
        if rules.calendar.coverage.contains(date) {
            return .weekday
        }
        return nil
    }

    public func state(at instant: Date) -> PriceState? {
        let date = LocalDate(date: instant, calendar: calendar)
        guard let kind = dayKind(for: date) else { return nil }
        return state(kind: kind, at: instant)
    }

    public func snapshot(at now: Date) -> PriceSnapshot {
        let date = LocalDate(date: now, calendar: calendar)
        guard let kind = dayKind(for: date) else {
            return PriceSnapshot(
                evaluatedAt: now,
                state: nil,
                dayKind: nil,
                weekdayPeriod: nil,
                stateStartedAt: nil,
                nextChangeAt: nil,
                nextChangeState: nil,
                nextChangeWindowEnd: nil,
                comparison: comparison,
                issue: issue(for: date)
            )
        }
        let current = state(kind: kind, at: now)

        var nextChangeAt: Date?
        var nextChangeState: PriceState?
        var nextChangeWindowEnd: Date?
        var ruleIssue: RuleIssue?

        switch firstChange(after: now, current: current) {
        case .found(let transition, let newState):
            nextChangeAt = transition
            nextChangeState = newState
            if case .found(let windowEnd, _) = firstChange(after: transition, current: newState) {
                nextChangeWindowEnd = windowEnd
            }
        case .blocked(let blockedAt):
            if blockedAt < rules.calendar.coverage.from || blockedAt > rules.calendar.coverage.through {
                ruleIssue = issue(for: blockedAt)
            } else {
                ruleIssue = .nextChangeUnconfirmed
            }
        }

        return PriceSnapshot(
            evaluatedAt: now,
            state: current,
            dayKind: kind,
            weekdayPeriod: periodicPeriod(at: now),
            stateStartedAt: previousChange(before: now, current: current),
            nextChangeAt: nextChangeAt,
            nextChangeState: nextChangeState,
            nextChangeWindowEnd: nextChangeWindowEnd,
            comparison: comparison,
            issue: ruleIssue
        )
    }

    // MARK: - State evaluation

    private func state(kind: DayKind, at instant: Date) -> PriceState {
        switch kind {
        case .weekend, .holiday:
            return .valley
        case .weekday:
            let minute = minuteOfDay(for: instant)
            let weekday = isoWeekday(for: instant)
            let isPeak = (windowsByWeekday[weekday] ?? []).contains { $0.contains(minuteOfDay: minute) }
            return isPeak ? .peak : .valley
        }
    }

    private func periodicPeriod(at instant: Date) -> WeekdayPeriod? {
        let date = LocalDate(date: instant, calendar: calendar)
        guard let kind = dayKind(for: date), case .weekday = kind else { return nil }
        let minute = minuteOfDay(for: instant)
        switch minute {
        case ..<540: return .early
        case ..<720: return .morningPeak
        case ..<840: return .midday
        case ..<1080: return .afternoonPeak
        default: return .evening
        }
    }

    private func issue(for date: LocalDate) -> RuleIssue {
        if date > rules.calendar.coverage.through {
            return .calendarExpired(through: rules.calendar.coverage.through)
        }
        return .dateUnverified(date)
    }

    // MARK: - Transition search

    private enum ChangeSearch {
        case found(date: Date, state: PriceState)
        case blocked(LocalDate)
    }

    private func firstChange(after start: Date, current: PriceState) -> ChangeSearch {
        let startDay = calendar.startOfDay(for: start)
        for offset in 0..<Self.searchHorizonDays {
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: startDay) else {
                return .blocked(LocalDate(date: start, calendar: calendar))
            }
            let day = LocalDate(date: dayStart, calendar: calendar)
            guard let kind = dayKind(for: day) else {
                return .blocked(day)
            }
            for boundary in boundaries(dayStart: dayStart, day: day, kind: kind) where boundary > start {
                // Re-derive the day kind at the boundary: a midnight boundary belongs
                // to the next day, which may be a weekend, holiday or unverified date.
                guard let stateAtBoundary = state(at: boundary) else {
                    return .blocked(LocalDate(date: boundary, calendar: calendar))
                }
                if stateAtBoundary != current {
                    return .found(date: boundary, state: stateAtBoundary)
                }
            }
        }
        return .blocked(LocalDate(date: start, calendar: calendar))
    }

    private func previousChange(before end: Date, current: PriceState) -> Date? {
        let endDay = calendar.startOfDay(for: end)
        for offset in 0..<Self.searchHorizonDays {
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: endDay) else {
                return nil
            }
            let day = LocalDate(date: dayStart, calendar: calendar)
            guard let kind = dayKind(for: day) else { return nil }
            let candidates = boundaries(dayStart: dayStart, day: day, kind: kind).filter { $0 <= end }
            for boundary in candidates.reversed() {
                guard let stateAtBoundary = state(at: boundary), stateAtBoundary == current else {
                    continue
                }
                guard let before = calendar.date(byAdding: .second, value: -1, to: boundary),
                    let stateBefore = state(at: before)
                else {
                    return nil
                }
                if stateBefore != current {
                    return boundary
                }
            }
        }
        return nil
    }

    /// Every instant at which the price state could change on a given day.
    private func boundaries(dayStart: Date, day: LocalDate, kind: DayKind) -> [Date] {
        var result: [Date] = []
        if let midnight = calendar.date(byAdding: .day, value: 1, to: dayStart) {
            result.append(midnight)
        }
        if case .weekday = kind {
            guard let weekdayDate = day.startDate(in: calendar) else { return result }
            let weekday = isoWeekday(for: weekdayDate)
            for window in windowsByWeekday[weekday] ?? [] {
                if let start = calendar.date(byAdding: .minute, value: window.start.minutes, to: dayStart) {
                    result.append(start)
                }
                if let end = calendar.date(byAdding: .minute, value: window.end.minutes, to: dayStart) {
                    result.append(end)
                }
            }
        }
        return Array(Set(result)).sorted()
    }

    // MARK: - Calendar helpers

    private func isoWeekday(for instant: Date) -> Int {
        let component = calendar.component(.weekday, from: instant)
        return ((component + 5) % 7) + 1
    }

    private func minuteOfDay(for instant: Date) -> Int {
        calendar.component(.hour, from: instant) * 60 + calendar.component(.minute, from: instant)
    }
}
