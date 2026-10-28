import GudengRuntime
import Foundation
import GudengCore

/// Chinese-first presentation helpers for the status bar and the small panel.
///
/// These functions are deliberately free of SwiftUI so they can be unit tested.
/// All times are rendered in Beijing time, matching the pricing rules.
public enum ClockText {
    public static let brandTitle = "DeepSeek API"
    public static let brandCaption = "峰谷价格提醒 · 北京时间"
    public static let communityNotice = "社区工具，与 DeepSeek 官方无隶属关系"
    public static let versionsLabel = "价格 / 日历"
    public static let coverageLabel = "覆盖日期"
    public static let originLabel = "规则来源"
    public static let priceCheckLabel = "价格核对"
    public static let calendarCheckLabel = "日期核对"
    public static let reminderIntensityTitle = "提醒强度"
    public static let notificationDisabledTitle = "系统通知未开启"
    public static let notificationSettingsTitle = "打开系统设置"
    public static let ruleUpdateTitle = "检查规则更新"
    public static let ruleCheckingTitle = "正在检查…"
    public static let ruleUpdateHint = "从规则源检查并安装新版本"
    public static let ruleResultHint = "查看完整规则检查结果"
    public static let groupExpanded = "已展开"
    public static let groupCollapsed = "已折叠"
    public static let groupToggleHint = "点击整行展开或折叠"
    public static func ruleUpdateSummary(for state: UpdateState) -> String {
        switch state {
        case .idle, .checking: ""
        case .notConfigured: "未配置更新源"
        case .upToDate: "已是最新"
        case .updated: "已下载规则"
        case .failed: "检查失败"
        }
    }

    public static let quitTitle = "退出谷蹬"
    public static let quitHint = "退出应用后不再重新排定提醒"
    public static func appVersionLabel(_ version: AppVersion) -> String {
        "谷蹬 \(version.shortVersion) (\(version.build))"
    }

    public static func appVersionAccessibilityLabel(_ version: AppVersion) -> String {
        "应用版本 \(version.shortVersion)，构建号 \(version.build)"
    }

    public static let rulesTitle = "规则信息"
    public static let officialRulesTitle = "DeepSeek 官方价格 · 北京时间"
    public static let priceSourceTitle = "价格来源"
    public static let calendarSourceTitle = "日期来源"
    public static let invalidDownloadedRules = "已下载规则无效，继续使用内置规则。"
    public static func ruleVersions(_ status: RuleStatus) -> String {
        "价格规则 \(status.pricingVersion) · 日期数据 \(status.calendarVersion)"
    }
    public static func ruleCoverage(_ status: RuleStatus) -> String {
        "覆盖 \(coverageText(status.coverage))"
    }
    public static func priceVerification(_ status: RuleStatus) -> String {
        "\(status.originText) · 价格核对于 \(checkedAtText(status.checkedAt))"
    }
    public static func calendarVerification(_ status: RuleStatus) -> String {
        "日期核对于 \(checkedAtText(status.calendarCheckedAt))"
    }
    public static func pendingRules(_ version: String) -> String {
        "已下载规则包 \(version)，将在生效时间自动启用。"
    }
    public static var previewSummary: String {
        let plan = ReminderPreviewPlan(intensity: .strong)
        return "测试提醒 · 最多 \(plan.offsets.count) 次 · \(Int(plan.duration)) 秒结束"
    }

    public static let previewTitle = "预览提醒"
    public static let previewStop = "立即停止预览"
    public static func previewExplanation(for intensity: ReminderIntensity) -> String {
        let plan = ReminderPreviewPlan(intensity: intensity)
        switch intensity {
        case .off:
            return "请先开启提醒，再预览通知。"
        case .medium:
            return "测试 1 次，\(Int(plan.duration)) 秒结束；关闭面板即停止。"
        case .strong:
            return "测试最多 \(plan.offsets.count) 次，\(Int(plan.duration)) 秒结束；关闭面板即停止。"
        }
    }
    public static let previewNotificationTitle = "谷蹬 · 测试提醒"
    public static let previewNotificationBody = "这是提醒预览，不表示价格已切换。"
    public static let previewPermissionRequired = "通知未获授权，未发送预览。请在系统设置中开启通知。"
    public static let previewFinished = "预览已结束。"
    public static let previewFailed = "预览失败："
    public static let loginTitle = "登录时启动"
    public static let loginApproval = "需在系统登录项设置中允许谷蹬。"
    public static let loginUnavailable = "当前应用无法注册登录启动，请检查安装位置。"
    public static let loginFailure = "登录项设置失败："
    public static let loginSettings = "打开登录项设置"
    public static let automaticUpdatesTitle = "自动更新规则"
    public static var automaticUpdatesExplanation: String {
        "开启后自动检查规则，每 \(Int(AutomaticUpdateSchedule.interval / 3600)) 小时最多一次；失败保留本地有效规则。"
    }

    public static func lastAutomaticAttemptText(_ date: Date?) -> String {
        guard let date else { return "尚无自动检查记录" }
        return "上次尝试：\(checkedAtText(date)) \(clockText(date)) · 北京时间"
    }

    public static let settingsTitle = "设置"
    public static let backTitle = "返回主面板"
    public static let remindersTitle = "提醒"
    public static let appearanceTitle = "外观"
    public static let generalTitle = "通用"
    public static let displayModeTitle = "显示模式"
    public static let systemAppearance = "系统"
    public static let lightAppearance = "浅色"
    public static let darkAppearance = "深色"
    public static let animationsTitle = "界面动效"
    public static let animationsExplanation = "控制入场、数字变化、页面切换与折叠反馈；系统减少动态效果优先。"
    public static let reminderExplanation = "中等：通知与短音一次；强：有界重复，可停止。"

    public static func panelStateName(_ state: PriceState?) -> String {
        switch state {
        case .peak: "峰期"
        case .valley: "谷期"
        case nil: "待确认"
        }
    }

    public static func panelCountdownLabel(for snapshot: PriceSnapshot) -> String {
        guard snapshot.nextChangeAt != nil else { return "下次切换待确认" }
        let label = snapshot.nextChangeState == .peak ? "后进入峰期" : "后进入谷期"
        return label
    }

    public static func panelTransitionLine(for snapshot: PriceSnapshot, now: Date) -> String {
        guard let next = snapshot.nextChangeAt else {
            return nextTransitionLine(for: snapshot, now: now)
        }
        let calendar = RuleTime.makeCalendar()
        let prefix = calendar.isDate(next, inSameDayAs: now) ? "" : "\(checkedAtText(next)) "
        return "\(prefix)\(clockText(next)) 进入\(panelStateName(snapshot.nextChangeState))"
    }

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
        case .peak: "高峰"
        case .valley: "低价"
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
        guard seconds >= 60 else {
            return CountdownDisplay(value: "即将切换", unitCaption: nil, isExtended: true)
        }
        let totalMinutes = Int((seconds / 60).rounded(.up))
        if totalMinutes < 1440 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return CountdownDisplay(
                value: hours == 0 ? "\(minutes)分" : (minutes == 0 ? "\(hours)小时" : "\(hours)小时\(minutes)分"),
                unitCaption: "剩余时长",
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
        guard seconds >= 60 else { return "即将切换" }
        let totalMinutes = Int((seconds / 60).rounded(.up))
        if totalMinutes < 60 {
            return "\(totalMinutes)分"
        }
        if totalMinutes < 1440 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes == 0 ? "\(hours)小时" : "\(hours)小时\(minutes)分"
        }
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        return hours == 0 ? "\(days)天" : "\(days)天\(hours)小时"
    }

    public static func panelAccessibilityLabel(for snapshot: PriceSnapshot, now: Date) -> String {
        guard let state = snapshot.state else {
            return "价格状态待确认。\(issueText(snapshot.issue ?? .nextChangeUnconfirmed))"
        }
        let description = "当前\(stateName(state))时段。\(priceLine(for: snapshot))。"
        guard let next = snapshot.nextChangeAt else {
            return description + "下次切换待确认。"
        }
        let remaining = compactRemaining(until: next, now: now)
        return description + (remaining == "即将切换" ? "即将切换。" : "距离下次切换 \(remaining)。")
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
