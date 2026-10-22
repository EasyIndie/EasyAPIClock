import Foundation
import LiangWenCore

/// Chinese-first presentation helpers for the status bar and the small panel.
///
/// These functions are deliberately free of SwiftUI so they can be unit tested.
/// All times are rendered in Beijing time, matching the pricing rules.
public enum ClockText {
    public struct CountdownDisplay: Sendable, Equatable {
        public let value: String
        public let unitCaption: String?
        public let isExtended: Bool

        public init(value: String, unitCaption: String?, isExtended: Bool) {
            self.value = value
            self.unitCaption = unitCaption
            self.isExtended = isExtended
        }
    }

    public static func stateName(_ state: PriceState?) -> String {
        switch state {
        case .peak: "梁文峰"
        case .valley: "梁文谷"
        case nil: "待确认"
        }
    }

    public static func shortStateName(_ state: PriceState?) -> String {
        switch state {
        case .peak: "峰"
        case .valley: "谷"
        case nil: "?"
        }
    }

    public static func priceLine(for snapshot: PriceSnapshot) -> String {
        switch snapshot.state {
        case .peak:
            if let multiple = snapshot.comparison.multiple {
                return "模型单价为谷期的 \(decimalText(multiple)) 倍"
            }
            return "当前为高峰价格"
        case .valley:
            if let percent = snapshot.comparison.valleyPercentLower {
                return "模型单价较峰期低 \(decimalText(percent))%"
            }
            return "当前为空闲价格"
        case nil:
            if let issue = snapshot.issue {
                return issueText(issue)
            }
            return "价格规则待更新"
        }
    }

    public static func countdownLabel(for snapshot: PriceSnapshot) -> String {
        guard snapshot.state != nil else { return "切换时间" }
        guard snapshot.nextChangeAt != nil else { return "下次切换" }
        switch snapshot.state {
        case .peak: return "距离低价"
        case .valley: return "距离高峰"
        case nil: return "下次切换"
        }
    }

    public static func countdown(for snapshot: PriceSnapshot, now: Date) -> CountdownDisplay {
        guard let next = snapshot.nextChangeAt else {
            return CountdownDisplay(value: "—", unitCaption: nil, isExtended: false)
        }
        let seconds = max(0, next.timeIntervalSince(now))
        let totalMinutes = max(0, Int((seconds / 60).rounded(.up)))
        if totalMinutes < 1440 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return CountdownDisplay(
                value: String(format: "%02d:%02d", hours, minutes),
                unitCaption: "小时 : 分钟",
                isExtended: false
            )
        }
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        let value = hours == 0 ? "\(days)天" : "\(days)天 \(hours)小时"
        return CountdownDisplay(value: value, unitCaption: "距下次切换", isExtended: true)
    }

    public static func nextTransitionLine(for snapshot: PriceSnapshot, now: Date) -> String {
        guard let next = snapshot.nextChangeAt else {
            if snapshot.state == nil {
                return "更新规则后恢复价格提醒"
            }
            return "更新日期规则后确认下次切换"
        }
        return "\(relativeDayPrefix(for: next, now: now))\(clockText(next)) 切换"
    }

    public static func daySummary(for snapshot: PriceSnapshot) -> String {
        switch snapshot.dayKind {
        case .weekend:
            return "周末 · 全天低价"
        case .holiday(let name):
            return "\(name) · 全天低价"
        case .weekday:
            guard let period = snapshot.weekdayPeriod else { return "工作日" }
            return "工作日 · \(periodName(period))"
        case nil:
            return "日期规则待更新"
        }
    }

    public static func menuBarTitle(for snapshot: PriceSnapshot, now: Date) -> String {
        guard snapshot.state != nil else { return "规则待更新" }
        let name = shortStateName(snapshot.state)
        guard let next = snapshot.nextChangeAt else { return "\(name) · 待确认" }
        return "\(name) · \(compactRemaining(until: next, now: now))"
    }

    public static func compactRemaining(until date: Date, now: Date) -> String {
        let seconds = max(0, date.timeIntervalSince(now))
        let totalMinutes = max(1, Int(seconds / 60))
        if totalMinutes < 60 {
            return "\(totalMinutes)分"
        }
        if totalMinutes < 1440 {
            let hours = max(1, Int((Double(totalMinutes) / 60).rounded()))
            return "\(hours)小时"
        }
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        return hours == 0 ? "\(days)天" : "\(days)天\(hours)小时"
    }

    public static func durationPhrase(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded()))
        if minutes < 60 {
            return "\(minutes) 分钟"
        }
        let hours = minutes / 60
        let restMinutes = minutes % 60
        if hours < 24 {
            return restMinutes == 0 ? "\(hours) 小时" : "\(hours) 小时 \(restMinutes) 分钟"
        }
        let days = hours / 24
        let restHours = hours % 24
        return restHours == 0 ? "\(days) 天" : "\(days) 天 \(restHours) 小时"
    }

    public static func leadPhrase(_ seconds: Int) -> String {
        durationPhrase(TimeInterval(seconds))
    }

    public static func intensityName(_ intensity: ReminderIntensity) -> String {
        switch intensity {
        case .off: "关闭"
        case .medium: "中等"
        case .strong: "强"
        }
    }

    public static func intensitySummary(_ intensity: ReminderIntensity) -> String {
        switch intensity {
        case .off: "提醒已关闭"
        case .medium: "中等提醒"
        case .strong: "强提醒"
        }
    }

    public static func issueText(_ issue: RuleIssue) -> String {
        switch issue {
        case .calendarExpired(let through):
            return "日期数据仅覆盖至 \(through.year)年\(through.month)月\(through.day)日"
        case .dateUnverified(let date):
            return "\(date.month)月\(date.day)日 的日期规则待确认"
        case .nextChangeUnconfirmed:
            return "下次切换待确认"
        }
    }

    public static func coverageText(_ range: LocalDateRange) -> String {
        "\(range.from) 至 \(range.through)"
    }

    public static func checkedAtText(_ date: Date) -> String {
        let calendar = RuleTime.makeCalendar()
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return
            "\(components.year ?? 0)-\(String(format: "%02d", components.month ?? 0))-\(String(format: "%02d", components.day ?? 0))"
    }

    public static func clockText(_ date: Date) -> String {
        let calendar = RuleTime.makeCalendar()
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    // MARK: - Helpers

    private static func relativeDayPrefix(for date: Date, now: Date) -> String {
        let calendar = RuleTime.makeCalendar()
        let start = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: date)
        let distance = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        if distance <= 0 { return "" }
        if distance == 1 { return "明天 " }
        if distance < 7 { return "\(weekdayName(date)) " }
        let targetComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let nowComponents = calendar.dateComponents([.year], from: now)
        let month = targetComponents.month ?? 0
        let day = targetComponents.day ?? 0
        if targetComponents.year == nowComponents.year {
            return "\(month)月\(day)日 "
        }
        return "\(targetComponents.year ?? 0)年\(month)月\(day)日 "
    }

    private static func weekdayName(_ date: Date) -> String {
        let calendar = RuleTime.makeCalendar()
        let component = calendar.component(.weekday, from: date)
        let iso = ((component + 5) % 7) + 1
        let names = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return names[max(0, min(6, iso - 1))]
    }

    private static func periodName(_ period: WeekdayPeriod) -> String {
        switch period {
        case .early: "早间"
        case .morningPeak: "上午高峰"
        case .midday: "午间"
        case .afternoonPeak: "下午高峰"
        case .evening: "晚间"
        }
    }

    private static func decimalText(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
