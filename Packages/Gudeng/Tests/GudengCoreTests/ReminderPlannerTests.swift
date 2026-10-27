import Foundation
import Testing
@testable import GudengCore

@Suite("提醒计划")
struct ReminderPlannerTests {
    private let engine = Fixture.engine()
    private let policy = Fixture.policy()

    private func snapshot(at iso: String) -> PriceSnapshot {
        engine.snapshot(at: Fixture.date(iso))
    }

    private func plan(
        at iso: String,
        intensity: ReminderIntensity = .medium,
        early: Bool = false
    ) -> [PlannedReminder] {
        let now = Fixture.date(iso)
        let preferences = UserPreferences(intensity: intensity, earlyReminderEnabled: early)
        return ReminderPlanner(now: now, preferences: preferences, policy: policy)
            .plan(for: engine.snapshot(at: now))
    }

    @Test("中等提醒只安排一次切换通知")
    func mediumPlan() throws {
        let reminders = plan(at: "2026-10-21T11:59:00+08:00")
        let reminder = try #require(reminders.first)
        #expect(reminders.count == 1)
        #expect(reminder.kind == .transition)
        #expect(reminder.fireDate == Fixture.date("2026-10-21T12:00:00+08:00"))
        #expect(reminder.transitionDate == reminder.fireDate)
        #expect(reminder.targetState == .valley)
        #expect(reminder.intensity == .medium)
        #expect(reminder.repeatDates.isEmpty)
        #expect(reminder.facts.upcomingWindowDuration == 2 * 3600.0)
        #expect(reminder.id == "t:\(Int(reminder.fireDate.timeIntervalSince1970))")
    }

    @Test("关闭提醒不安排任何通知")
    func offPlan() {
        #expect(plan(at: "2026-10-21T11:59:00+08:00", intensity: .off).isEmpty)
    }

    @Test("提前提醒使用策略偏移量，且不补发已过去的提醒")
    func advancePlan() throws {
        let early = plan(at: "2026-10-21T11:54:00+08:00", early: true)
        #expect(early.count == 2)
        let advance = try #require(early.first)
        #expect(advance.kind == .advance(leadSeconds: 300))
        #expect(advance.fireDate == Fixture.date("2026-10-21T11:55:00+08:00"))
        #expect(advance.facts.leadSeconds == 300)
        #expect(early.last?.kind == .transition)

        let missed = plan(at: "2026-10-21T11:56:00+08:00", early: true)
        #expect(missed.count == 1)
        #expect(missed.first?.kind == .transition)
    }

    @Test("强提醒生成有界重复")
    func strongPlan() throws {
        let reminders = plan(at: "2026-10-21T11:59:00+08:00", intensity: .strong)
        let reminder = try #require(reminders.first)
        #expect(reminder.repeatDates.count == 10)
        #expect(reminder.allFireDates.count == 11)
        #expect(reminder.repeatDates.first == reminder.fireDate.addingTimeInterval(30))
        #expect(reminder.repeatDates.last == reminder.fireDate.addingTimeInterval(300))
    }

    @Test("下次切换未确认时不安排价格提醒")
    func unconfirmedPlan() {
        let coverage = LocalDateRange(
            from: Fixture.localDate("2026-01-01"),
            through: Fixture.localDate("2026-10-23")
        )
        let expiredEngine = Fixture.engine(coverage: coverage)
        let now = Fixture.date("2026-10-23T19:00:00+08:00")
        let snapshot = expiredEngine.snapshot(at: now)
        let reminders = ReminderPlanner(
            now: now,
            preferences: UserPreferences(intensity: .medium),
            policy: policy
        ).plan(for: snapshot)
        #expect(reminders.isEmpty)
    }

    @Test("首次启动默认中等提醒，提前提醒默认关闭")
    func initialPreferences() {
        let preferences = UserPreferences.initial(policy: policy)
        #expect(preferences.intensity == .medium)
        #expect(!preferences.earlyReminderEnabled)
    }

    @Test("提醒签名随强度和内容变化")
    func signatureChanges() {
        let medium = plan(at: "2026-10-21T11:59:00+08:00", intensity: .medium)
        let strong = plan(at: "2026-10-21T11:59:00+08:00", intensity: .strong)
        #expect(medium.first?.signature != strong.first?.signature)

        let before = plan(at: "2026-10-21T11:59:00+08:00")
        let after = plan(at: "2026-10-21T12:30:00+08:00")
        #expect(before.first?.id != after.first?.id)
    }

    @Test("规则更新不会改变本地提醒强度")
    func rulesDoNotOverridePreferences() throws {
        let preferences = UserPreferences(intensity: .off, earlyReminderEnabled: true)
        let updatedPolicy = Fixture.policy(defaultIntensity: .strong, advanceSeconds: [600])
        let encoded = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: encoded)
        #expect(decoded == preferences)
        #expect(updatedPolicy.defaultIntensity == .strong)
        #expect(decoded.intensity == .off)
    }
}
