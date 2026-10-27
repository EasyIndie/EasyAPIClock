@testable import LiangWenRuntime
import Foundation
import Testing
@testable import LiangWenCore
@testable import LiangWenKit

@Suite("设置失败路径与更新隔离")
@MainActor
struct SettingsModelTests {
    private func model(
        root: URL, defaults: UserDefaults, scheduler: TestSettingsScheduler,
        updater: RemoteRuleUpdater? = nil
    ) -> ClockModel {
        let repository = RuleRepository(
            bundledDirectory: KitTestPaths.rulesDirectory,
            supportDirectory: root.appendingPathComponent("Support"))
        let now = KitFixture.date("2026-10-26T08:00:00+08:00")
        return ClockModel(
            active: repository.active(at: now),
            preferences: UserPreferences(intensity: .strong, earlyReminderEnabled: true),
            repository: repository, preferencesStore: UserDefaultsPreferences(defaults: defaults),
            scheduler: scheduler, updater: updater, settingsDefaults: defaults, initialNow: now)
    }

    @Test("自动检查记录失败尝试并跨实例保留，禁用和手动检查不伪造记录")
    func automaticAttemptReceipt() async throws {
        let suite = "gudeng-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { try? FileManager.default.removeItem(at: root) }
        let fetcher = FailingSettingsFetcher()
        let updater = RemoteRuleUpdater(
            baseURL: try #require(URL(string: "https://example.invalid/rules")), fetcher: fetcher)
        let clock = model(root: root, defaults: defaults, scheduler: TestSettingsScheduler(), updater: updater)
        let now = KitFixture.date("2026-10-26T08:00:00+08:00")
        #expect(clock.lastAutomaticAttemptAt == nil)
        clock.setAutomaticUpdatesEnabled(false)
        await clock.checkForAutomaticUpdates(now: now)
        #expect(clock.lastAutomaticAttemptAt == nil)
        #expect(await fetcher.requestCount == 0)
        clock.setAutomaticUpdatesEnabled(true)
        await clock.checkForAutomaticUpdates(now: now)
        #expect(clock.lastAutomaticAttemptAt == now)
        #expect(clock.updateMessage.hasPrefix("检查失败："))
        let restored = model(root: root, defaults: defaults, scheduler: TestSettingsScheduler(), updater: updater)
        #expect(restored.lastAutomaticAttemptAt == now)
        await restored.checkForAutomaticUpdates(now: now.addingTimeInterval(60))
        #expect(await fetcher.requestCount == 1)
        await restored.checkForUpdates(now: now.addingTimeInterval(120))
        #expect(await fetcher.requestCount == 2)
        #expect(restored.lastAutomaticAttemptAt == now)
    }

    @Test("两个界面适配器共享会话状态，不重复业务排程且可独立释放")
    func sharedPresentationAdapters() async throws {
        let suite = "gudeng-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { try? FileManager.default.removeItem(at: root) }
        let scheduler = TestSettingsScheduler()
        let primary = model(root: root, defaults: defaults, scheduler: scheduler)
        var secondary: ClockModel? = ClockModel(session: primary.session)
        weak var released = secondary
        primary.setAutomaticUpdatesEnabled(false)
        #expect(secondary?.state.automaticUpdatesEnabled == false)
        let now = KitFixture.date("2026-10-26T08:00:00+08:00")
        await secondary?.checkForUpdates(now: now)
        #expect(primary.state.updateState == .notConfigured)
        #expect(secondary?.state == primary.state)
        #expect(scheduler.formalReplacements == 0)
        secondary = nil
        #expect(released == nil)
        primary.setAutomaticUpdatesEnabled(true)
        #expect(primary.state.automaticUpdatesEnabled)
    }

    @Test("权限拒绝和投递失败不伪造预览成功，停止不碰正式排程")
    func previewFailures() async throws {
        let suite = "gudeng-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { try? FileManager.default.removeItem(at: root) }
        let scheduler = TestSettingsScheduler()
        let clock = model(root: root, defaults: defaults, scheduler: scheduler)
        await clock.startPreview()?.value
        #expect(!clock.isPreviewing)
        #expect(clock.previewMessage == ClockText.previewPermissionRequired)
        #expect(scheduler.previewRequests == 0)
        scheduler.authorization = .authorized
        scheduler.failPreview = true
        await clock.startPreview()?.value
        #expect(!clock.isPreviewing)
        #expect(clock.previewMessage.hasPrefix(ClockText.previewFailed))
        #expect(scheduler.previewRequests == 1)
        scheduler.failPreview = false
        let cancelled = clock.startPreview()
        cancelled?.cancel()
        await cancelled?.value
        #expect(!clock.isPreviewing)
        let activePreview = clock.startPreview()
        await scheduler.waitForNextPreview()
        #expect(clock.isPreviewing)
        let stopsBefore = scheduler.stoppedIDs.count
        clock.stopPreview()
        await activePreview?.value
        #expect(!clock.isPreviewing)
        #expect(scheduler.stoppedIDs.count > stopsBefore)
        #expect(scheduler.formalReplacements == 0)
        #expect(clock.preferences.intensity == .strong)
        #expect(clock.preferences.earlyReminderEnabled)
    }

    @Test("七天离线、跨实例和禁用期间不重试，失败保留本地规则")
    func weekOfOfflineAutomaticUpdates() async throws {
        let suite = "gudeng-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { try? FileManager.default.removeItem(at: root) }
        let fetcher = FailingSettingsFetcher()
        let updater = RemoteRuleUpdater(
            baseURL: try #require(URL(string: "https://example.invalid/rules")), fetcher: fetcher)
        let scheduler = TestSettingsScheduler()
        var clock = model(root: root, defaults: defaults, scheduler: scheduler, updater: updater)
        let original = clock.rules
        let start = KitFixture.date("2026-10-26T08:00:00+08:00")

        // One-minute ticks; disabled for two days. Recreated both while enabled
        // and while disabled to exercise persisted attempts and the local switch.
        for minute in 0..<(7 * 24 * 60) {
            if minute == 2 * 24 * 60 { clock.setAutomaticUpdatesEnabled(false) }
            if minute == 4 * 24 * 60 { clock.setAutomaticUpdatesEnabled(true) }
            if minute == 110 || minute == 3000 {
                clock = model(root: root, defaults: defaults, scheduler: scheduler, updater: updater)
            }
            await clock.checkForAutomaticUpdates(now: start.addingTimeInterval(Double(minute * 60)))
        }
        // Five enabled days, four attempts per day; failures are throttled too.
        #expect(await fetcher.requestCount == 20)
        #expect(clock.rules == original)
        #expect(clock.preferences.intensity == .strong)
        #expect(clock.preferences.earlyReminderEnabled)
        #expect(!clock.isCheckingForUpdates)
        #expect(scheduler.formalReplacements == 0)
        #expect(clock.updateMessage.hasPrefix("检查失败："))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Support/active").path))
        let lastAttempt = try #require(defaults.object(forKey: "gudeng.lastAutomaticAttempt") as? Date)
        #expect(lastAttempt == start.addingTimeInterval(6 * 86400 + 18 * 3600))

        clock.setAutomaticUpdatesEnabled(false)
        let manualTime = start.addingTimeInterval(7 * 86400)
        await clock.checkForAutomaticUpdates(now: manualTime)
        #expect(await fetcher.requestCount == 20)
        await clock.checkForUpdates(now: manualTime)
        #expect(await fetcher.requestCount == 21)
        #expect(!clock.automaticUpdatesEnabled)
        #expect(clock.rules == original)
        #expect(defaults.object(forKey: "gudeng.lastAutomaticAttempt") as? Date == lastAttempt)
    }

    @Test("坏清单失败后保留旧规则，不产生虚假的最新提示")
    func malformedManifestKeepsRules() async throws {
        let suite = "gudeng-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { try? FileManager.default.removeItem(at: root) }
        let fetcher = FailingSettingsFetcher(payload: Data("{invalid".utf8))
        let updater = RemoteRuleUpdater(
            baseURL: try #require(URL(string: "https://example.invalid/rules")), fetcher: fetcher)
        let scheduler = TestSettingsScheduler()
        let clock = model(root: root, defaults: defaults, scheduler: scheduler, updater: updater)
        let original = clock.rules
        let now = KitFixture.date("2026-10-26T08:00:00+08:00")
        await clock.checkForAutomaticUpdates(now: now)
        await clock.checkForAutomaticUpdates(now: now.addingTimeInterval(60))
        #expect(await fetcher.requestCount == 1)
        #expect(clock.rules == original)
        #expect(clock.updateMessage.hasPrefix("检查失败："))
        #expect(scheduler.formalReplacements == 0)
        #expect(clock.preferences.intensity == .strong)
        #expect(clock.preferences.earlyReminderEnabled)
    }

    @Test("自动更新关闭再开启后丢弃旧请求失败")
    func staleAutomaticFailure() async throws {
        let suite = "gudeng-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { try? FileManager.default.removeItem(at: root) }
        let fetcher = SuspendedSettingsFetcher(files: ["manifest.json": Data()], failFirst: true)
        let updater = RemoteRuleUpdater(
            baseURL: try #require(URL(string: "https://example.invalid/rules")), fetcher: fetcher)
        let scheduler = TestSettingsScheduler()
        let clock = model(root: root, defaults: defaults, scheduler: scheduler, updater: updater)
        let original = clock.rules
        let now = KitFixture.date("2026-10-26T08:00:00+08:00")
        let task = Task { await clock.checkForAutomaticUpdates(now: now) }
        await fetcher.waitUntilStarted()
        clock.setAutomaticUpdatesEnabled(false)
        clock.setAutomaticUpdatesEnabled(true)
        await fetcher.release()
        await task.value
        #expect(clock.updateState == .idle)
        #expect(!clock.isCheckingForUpdates)
        #expect(clock.updateMessage.isEmpty)
        #expect(clock.rules == original)
        #expect(scheduler.formalReplacements == 0)
        await clock.checkForAutomaticUpdates(now: now.addingTimeInterval(60))
        #expect(await fetcher.requestCount == 1)
    }

    @Test("自动关闭丢弃在途结果；手动检查仍可用且偏好不变")
    func automaticUpdateIsolation() async throws {
        let suite = "gudeng-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { try? FileManager.default.removeItem(at: root) }
        var manifest = try #require(
            JSONSerialization.jsonObject(
                with: Data(contentsOf: KitTestPaths.rulesDirectory.appendingPathComponent("manifest.json")))
                as? [String: Any])
        manifest["bundleVersion"] = "test-disabled"
        let baseline = try RuleBundleLoader.load(from: KitTestPaths.rulesDirectory)
        manifest["publishedAt"] = ISO8601DateFormatter().string(
            from: baseline.manifest.publishedAt.addingTimeInterval(3600))
        manifest["effectiveFrom"] = "2026-10-25T12:00:00+08:00"
        var files: [String: Data] = ["manifest.json": try JSONSerialization.data(withJSONObject: manifest)]
        for name in ["pricing.json", "calendar-2026.json", "reminder-policy.json"] {
            files[name] = try Data(contentsOf: KitTestPaths.rulesDirectory.appendingPathComponent(name))
        }
        let fetcher = SuspendedSettingsFetcher(files: files)
        let updater = RemoteRuleUpdater(
            baseURL: try #require(URL(string: "https://example.invalid/rules")), fetcher: fetcher)
        let clock = model(root: root, defaults: defaults, scheduler: TestSettingsScheduler(), updater: updater)
        let now = KitFixture.date("2026-10-26T08:00:00+08:00")
        let original = clock.rules.bundleVersion
        let task = Task { await clock.checkForAutomaticUpdates(now: now) }
        await fetcher.waitUntilStarted()
        clock.setAutomaticUpdatesEnabled(false)
        await fetcher.release()
        await task.value
        #expect(clock.rules.bundleVersion == original)
        #expect(clock.updateState == .idle)
        #expect(!clock.isCheckingForUpdates)
        let requests = await fetcher.requestCount
        await clock.checkForAutomaticUpdates(now: now.addingTimeInterval(21600))
        #expect(await fetcher.requestCount == requests)
        await clock.checkForUpdates(now: now)
        #expect(clock.rules.bundleVersion == "test-disabled")
        #expect(!clock.automaticUpdatesEnabled)
        #expect(clock.preferences.intensity == .strong)
        #expect(clock.preferences.earlyReminderEnabled)
        let restored = model(root: root, defaults: defaults, scheduler: TestSettingsScheduler(), updater: updater)
        #expect(!restored.automaticUpdatesEnabled)
    }
}

@MainActor
private final class TestSettingsScheduler: ReminderScheduling {
    var authorization: ReminderAuthorization = .denied
    var failPreview = false
    var previewRequests = 0
    var formalReplacements = 0
    var stoppedIDs: [String] = []
    var previewWaiter: CheckedContinuation<Void, Never>?
    func waitForNextPreview() async {
        await withCheckedContinuation { previewWaiter = $0 }
    }
    func authorizationStatus() async -> ReminderAuthorization { authorization }
    func requestAuthorization() async -> ReminderAuthorization { authorization }
    func replacePlan(_ reminders: [PlannedReminder], policy: ReminderPolicy) async { formalReplacements += 1 }
    func cancelAll() async {}
    func stop(eventID: String) async {}
    func openSystemSettings() {}
    func schedulePreview(id: String, intensity: ReminderIntensity, soundEnabled: Bool) async throws {
        previewRequests += 1
        if failPreview { throw CocoaError(.fileWriteNoPermission) }
        previewWaiter?.resume()
        previewWaiter = nil
    }
    func stopPreview(id: String) { stoppedIDs.append(id) }
}

private actor SuspendedSettingsFetcher: RuleDataFetching {
    let files: [String: Data]
    let failFirst: Bool
    var requestCount = 0
    var started = false
    var startWaiter: CheckedContinuation<Void, Never>?
    var responseWaiter: CheckedContinuation<Data, Never>?
    init(files: [String: Data], failFirst: Bool = false) {
        self.files = files
        self.failFirst = failFirst
    }
    func data(from url: URL) async throws -> Data {
        requestCount += 1
        let data = files[url.lastPathComponent]!
        if requestCount == 1 {
            let response = await withCheckedContinuation { continuation in
                responseWaiter = continuation
                started = true
                startWaiter?.resume()
                startWaiter = nil
            }
            if failFirst { throw URLError(.notConnectedToInternet) }
            return response
        }
        return data
    }
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startWaiter = $0 }
    }
    func release() {
        responseWaiter?.resume(returning: files["manifest.json"]!)
        responseWaiter = nil
    }
}

private actor FailingSettingsFetcher: RuleDataFetching {
    private let payload: Data?
    private(set) var requestCount = 0
    init(payload: Data? = nil) { self.payload = payload }
    func data(from url: URL) async throws -> Data {
        requestCount += 1
        if let payload { return payload }
        throw URLError(.notConnectedToInternet)
    }
}
