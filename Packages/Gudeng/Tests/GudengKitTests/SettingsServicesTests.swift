@testable import GudengCore
@testable import GudengRuntime
import Foundation
import Testing
@testable import GudengKit

#if os(macOS)
    import ServiceManagement
#endif

@Suite("设置服务")
struct SettingsServicesTests {
    @Test("预览次数有界且不会使用正式提醒ID")
    func previewBounds() {
        let off = ReminderPreviewPlan(intensity: .off)
        let medium = ReminderPreviewPlan(intensity: .medium)
        let strong = ReminderPreviewPlan(intensity: .strong)
        #expect(off.offsets.isEmpty)
        #expect(medium.offsets == [1])
        #expect(strong.offsets == [1, 4, 7])
        #expect(strong.offsets.allSatisfy { $0 > 0 && $0 < strong.duration })
        #expect(strong.duration == 10)
        #expect(strong.identifiers(id: "test").allSatisfy { !$0.hasPrefix("lw.") })
        #expect(strong.identifiers(id: "first") != strong.identifiers(id: "second"))
    }

    @Test("自动更新关闭、失败后节流、跨重启与改时")
    func automaticUpdateCadence() {
        let now = KitFixture.date("2026-10-26T08:00:00+08:00")
        var schedule = AutomaticUpdateSchedule()
        #expect(!schedule.isDue(at: now, enabled: false))
        #expect(schedule.isDue(at: now, enabled: true))
        schedule.recordAttempt(at: now)
        #expect(!schedule.isDue(at: now.addingTimeInterval(21599), enabled: true))
        #expect(schedule.isDue(at: now.addingTimeInterval(21600), enabled: true))
        #expect(!schedule.isDue(at: now.addingTimeInterval(21600), enabled: false))
        let restored = AutomaticUpdateSchedule(lastAttempt: schedule.lastAttempt)
        #expect(!restored.isDue(at: now, enabled: true))
        #expect(restored.isDue(at: now.addingTimeInterval(-60), enabled: true))
    }

    #if os(macOS)
        @Test("从未注册的主应用服务notFound不能禁用用户注册入口")
        @MainActor
        func unseenMainAppCanRegister() {
            #expect(SystemLoginItemService.loginState(for: .notFound) == .disabled)
            #expect(SystemLoginItemService.loginState(for: .notRegistered) == .disabled)
            #expect(SystemLoginItemService.loginState(for: .enabled) == .enabled)
            #expect(SystemLoginItemService.loginState(for: .requiresApproval) == .requiresApproval)
        }
    #endif

    @Test("登录开关以真实状态为准，注册失败不伪造成功")
    @MainActor
    func loginFailureAndApproval() {
        let service = TestLoginItemService()
        let controller = LoginItemController(service: service)
        #expect(controller.state == .disabled)
        service.shouldFail = true
        controller.setEnabled(true)
        #expect(controller.state == .disabled)
        #expect(controller.errorMessage != nil)
        service.shouldFail = false
        controller.setEnabled(true)
        #expect(controller.state == .requiresApproval)
        #expect(controller.errorMessage == nil)
        service.state = .enabled
        controller.refresh()
        #expect(controller.state == .enabled)
        controller.setEnabled(false)
        #expect(controller.state == .disabled)
    }
}

@MainActor
private final class TestLoginItemService: LoginItemManaging {
    var state: LoginItemState = .disabled
    var shouldFail = false
    func setEnabled(_ enabled: Bool) throws {
        if shouldFail { throw CocoaError(.fileWriteNoPermission) }
        state = enabled ? .requiresApproval : .disabled
    }
    func openSettings() {}
}

@MainActor
@Suite("偏好键迁移")
struct PreferencesMigrationTests {
    private func makeDefaults() throws -> (UserDefaults, String) {
        let name = "gudeng.tests.preferences.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    @Test("旧 liangwen 偏好键读取后写入新键")
    func migratesLegacyKey() throws {
        let (defaults, name) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let legacy = UserPreferences(intensity: .strong, earlyReminderEnabled: true)
        defaults.set(try JSONEncoder().encode(legacy), forKey: UserDefaultsPreferences.legacyKey)

        let store = UserDefaultsPreferences(defaults: defaults)
        #expect(store.load() == legacy)
        #expect(defaults.data(forKey: UserDefaultsPreferences.defaultKey) != nil)
        // The legacy value stays for rollback.
        #expect(defaults.data(forKey: UserDefaultsPreferences.legacyKey) != nil)
    }

    @Test("新键优先，旧键不再覆盖")
    func currentKeyWins() throws {
        let (defaults, name) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let legacy = UserPreferences(intensity: .medium, earlyReminderEnabled: false)
        let current = UserPreferences(intensity: .strong, earlyReminderEnabled: true)
        defaults.set(try JSONEncoder().encode(legacy), forKey: UserDefaultsPreferences.legacyKey)
        defaults.set(try JSONEncoder().encode(current), forKey: UserDefaultsPreferences.defaultKey)

        #expect(UserDefaultsPreferences(defaults: defaults).load() == current)
    }

    @Test("没有偏好时返回空，由策略默认值接管")
    func emptyStore() throws {
        let (defaults, name) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(UserDefaultsPreferences(defaults: defaults).load() == nil)
    }
}
