import Foundation

/// Human-readable, aggregated validation failures.
public struct RuleValidationError: Error, Sendable, Equatable, CustomStringConvertible {
    public let issues: [String]

    public init(_ issues: [String]) {
        self.issues = issues
    }

    public var description: String {
        issues.map { "• \($0)" }.joined(separator: "\n")
    }
}

public enum RuleValidator {
    public static let supportedSchemaVersion = 1
    public static let supportedTimeZone = RuleTime.beijingTimeZoneIdentifier
    public static let maximumHolidayLengthInDays = 62
    private static let minimumCoverageDate = LocalDate(year: 2000, month: 1, day: 1)!

    public static func validate(_ rules: RuleSet) throws {
        var issues = validate(pricing: rules.pricing)
        issues += validate(calendar: rules.calendar, pricing: rules.pricing)
        issues += validate(policy: rules.reminderPolicy)
        if rules.bundleVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("bundleVersion 不能为空。")
        }
        guard issues.isEmpty else { throw RuleValidationError(issues) }
    }

    public static func validate(pricing: PricingRules) -> [String] {
        var issues: [String] = []
        if pricing.schemaVersion != supportedSchemaVersion {
            issues.append("价格规则 schemaVersion=\(pricing.schemaVersion)，仅支持 \(supportedSchemaVersion)。")
        }
        if pricing.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("价格规则 version 不能为空。")
        }
        if pricing.timeZone != supportedTimeZone {
            issues.append("价格规则 timeZone 必须为 \(supportedTimeZone)，实际为 \(pricing.timeZone)。")
        }
        if pricing.currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("价格规则 currency 不能为空。")
        }
        if pricing.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("价格规则 unit 不能为空。")
        }
        if pricing.source.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("价格规则 source.name 不能为空。")
        }
        if pricing.weeklyPeakWindows.isEmpty {
            issues.append("价格规则至少需要一个高峰时段。")
        }
        if pricing.models.isEmpty {
            issues.append("价格规则至少需要一个模型。")
        }

        let windowsByWeekday = Dictionary(grouping: pricing.weeklyPeakWindows, by: \.weekday)
        for (weekday, windows) in windowsByWeekday {
            if !(1...5).contains(weekday) {
                issues.append("高峰时段 weekday=\(weekday) 无效；周末固定为空闲时段，只允许 1...5。")
                continue
            }
            let sorted = windows.sorted { $0.start < $1.start }
            for (index, window) in sorted.enumerated() {
                if window.start.minutes >= window.end.minutes {
                    issues.append("周\(weekday) 高峰时段 \(window.start)–\(window.end) 必须 start < end。")
                }
                if window.start.minutes > 1439 {
                    issues.append("周\(weekday) 高峰时段开始时间不能是 24:00。")
                }
                if index > 0 {
                    let previous = sorted[index - 1]
                    if window.start < previous.end {
                        issues.append(
                            "周\(weekday) 高峰时段 \(previous.start)–\(previous.end) 与 \(window.start)–\(window.end) 重叠。")
                    }
                }
            }
        }

        var modelIDs = Set<String>()
        for model in pricing.models {
            if model.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("模型 id 不能为空。")
            } else if !modelIDs.insert(model.id).inserted {
                issues.append("模型 id 重复：\(model.id)。")
            }
            if model.tiers.isEmpty {
                issues.append("模型 \(model.id) 至少需要一个计费项。")
            }
            var tierIDs = Set<String>()
            for tier in model.tiers {
                if tier.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append("模型 \(model.id) 存在空的计费项 id。")
                } else if !tierIDs.insert(tier.id).inserted {
                    issues.append("模型 \(model.id) 计费项 id 重复：\(tier.id)。")
                }
                if tier.valley.value < 0 || tier.peak.value < 0 {
                    issues.append("模型 \(model.id) 计费项 \(tier.id) 的单价不能为负。")
                }
            }
        }

        let hasUsablePrice = pricing.models
            .flatMap(\.tiers)
            .contains { $0.valley.value > 0 }
        if !hasUsablePrice {
            issues.append("至少需要一个谷期单价大于 0 的计费项，才能计算价格差异。")
        }
        return issues
    }

    public static func validate(calendar: CalendarRules, pricing: PricingRules) -> [String] {
        var issues: [String] = []
        if calendar.schemaVersion != supportedSchemaVersion {
            issues.append("日期规则 schemaVersion=\(calendar.schemaVersion)，仅支持 \(supportedSchemaVersion)。")
        }
        if calendar.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("日期规则 version 不能为空。")
        }
        if calendar.timeZone != supportedTimeZone {
            issues.append("日期规则 timeZone 必须为 \(supportedTimeZone)，实际为 \(calendar.timeZone)。")
        }
        if calendar.timeZone != pricing.timeZone {
            issues.append("价格规则与日期规则的 timeZone 不一致。")
        }
        if calendar.source.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("日期规则 source.name 不能为空。")
        }
        if !calendar.coverage.isValid {
            issues.append("日期覆盖范围无效：\(calendar.coverage.from) 晚于 \(calendar.coverage.through)。")
        }
        if calendar.coverage.from < minimumCoverageDate {
            issues.append("日期覆盖范围起点早于 2000-01-01，疑似配置错误。")
        }

        let sortedHolidays = calendar.holidays.sorted { $0.from < $1.from }
        for holiday in sortedHolidays {
            if holiday.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("节假日名称不能为空（\(holiday.from)–\(holiday.through)）。")
            }
            if holiday.from > holiday.through {
                issues.append("节假日 \(holiday.name) 的起止日期颠倒。")
            }
            if !calendar.coverage.contains(holiday.from) || !calendar.coverage.contains(holiday.through) {
                issues.append("节假日 \(holiday.name)（\(holiday.from)–\(holiday.through)）超出日期覆盖范围。")
            }
            if let from = holiday.from.startDate(in: RuleTime.makeCalendar()),
                let through = holiday.through.startDate(in: RuleTime.makeCalendar()),
                let days = RuleTime.makeCalendar().dateComponents([.day], from: from, to: through).day,
                days > maximumHolidayLengthInDays
            {
                issues.append("节假日 \(holiday.name) 长度 \(days) 天，超过上限 \(maximumHolidayLengthInDays) 天。")
            }
        }
        for (index, holiday) in sortedHolidays.enumerated() where index > 0 {
            let previous = sortedHolidays[index - 1]
            if holiday.from <= previous.through {
                issues.append("节假日 \(previous.name) 与 \(holiday.name) 的日期范围重叠。")
            }
        }

        var workdays = Set<LocalDate>()
        for date in calendar.makeupWorkdays {
            if !workdays.insert(date).inserted {
                issues.append("调休上班日重复：\(date)。")
            }
            if !calendar.coverage.contains(date) {
                issues.append("调休上班日 \(date) 超出日期覆盖范围。")
            }
        }
        return issues
    }

    public static func validate(policy: ReminderPolicy) -> [String] {
        var issues: [String] = []
        if policy.schemaVersion != supportedSchemaVersion {
            issues.append("提醒策略 schemaVersion=\(policy.schemaVersion)，仅支持 \(supportedSchemaVersion)。")
        }
        if policy.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("提醒策略 version 不能为空。")
        }
        if policy.advanceOptionsSeconds.isEmpty {
            issues.append("提醒策略至少需要一个提前提醒偏移量。")
        }
        if policy.advanceOptionsSeconds != policy.advanceOptionsSeconds.sorted() {
            issues.append("提前提醒偏移量必须按升序排列。")
        }
        if Set(policy.advanceOptionsSeconds).count != policy.advanceOptionsSeconds.count {
            issues.append("提前提醒偏移量不能重复。")
        }
        for seconds in policy.advanceOptionsSeconds {
            if !(60...7200).contains(seconds) {
                issues.append("提前提醒偏移量 \(seconds) 秒超出 60...7200 秒。")
            }
        }
        if !(10...600).contains(policy.strongRepeatIntervalSeconds) {
            issues.append("强提醒重复间隔必须在 10...600 秒之间。")
        }
        if !(1...60).contains(policy.strongMaxRepeats) {
            issues.append("强提醒重复次数必须在 1...60 之间。")
        }
        let totalStrongSeconds = policy.strongRepeatIntervalSeconds * policy.strongMaxRepeats
        if totalStrongSeconds > 1800 {
            issues.append("强提醒最长持续超过 30 分钟，请缩短重复次数或间隔。")
        }
        return issues
    }
}
