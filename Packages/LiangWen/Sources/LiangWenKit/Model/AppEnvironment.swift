import Foundation
import LiangWenCore

/// Composition root for both apps.
///
/// A menu-bar utility is single-instance, so a process-wide environment keeps the
/// SwiftUI scene simple. It owns no global mutable business state beyond the model.
@MainActor
public final class AppEnvironment {
    public static let shared = AppEnvironment()

    public let model: ClockModel
    private var loop: Task<Void, Never>?
    private var updateTask: Task<Void, Never>?

    private init() {
        let fileManager = FileManager.default
        let supportRoot =
            fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let rulesSupport =
            supportRoot
            .appendingPathComponent("LiangWen", isDirectory: true)
            .appendingPathComponent("Rules", isDirectory: true)

        let bundled =
            Bundle.main.url(forResource: "Rules", withExtension: nil)
            ?? Bundle.main.resourceURL?.appendingPathComponent("Rules", isDirectory: true)
        precondition(bundled != nil, "Rules folder is missing from the app bundle.")

        let repository = RuleRepository(bundledDirectory: bundled!, supportDirectory: rulesSupport)
        let active = repository.active(at: Date())

        let preferencesStore = UserDefaultsPreferences()
        let preferences =
            preferencesStore.load()
            ?? UserPreferences.initial(policy: active.bundle.ruleSet.reminderPolicy)

        let configuration = RuleSourceConfiguration.resolve()
        let updater = configuration.baseURL.map { RemoteRuleUpdater(baseURL: $0) }

        self.model = ClockModel(
            active: active,
            preferences: preferences,
            repository: repository,
            preferencesStore: preferencesStore,
            scheduler: UserNotificationScheduler(),
            updater: updater
        )
    }

    public func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            guard let self else { return }
            await self.model.prepare()
            while !Task.isCancelled {
                let now = Date()
                await self.model.refresh(now: now)
                #if os(macOS)
                    self.requestAutomaticRuleCheck(now: now)
                #endif
                let nextMinute = (Int(now.timeIntervalSince1970 / 60) + 1) * 60
                let delay = max(1, Double(nextMinute) - now.timeIntervalSince1970)
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private func requestAutomaticRuleCheck(now: Date) {
        guard updateTask == nil else { return }
        updateTask = Task { [weak self] in
            guard let self else { return }
            defer { updateTask = nil }
            await model.checkForAutomaticUpdates(now: now)
        }
    }

    /// Used for wake, clock change and time-zone change notifications.
    public func refreshNow() {
        Task {
            let now = Date()
            await model.refresh(now: now)
            #if os(macOS)
                requestAutomaticRuleCheck(now: now)
            #endif
        }
    }
}
