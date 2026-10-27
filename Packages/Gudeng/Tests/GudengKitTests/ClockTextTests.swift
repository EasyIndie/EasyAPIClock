import Foundation
import Testing
@testable import GudengCore
@testable import GudengKit

@Suite("界面文案与倒计时")
struct ClockTextTests {
    @Test("预览说明与所选提醒强度及次数一致")
    func previewExplanationMatchesIntensity() {
        #expect(
            ClockText.previewExplanation(for: .off)
                == "请先开启提醒，再预览通知。")
        #expect(
            ClockText.previewExplanation(for: .medium)
                == "测试 1 次，10 秒结束；关闭面板即停止。")
        #expect(
            ClockText.previewExplanation(for: .strong)
                == "测试最多 3 次，10 秒结束；关闭面板即停止。")
    }

    @Test("谷期主面板文案")
    func valleyCopy() {
        let now = KitFixture.date("2026-10-21T12:30:00+08:00")
        let snapshot = KitFixture.snapshot(at: "2026-10-21T12:30:00+08:00")
        #expect(ClockText.stateName(snapshot.state) == "低价")
        #expect(ClockText.priceLine(for: snapshot) == "模型单价较峰期低 50%")
        #expect(ClockText.countdownLabel(for: snapshot) == "距离高峰")
        #expect(ClockText.countdown(for: snapshot, now: now).value == "1小时30分")
        #expect(ClockText.nextTransitionLine(for: snapshot, now: now) == "14:00 切换")
        #expect(ClockText.daySummary(for: snapshot) == "工作日 · 午间")
        #expect(ClockText.menuBarTitle(for: snapshot, now: now) == "谷 · 1小时30分")
    }

    @Test("峰期主面板文案")
    func peakCopy() {
        let now = KitFixture.date("2026-10-21T10:00:00+08:00")
        let snapshot = KitFixture.snapshot(at: "2026-10-21T10:00:00+08:00")
        #expect(ClockText.stateName(snapshot.state) == "高峰")
        #expect(ClockText.priceLine(for: snapshot) == "模型单价为谷期的 2 倍")
        #expect(ClockText.countdownLabel(for: snapshot) == "距离低价")
        #expect(ClockText.countdown(for: snapshot, now: now).value == "2小时")
        #expect(ClockText.menuBarTitle(for: snapshot, now: now) == "峰 · 2小时")
        #expect(ClockText.daySummary(for: snapshot) == "工作日 · 上午高峰")
    }

    @Test("跨日倒计时使用天与小时")
    func extendedCountdown() {
        let now = KitFixture.date("2026-10-23T19:00:00+08:00")
        let snapshot = KitFixture.snapshot(at: "2026-10-23T19:00:00+08:00")
        let countdown = ClockText.countdown(for: snapshot, now: now)
        #expect(countdown.isExtended)
        #expect(countdown.value == "2天 14小时")
        #expect(countdown.unitCaption == "距下次切换")
        #expect(ClockText.nextTransitionLine(for: snapshot, now: now) == "周一 09:00 切换")
        #expect(ClockText.menuBarTitle(for: snapshot, now: now) == "谷 · 2天14小时")
    }

    @Test("周末与节假日摘要")
    func daySummaries() {
        #expect(ClockText.daySummary(for: KitFixture.snapshot(at: "2026-10-24T12:00:00+08:00")) == "周末 · 全天低价")
        #expect(ClockText.daySummary(for: KitFixture.snapshot(at: "2026-10-02T12:00:00+08:00")) == "国庆节 · 全天低价")
    }

    @Test("规则过期时的待确认状态")
    func unknownCopy() {
        let now = KitFixture.date("2027-01-05T10:00:00+08:00")
        let snapshot = KitFixture.snapshot(at: "2027-01-05T10:00:00+08:00")
        #expect(snapshot.state == nil)
        #expect(ClockText.stateName(snapshot.state) == "待确认")
        #expect(ClockText.countdown(for: snapshot, now: now).value == "—")
        #expect(ClockText.menuBarTitle(for: snapshot, now: now) == "规则待更新")
        #expect(ClockText.daySummary(for: snapshot) == "日期规则待更新")
        #expect(ClockText.priceLine(for: snapshot).contains("2026年12月31日"))
        #expect(ClockText.nextTransitionLine(for: snapshot, now: now) == "更新规则后恢复价格提醒")
    }

    @Test("剩余时间压缩格式")
    func compactDurations() {
        let now = KitFixture.date("2026-10-21T00:00:00+08:00")
        #expect(ClockText.compactRemaining(until: now.addingTimeInterval(59), now: now) == "即将切换")
        #expect(ClockText.compactRemaining(until: now.addingTimeInterval(90), now: now) == "2分")
        #expect(ClockText.compactRemaining(until: now.addingTimeInterval(20 * 60), now: now) == "20分")
        #expect(ClockText.compactRemaining(until: now.addingTimeInterval(2 * 3600), now: now) == "2小时")
        #expect(ClockText.compactRemaining(until: now.addingTimeInterval(3600 + 59 * 60), now: now) == "1小时59分")
        #expect(ClockText.compactRemaining(until: now.addingTimeInterval(3600 + 29 * 60), now: now) == "1小时29分")
        #expect(ClockText.compactRemaining(until: now.addingTimeInterval(26 * 3600), now: now) == "1天2小时")
    }

    @Test("新面板使用明确状态与跨日日期")
    func redesignedPanelCopy() {
        let now = KitFixture.date("2026-10-23T19:00:00+08:00")
        let snapshot = KitFixture.snapshot(at: "2026-10-23T19:00:00+08:00")
        #expect(ClockText.panelStateName(snapshot.state) == "谷期")
        #expect(ClockText.panelCountdownLabel(for: snapshot) == "后进入峰期")
        #expect(ClockText.panelTransitionLine(for: snapshot, now: now) == "2026-10-26 09:00 进入峰期")
        let unknown = KitFixture.snapshot(at: "2027-01-05T10:00:00+08:00")
        #expect(ClockText.panelStateName(unknown.state) == "待确认")
        #expect(ClockText.panelCountdownLabel(for: unknown) == "下次切换待确认")
    }

    @Test("菜单栏与面板使用相同分钟取整")
    func consistentCountdownRounding() {
        let now = KitFixture.date("2026-10-21T06:52:06+08:00")
        let snapshot = KitFixture.snapshot(at: "2026-10-21T06:52:06+08:00")
        #expect(ClockText.countdown(for: snapshot, now: now).value == "2小时8分")
        #expect(ClockText.menuBarTitle(for: snapshot, now: now) == "谷 · 2小时8分")
        let minutesOnly = KitFixture.date("2026-10-21T08:44:01+08:00")
        #expect(
            ClockText.countdown(
                for: KitFixture.snapshot(at: "2026-10-21T08:44:01+08:00"), now: minutesOnly
            ).value == "16分")
        let imminent = KitFixture.date("2026-10-21T08:59:01+08:00")
        let imminentSnapshot = KitFixture.snapshot(at: "2026-10-21T08:59:01+08:00")
        #expect(ClockText.countdown(for: imminentSnapshot, now: imminent).value == "即将切换")
        #expect(ClockText.menuBarTitle(for: imminentSnapshot, now: imminent) == "谷 · 即将切换")
    }

    @Test("主面板朗读与可见倒计时保持一致")
    func panelAccessibilityCopy() {
        let now = KitFixture.date("2026-10-21T06:52:06+08:00")
        let snapshot = KitFixture.snapshot(at: "2026-10-21T06:52:06+08:00")
        #expect(
            ClockText.panelAccessibilityLabel(for: snapshot, now: now)
                == "当前低价时段。模型单价较峰期低 50%。距离下次切换 2小时8分。")
        let imminent = KitFixture.date("2026-10-21T08:59:01+08:00")
        #expect(
            ClockText.panelAccessibilityLabel(
                for: KitFixture.snapshot(at: "2026-10-21T08:59:01+08:00"), now: imminent)
                == "当前低价时段。模型单价较峰期低 50%。即将切换。")
        let expired = KitFixture.date("2027-01-05T10:00:00+08:00")
        let unknown = KitFixture.snapshot(at: "2027-01-05T10:00:00+08:00")
        let label = ClockText.panelAccessibilityLabel(for: unknown, now: expired)
        #expect(label.hasPrefix("价格状态待确认。"))
        #expect(!label.contains("距离下次切换"))
    }

    @Test("自动检查时间明确为北京时间，不把无记录伪装成已检查")
    func automaticAttemptCopy() {
        #expect(ClockText.lastAutomaticAttemptText(nil) == "尚无自动检查记录")
        let date = KitFixture.date("2026-10-26T23:15:00+00:00")
        #expect(ClockText.lastAutomaticAttemptText(date) == "上次尝试：2026-10-27 07:15 · 北京时间")
    }

    @Test("规则检查短结果区分空闲、成功与错误，详细信息留在详情")
    func ruleUpdateSummary() {
        #expect(ClockText.ruleUpdateSummary(for: .idle).isEmpty)
        #expect(ClockText.ruleUpdateSummary(for: .checking).isEmpty)
        #expect(ClockText.ruleUpdateSummary(for: .upToDate("2026.10.23")) == "已是最新")
        #expect(ClockText.ruleUpdateSummary(for: .updated("future")) == "已下载规则")
        #expect(ClockText.ruleUpdateSummary(for: .notConfigured) == "未配置更新源")
        #expect(ClockText.ruleUpdateSummary(for: .failed("long detailed error")) == "检查失败")
    }

    @Test("时长短语")
    func durationPhrases() {
        #expect(ClockText.durationPhrase(7200) == "2 小时")
        #expect(ClockText.durationPhrase(5400) == "1 小时 30 分钟")
        #expect(ClockText.durationPhrase(25 * 3600) == "1 天 1 小时")
        #expect(ClockText.leadPhrase(300) == "5 分钟")
    }
}

@Suite("提醒文案")
struct ReminderCopyTests {
    @Test("进入谷期文案")
    func valleyReminder() throws {
        let reminder = try #require(KitFixture.reminder(at: "2026-10-21T11:59:00+08:00"))
        #expect(ReminderCopy.title(for: reminder) == "进入低价")
        #expect(ReminderCopy.body(for: reminder) == "单价比峰期低 50% · 持续 2 小时")
        // The app name is supplied by the system; medium reminders add no subtitle.
        #expect(ReminderCopy.subtitle(for: reminder) == nil)
    }

    @Test("进入峰期文案")
    func peakReminder() throws {
        let reminder = try #require(KitFixture.reminder(at: "2026-10-21T08:59:00+08:00"))
        #expect(ReminderCopy.title(for: reminder) == "进入高峰")
        #expect(ReminderCopy.body(for: reminder) == "单价为谷期 2 倍 · 持续 3 小时")
    }

    @Test("提前提醒文案")
    func advanceReminder() throws {
        let reminder = try #require(KitFixture.reminder(at: "2026-10-21T08:54:00+08:00", early: true))
        #expect(reminder.kind == .advance(leadSeconds: 300))
        #expect(ReminderCopy.title(for: reminder) == "5 分钟后进入高峰")
        #expect(ReminderCopy.body(for: reminder) == "单价将升为谷期 2 倍 · 持续 3 小时")
    }

    @Test("强提醒副标题与重复次数")
    func strongReminder() throws {
        let reminder = try #require(KitFixture.reminder(at: "2026-10-21T08:59:00+08:00", intensity: .strong))
        #expect(ReminderCopy.subtitle(for: reminder) == "持续提醒 · 可停止")
        #expect(reminder.repeatDates.count == 10)
    }

    @Test("通知文案短到可一眼读完")
    func reminderCopyStaysShort() throws {
        for time in ["2026-10-21T08:59:00+08:00", "2026-10-21T11:59:00+08:00"] {
            for intensity in [ReminderIntensity.medium, .strong] {
                let reminder = try #require(KitFixture.reminder(at: time, intensity: intensity))
                #expect(ReminderCopy.title(for: reminder).count <= 8)
                #expect(ReminderCopy.body(for: reminder).count <= 20)
            }
            let advance = try #require(KitFixture.reminder(at: time, early: true))
            #expect(ReminderCopy.title(for: advance).count <= 12)
            #expect(ReminderCopy.body(for: advance).count <= 22)
        }
    }
}
