import Foundation
import Testing
@testable import LiangWenCore
@testable import LiangWenKit

@Suite("界面文案与倒计时")
struct ClockTextTests {
    @Test("谷期主面板文案")
    func valleyCopy() {
        let now = KitFixture.date("2026-10-21T12:30:00+08:00")
        let snapshot = KitFixture.snapshot(at: "2026-10-21T12:30:00+08:00")
        #expect(ClockText.stateName(snapshot.state) == "梁文谷")
        #expect(ClockText.priceLine(for: snapshot) == "模型单价较峰期低 50%")
        #expect(ClockText.countdownLabel(for: snapshot) == "距离高峰")
        #expect(ClockText.countdown(for: snapshot, now: now).value == "01:30")
        #expect(ClockText.nextTransitionLine(for: snapshot, now: now) == "14:00 切换")
        #expect(ClockText.daySummary(for: snapshot) == "工作日 · 午间")
        #expect(ClockText.menuBarTitle(for: snapshot, now: now) == "谷 · 2小时")
    }

    @Test("峰期主面板文案")
    func peakCopy() {
        let now = KitFixture.date("2026-10-21T10:00:00+08:00")
        let snapshot = KitFixture.snapshot(at: "2026-10-21T10:00:00+08:00")
        #expect(ClockText.stateName(snapshot.state) == "梁文峰")
        #expect(ClockText.priceLine(for: snapshot) == "模型单价为谷期的 2 倍")
        #expect(ClockText.countdownLabel(for: snapshot) == "距离低价")
        #expect(ClockText.countdown(for: snapshot, now: now).value == "02:00")
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
        #expect(ClockText.compactRemaining(until: now.addingTimeInterval(90), now: now) == "1分")
        #expect(ClockText.compactRemaining(until: now.addingTimeInterval(20 * 60), now: now) == "20分")
        #expect(ClockText.compactRemaining(until: now.addingTimeInterval(2 * 3600), now: now) == "2小时")
        #expect(ClockText.compactRemaining(until: now.addingTimeInterval(3600 + 59 * 60), now: now) == "2小时")
        #expect(ClockText.compactRemaining(until: now.addingTimeInterval(3600 + 29 * 60), now: now) == "1小时")
        #expect(ClockText.compactRemaining(until: now.addingTimeInterval(26 * 3600), now: now) == "1天2小时")
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
        #expect(ReminderCopy.title(for: reminder) == "低价时段开始")
        #expect(ReminderCopy.body(for: reminder) == "模型单价较峰期低 50%。本次低价持续 2 小时。")
        #expect(ReminderCopy.subtitle(for: reminder) == "梁文钟 · 中等提醒 · 短音一次")
    }

    @Test("进入峰期文案")
    func peakReminder() throws {
        let reminder = try #require(KitFixture.reminder(at: "2026-10-21T08:59:00+08:00"))
        #expect(ReminderCopy.title(for: reminder) == "高峰时段开始")
        #expect(ReminderCopy.body(for: reminder) == "模型单价为谷期的 2 倍。距离下次低价还有 3 小时。")
    }

    @Test("提前提醒文案")
    func advanceReminder() throws {
        let reminder = try #require(KitFixture.reminder(at: "2026-10-21T08:54:00+08:00", early: true))
        #expect(reminder.kind == .advance(leadSeconds: 300))
        #expect(ReminderCopy.title(for: reminder) == "还有 5 分钟进入高峰")
        #expect(ReminderCopy.body(for: reminder) == "模型单价即将上升。本次高峰持续 3 小时。")
    }

    @Test("强提醒副标题与重复次数")
    func strongReminder() throws {
        let reminder = try #require(KitFixture.reminder(at: "2026-10-21T08:59:00+08:00", intensity: .strong))
        #expect(ReminderCopy.subtitle(for: reminder) == "梁文钟 · 强提醒 · 持续至关闭")
        #expect(reminder.repeatDates.count == 10)
    }
}
