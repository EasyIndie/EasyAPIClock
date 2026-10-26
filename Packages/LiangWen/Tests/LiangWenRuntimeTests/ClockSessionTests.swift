import Foundation
import Testing
import LiangWenCore
import LiangWenRuntime

@Suite("无界面共享业务会话")
@MainActor
struct ClockSessionTests {
    @Test("多界面订阅不触发副作用，移除一个不影响另一个及提醒去重")
    func sharedObservers() async throws {
        let fixture = try SessionFixture()
        defer { fixture.cleanup() }
        let session = fixture.session
        var first: [ClockSessionState] = []
        var second: [ClockSessionState] = []
        let firstID = session.observe { first.append($0) }
        let secondID = session.observe { second.append($0) }
        #expect(first == [session.state])
        #expect(second == first)
        #expect(fixture.scheduler.replacements == 0)
        #expect(fixture.scheduler.authorizationQueries == 0)

        await session.refresh(now: fixture.now)
        #expect(fixture.scheduler.replacements == 1)
        #expect(first.last?.snapshot == second.last?.snapshot)
        #expect(first.last?.snapshot == ClockEngine(rules: session.rules).snapshot(at: fixture.now))
        let firstCount = first.count
        session.removeObserver(firstID)
        session.setAutomaticUpdatesEnabled(false)
        #expect(first.count == firstCount)
        #expect(second.last?.automaticUpdatesEnabled == false)
        await session.refresh(now: fixture.now.addingTimeInterval(60))
        #expect(fixture.scheduler.replacements == 1)
        #expect(second.last?.now == fixture.now.addingTimeInterval(60))
        #expect(first.count == firstCount)
        session.removeObserver(secondID)
    }

    @Test("无界面预览返回类型化拒绝结果，未配置更新源也可独立使用")
    func headlessFailures() async throws {
        let fixture = try SessionFixture()
        defer { fixture.cleanup() }
        fixture.scheduler.authorization = .denied
        let session = fixture.session
        var states: [ClockSessionState] = []
        let id = session.observe { states.append($0) }
        await session.startPreview()?.value
        #expect(session.state.previewOutcome == .permissionRequired)
        #expect(!session.state.isPreviewing)
        #expect(states.contains { $0.isPreviewing })
        #expect(states.last?.previewOutcome == .permissionRequired)
        #expect(fixture.scheduler.previews == 0)
        await session.checkForUpdates(now: fixture.now)
        #expect(states.last?.updateState == .notConfigured)
        #expect(fixture.scheduler.replacements == 0)
        session.removeObserver(id)
    }
}

@MainActor
private struct SessionFixture {
    let root: URL
    let suite: String
    let defaults: UserDefaults
    let now: Date
    let scheduler: SessionScheduler
    let session: ClockSession

    init() throws {
        let suite = "gudeng-session-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let rules = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Rules")
        let formatter = ISO8601DateFormatter()
        let now = try #require(formatter.date(from: "2026-10-26T08:00:00+08:00"))
        let repository = RuleRepository(bundledDirectory: rules, supportDirectory: root)
        let scheduler = SessionScheduler()
        self.root = root
        self.suite = suite
        self.defaults = defaults
        self.now = now
        self.scheduler = scheduler
        self.session = ClockSession(
            active: repository.active(at: now),
            preferences: UserPreferences(intensity: .strong, earlyReminderEnabled: true),
            repository: repository, preferencesStore: SessionPreferences(), scheduler: scheduler,
            updater: nil, settingsDefaults: defaults, initialNow: now)
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }
}

@MainActor
private final class SessionPreferences: PreferencesStoring {
    var saved: UserPreferences?
    func load() -> UserPreferences? { saved }
    func save(_ preferences: UserPreferences) { saved = preferences }
}

@MainActor
private final class SessionScheduler: ReminderScheduling {
    var authorization: ReminderAuthorization = .authorized
    var authorizationQueries = 0
    var replacements = 0
    var previews = 0
    func authorizationStatus() async -> ReminderAuthorization {
        authorizationQueries += 1
        return authorization
    }
    func requestAuthorization() async -> ReminderAuthorization { authorization }
    func replacePlan(_ reminders: [PlannedReminder], policy: ReminderPolicy) async { replacements += 1 }
    func cancelAll() async {}
    func stop(eventID: String) async {}
    func schedulePreview(id: String, intensity: ReminderIntensity, soundEnabled: Bool) async throws { previews += 1 }
    func stopPreview(id: String) {}
    func openSystemSettings() {}
}
