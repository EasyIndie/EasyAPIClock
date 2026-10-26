import Foundation
import Observation
import OSLog
import LiangWenCore

@MainActor
@Observable
public final class ClockModel {
    public private(set) var rules: RuleSet
    public private(set) var snapshot: PriceSnapshot
    public private(set) var preferences: UserPreferences
    public private(set) var now: Date
    public private(set) var authorization: ReminderAuthorization = .unknown
    public private(set) var ruleStatus: RuleStatus
    public private(set) var updateState: UpdateState = .idle
    public private(set) var isCheckingForUpdates = false
    public private(set) var automaticUpdatesEnabled: Bool
    public private(set) var isPreviewing = false
    public private(set) var previewMessage = ""
    public let loginItem: LoginItemController
    @ObservationIgnored private let settingsDefaults: UserDefaults
    @ObservationIgnored private var automaticSchedule: AutomaticUpdateSchedule
    @ObservationIgnored private var automaticGeneration = 0
    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private var previewID: String?

    @ObservationIgnored private let repository: RuleRepository
    @ObservationIgnored private let preferencesStore: any PreferencesStoring
    @ObservationIgnored private let scheduler: any ReminderScheduling
    @ObservationIgnored private let updater: RemoteRuleUpdater?
    @ObservationIgnored private var engine: ClockEngine
    @ObservationIgnored private var planSignature = ""
    @ObservationIgnored private var didPrepare = false
    @ObservationIgnored private let logger = Logger(subsystem: "app.liangwen", category: "clock")

    public init(
        active: RuleRepository.Active,
        preferences: UserPreferences,
        repository: RuleRepository,
        preferencesStore: any PreferencesStoring,
        scheduler: any ReminderScheduling,
        updater: RemoteRuleUpdater?,
        settingsDefaults: UserDefaults = .standard,
        loginItem: LoginItemController? = nil,
        initialNow: Date = Date()
    ) {
        let now = initialNow
        let engine = ClockEngine(rules: active.bundle.ruleSet)
        self.settingsDefaults = settingsDefaults
        self.automaticUpdatesEnabled = settingsDefaults.object(forKey: "gudeng.automaticUpdates") as? Bool ?? true
        self.automaticSchedule = AutomaticUpdateSchedule(
            lastAttempt: settingsDefaults.object(forKey: "gudeng.lastAutomaticAttempt") as? Date)
        self.loginItem = loginItem ?? LoginItemController()
        self.rules = active.bundle.ruleSet
        self.preferences = preferences
        self.now = now
        self.snapshot = engine.snapshot(at: now)
        self.repository = repository
        self.preferencesStore = preferencesStore
        self.scheduler = scheduler
        self.updater = updater
        self.engine = engine
        self.ruleStatus = Self.makeStatus(rules: active.bundle.ruleSet, active: active)
    }

    // MARK: - Lifecycle

    public func prepare() async {
        if didPrepare {
            await refresh(now: Date())
            return
        }
        didPrepare = true
        authorization = await scheduler.authorizationStatus()
        if authorization == .notDetermined, preferences.intensity != .off {
            authorization = await scheduler.requestAuthorization()
        }
        logger.info(
            "启动：规则 \(self.rules.bundleVersion, privacy: .public)，提醒 \(self.preferences.intensity.rawValue, privacy: .public)，授权 \(self.authorization.rawValue, privacy: .public)"
        )
        await refresh(now: Date(), forceReload: true)
    }

    public func refresh(now: Date = Date(), forceReload: Bool = false) async {
        self.now = now
        loginItem.refresh()
        reloadRules(force: forceReload)

        let newAuthorization = await scheduler.authorizationStatus()
        if newAuthorization != authorization {
            authorization = newAuthorization
            planSignature = ""
        }

        engine = ClockEngine(rules: rules)
        let newSnapshot = engine.snapshot(at: now)
        snapshot = newSnapshot

        let plan = ReminderPlanner(
            now: now,
            preferences: preferences,
            policy: rules.reminderPolicy
        ).plan(for: newSnapshot)
        let signature = [
            authorization.rawValue,
            rules.bundleVersion,
            plan.map(\.signature).joined(separator: ";"),
        ].joined(separator: "#")
        guard signature != planSignature else { return }
        planSignature = signature
        logger.info(
            "刷新：状态 \(self.snapshot.state?.rawValue ?? "unknown", privacy: .public)，计划 \(plan.count, privacy: .public) 个事件"
        )
        await scheduler.replacePlan(plan, policy: rules.reminderPolicy)
    }

    // MARK: - User actions

    public func setIntensity(_ intensity: ReminderIntensity) async {
        guard preferences.intensity != intensity else { return }
        stopPreview()
        preferences.intensity = intensity
        preferencesStore.save(preferences)
        planSignature = ""
        if intensity != .off, authorization == .notDetermined {
            authorization = await scheduler.requestAuthorization()
        }
        await refresh(now: Date())
    }

    public func setEarlyReminderEnabled(_ enabled: Bool) async {
        guard preferences.earlyReminderEnabled != enabled else { return }
        preferences.earlyReminderEnabled = enabled
        preferencesStore.save(preferences)
        planSignature = ""
        await refresh(now: Date())
    }

    public func setAutomaticUpdatesEnabled(_ enabled: Bool) {
        automaticUpdatesEnabled = enabled
        automaticGeneration += 1
        settingsDefaults.set(enabled, forKey: "gudeng.automaticUpdates")
    }

    public func checkForAutomaticUpdates(now: Date) async {
        guard updater != nil, !isCheckingForUpdates,
            automaticSchedule.isDue(at: now, enabled: automaticUpdatesEnabled)
        else { return }
        automaticSchedule.recordAttempt(at: now)
        settingsDefaults.set(now, forKey: "gudeng.lastAutomaticAttempt")
        await checkForUpdates(automatic: true, now: now)
    }

    @discardableResult
    public func startPreview() -> Task<Void, Never>? {
        guard !isPreviewing, preferences.intensity != .off else { return nil }
        let id = UUID().uuidString
        let intensity = preferences.intensity
        let plan = ReminderPreviewPlan(intensity: intensity)
        previewID = id
        isPreviewing = true
        previewMessage = ""
        previewTask = Task { [weak self] in
            guard let self else { return }
            let status = await scheduler.authorizationStatus()
            guard !Task.isCancelled else {
                finishPreview(id: id, message: "")
                return
            }
            authorization = status
            guard status.allowsNotifications else {
                finishPreview(id: id, message: ClockText.previewPermissionRequired)
                return
            }
            do {
                try await scheduler.schedulePreview(
                    id: id, intensity: intensity, soundEnabled: rules.reminderPolicy.soundEnabled)
                try await Task.sleep(for: .seconds(plan.duration))
                finishPreview(id: id, message: ClockText.previewFinished)
            } catch is CancellationError {
                scheduler.stopPreview(id: id)
                finishPreview(id: id, message: "")
            } catch {
                finishPreview(id: id, message: ClockText.previewFailed + error.localizedDescription)
            }
        }
        return previewTask
    }

    public func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
        if let id = previewID { scheduler.stopPreview(id: id) }
        previewID = nil
        isPreviewing = false
        previewMessage = ""
    }

    private func finishPreview(id: String, message: String) {
        guard previewID == id else { return }
        scheduler.stopPreview(id: id)
        previewID = nil
        isPreviewing = false
        previewTask = nil
        previewMessage = message
    }

    public func checkForUpdates(automatic: Bool = false, now: Date = Date()) async {
        guard !isCheckingForUpdates else { return }
        guard let updater else {
            updateState = .notConfigured
            return
        }
        let generation = automaticGeneration
        isCheckingForUpdates = true
        updateState = .checking
        defer { isCheckingForUpdates = false }

        do {
            let bundle = try await updater.checkForUpdate(current: rules)
            if automatic, (!automaticUpdatesEnabled || generation != automaticGeneration) {
                updateState = .idle
                return
            }
            if let bundle {
                try repository.install(bundle, at: now)
                await refresh(now: now, forceReload: true)
                updateState = .updated(bundle.manifest.bundleVersion)
                logger.info("规则更新成功：\(bundle.manifest.bundleVersion, privacy: .public)")
            } else {
                updateState = .upToDate(rules.bundleVersion)
                logger.info("规则已是最新：\(self.rules.bundleVersion, privacy: .public)")
            }
        } catch {
            if automatic, (!automaticUpdatesEnabled || generation != automaticGeneration) {
                updateState = .idle
                return
            }
            updateState = .failed(error.localizedDescription)
            logger.error("规则更新失败：\(error.localizedDescription, privacy: .public)")
        }
    }

    public func openNotificationSettings() {
        scheduler.openSystemSettings()
    }

    // MARK: - Derived presentation

    public var reminderStatusText: String {
        if preferences.intensity == .off { return "提醒已关闭" }
        if snapshot.state == nil || snapshot.nextChangeAt == nil { return "提醒暂停" }
        if authorization.isDenied { return "通知未授权" }
        return ClockText.intensitySummary(preferences.intensity)
    }

    public var updateMessage: String {
        switch updateState {
        case .idle:
            ""
        case .notConfigured:
            "未配置更新源；当前使用\(ruleStatus.originText)。"
        case .checking:
            "正在检查更新…"
        case .upToDate(let version):
            "已是最新规则包 \(version)。"
        case .updated(let version):
            "已更新至 \(version)，后续提醒已重新安排。"
        case .failed(let message):
            "检查失败：\(message) 继续使用本地有效规则。"
        }
    }

    public var advanceLeadText: String {
        guard let lead = rules.reminderPolicy.advanceLeadSeconds else { return "提前提醒" }
        return "提前 \(ClockText.leadPhrase(lead))提醒"
    }

    // MARK: - Rules

    private func reloadRules(force: Bool) {
        let active = repository.active(at: now)
        let newRules = active.bundle.ruleSet
        let newStatus = Self.makeStatus(rules: newRules, active: active)
        if newRules != rules {
            rules = newRules
            engine = ClockEngine(rules: newRules)
            planSignature = ""
        }
        if force || newStatus != ruleStatus {
            ruleStatus = newStatus
        }
    }

    private static func makeStatus(rules: RuleSet, active: RuleRepository.Active) -> RuleStatus {
        RuleStatus(
            bundleVersion: rules.bundleVersion,
            pricingVersion: rules.pricing.version,
            calendarVersion: rules.calendar.version,
            coverage: rules.calendar.coverage,
            sourceName: rules.pricing.source.name,
            sourceURL: rules.pricing.source.url,
            checkedAt: rules.pricing.source.checkedAt,
            calendarSourceURL: rules.calendar.source.url,
            calendarCheckedAt: rules.calendar.source.checkedAt,
            origin: active.origin,
            pendingVersion: active.pendingVersion,
            installedError: active.installedError
        )
    }
}
