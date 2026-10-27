import Combine
import Foundation
import Testing
import GudengCore
import GudengRuntime
@testable import GudengKit

@Suite("macOS13观察适配回归")
@MainActor
struct ObservationCompatibilityTests {
    @Test("会话刷新与设置立即发布给所有界面适配器")
    func publishedSessionState() async throws {
        let fixture = try ObservationFixture()
        defer { fixture.cleanup() }
        let model = fixture.model
        let secondary = ClockModel(session: model.session)
        var first: [ClockSessionState] = []
        var second: [ClockSessionState] = []
        let firstToken = model.$state.sink { first.append($0) }
        let secondToken = secondary.$state.sink { second.append($0) }
        defer { firstToken.cancel(); secondToken.cancel() }
        model.setAutomaticUpdatesEnabled(false)
        #expect(first.last?.automaticUpdatesEnabled == false)
        #expect(second.last == first.last)
        let next = fixture.now.addingTimeInterval(60)
        await model.refresh(now: next)
        #expect(first.last?.now == next)
        #expect(first.last?.snapshot == ClockEngine(rules: model.rules).snapshot(at: next))
        #expect(second.last == first.last)
    }

    @Test("异步预览开始和拒绝结果通过发布者送达")
    func publishedPreviewState() async throws {
        let fixture = try ObservationFixture()
        defer { fixture.cleanup() }
        let model = fixture.model
        var states: [ClockSessionState] = []
        let token = model.$state.sink { states.append($0) }
        defer { token.cancel() }
        await model.startPreview()?.value
        #expect(states.contains { $0.isPreviewing })
        #expect(states.last?.isPreviewing == false)
        #expect(states.last?.previewOutcome == .permissionRequired)
        await model.checkForUpdates(now: fixture.now)
        #expect(states.last?.updateState == .notConfigured)
    }

    @Test("登录子对象独立发布审批变化与错误，不依赖父模型刷新")
    func publishedLoginState() {
        let service = ObservationLoginService()
        let login = LoginItemController(service: service)
        var states: [LoginItemState] = []
        var messages: [String?] = []
        let stateToken = login.$state.sink { states.append($0) }
        let errorToken = login.$errorMessage.sink { messages.append($0) }
        defer { stateToken.cancel(); errorToken.cancel() }
        login.setEnabled(true)
        #expect(states.last == .requiresApproval)
        service.state = .enabled
        login.refresh()
        #expect(states.last == .enabled)
        service.fail = true
        login.setEnabled(false)
        #expect(states.last == .enabled)
        #expect(messages.last.flatMap { $0 } != nil)
        service.fail = false
        login.setEnabled(false)
        #expect(states.last == .disabled)
        #expect(login.errorMessage == nil)
    }
}

@MainActor
private struct ObservationFixture {
    let suite: String
    let defaults: UserDefaults
    let root: URL
    let now: Date
    let model: ClockModel

    init() throws {
        let suite = "gudeng-observation-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let now = KitFixture.date("2026-10-26T08:00:00+08:00")
        let repository = RuleRepository(bundledDirectory: KitTestPaths.rulesDirectory, supportDirectory: root)
        self.suite = suite
        self.defaults = defaults
        self.root = root
        self.now = now
        self.model = ClockModel(
            active: repository.active(at: now),
            preferences: UserPreferences(intensity: .strong, earlyReminderEnabled: true),
            repository: repository, preferencesStore: UserDefaultsPreferences(defaults: defaults),
            scheduler: ObservationScheduler(), updater: nil, settingsDefaults: defaults,
            loginItem: LoginItemController(service: ObservationLoginService()), initialNow: now)
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }
}

@MainActor
private final class ObservationLoginService: LoginItemManaging {
    var state: LoginItemState = .disabled
    var fail = false
    func setEnabled(_ enabled: Bool) throws {
        if fail { throw CocoaError(.fileWriteNoPermission) }
        state = enabled ? .requiresApproval : .disabled
    }
    func openSettings() {}
}

@MainActor
private final class ObservationScheduler: ReminderScheduling {
    func authorizationStatus() async -> ReminderAuthorization { .denied }
    func requestAuthorization() async -> ReminderAuthorization { .denied }
    func replacePlan(_ reminders: [PlannedReminder], policy: ReminderPolicy) async {}
    func cancelAll() async {}
    func stop(eventID: String) async {}
    func schedulePreview(id: String, intensity: ReminderIntensity, soundEnabled: Bool) async throws {}
    func stopPreview(id: String) {}
    func openSystemSettings() {}
}
