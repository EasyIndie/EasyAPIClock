import Foundation
import Combine
import LiangWenCore
import LiangWenRuntime

/// SwiftUI observation and localized presentation for a reusable business session.
@MainActor
public final class ClockModel: ObservableObject {
    @Published public private(set) var state: ClockSessionState
    public let loginItem: LoginItemController
    public let session: ClockSession
    private var observationID: UUID?

    public var rules: RuleSet { state.rules }
    public var snapshot: PriceSnapshot { state.snapshot }
    public var preferences: UserPreferences { state.preferences }
    public var now: Date { state.now }
    public var authorization: ReminderAuthorization { state.authorization }
    public var ruleStatus: RuleStatus { state.ruleStatus }
    public var updateState: UpdateState { state.updateState }
    public var isCheckingForUpdates: Bool { state.isCheckingForUpdates }
    public var automaticUpdatesEnabled: Bool { state.automaticUpdatesEnabled }
    public var isPreviewing: Bool { state.isPreviewing }

    public var previewMessage: String {
        switch state.previewOutcome {
        case .idle: ""
        case .permissionRequired: ClockText.previewPermissionRequired
        case .finished: ClockText.previewFinished
        case .failed(let message): ClockText.previewFailed + message
        }
    }

    public init(session: ClockSession, loginItem: LoginItemController? = nil) {
        self.session = session
        self.loginItem = loginItem ?? LoginItemController()
        self.state = session.state
        self.observationID = session.observe { [weak self] state in self?.state = state }
    }

    public convenience init(
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
        self.init(
            session: ClockSession(
                active: active, preferences: preferences, repository: repository,
                preferencesStore: preferencesStore, scheduler: scheduler, updater: updater,
                settingsDefaults: settingsDefaults, initialNow: initialNow),
            loginItem: loginItem)
    }

    deinit {
        if let observationID {
            let session = session
            Task { @MainActor in session.removeObserver(observationID) }
        }
    }

    public func prepare() async {
        loginItem.refresh()
        await session.prepare()
    }

    public func refresh(now: Date = Date(), forceReload: Bool = false) async {
        loginItem.refresh()
        await session.refresh(now: now, forceReload: forceReload)
    }

    public func setIntensity(_ intensity: ReminderIntensity) async { await session.setIntensity(intensity) }
    public func setEarlyReminderEnabled(_ enabled: Bool) async { await session.setEarlyReminderEnabled(enabled) }
    public func setAutomaticUpdatesEnabled(_ enabled: Bool) { session.setAutomaticUpdatesEnabled(enabled) }
    public func checkForAutomaticUpdates(now: Date) async { await session.checkForAutomaticUpdates(now: now) }
    public func checkForUpdates(automatic: Bool = false, now: Date = Date()) async {
        await session.checkForUpdates(automatic: automatic, now: now)
    }
    @discardableResult
    public func startPreview() -> Task<Void, Never>? { session.startPreview() }
    public func stopPreview() { session.stopPreview() }
    public func openNotificationSettings() { session.openNotificationSettings() }

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

}
