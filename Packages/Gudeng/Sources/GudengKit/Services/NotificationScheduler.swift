import GudengRuntime
import Foundation
import OSLog
// The Xcode 16 SDK does not mark UNUserNotificationCenter/UNNotificationSettings
// as Sendable. All calls below are made on the main actor; @preconcurrency keeps
// the SDK's incomplete annotations from turning into false-positive concurrency
// errors while leaving our own types under Swift 6 checking.
@preconcurrency import UserNotifications
import GudengCore

#if os(macOS)
    import AppKit
#elseif os(iOS)
    import UIKit
#endif

private func reminderAuthorization(from status: UNAuthorizationStatus) -> ReminderAuthorization {
    switch status {
    case .notDetermined: .notDetermined
    case .denied: .denied
    case .authorized: .authorized
    case .provisional: .provisional
    case .ephemeral: .ephemeral
    @unknown default: .unknown
    }
}

private struct PendingNotificationInfo: Sendable {
    let identifier: String
    let categoryIdentifier: String
    let eventID: String?
}

private struct DeliveredNotificationInfo: Sendable {
    let identifier: String
    let eventID: String?
}

private enum NotificationID {
    static let prefix = "lw."
    static let stopAction = "lw.stop"
    static let strongCategory = NotificationCategory.strong
    static let eventKey = "lw.eventID"
    static let thread = "gudeng.price-transition"
}

/// System notification delivery backed by UserNotifications.
///
/// Notifications are best-effort: Focus modes, silent mode and authorization can
/// suppress sound or presentation. The settings panel surfaces denied permission.
@MainActor
public final class UserNotificationScheduler: ReminderScheduling {
    #if DEBUG
        private var previewProbes: [String: Task<Void, Never>] = [:]
    #endif
    private let center: UNUserNotificationCenter
    private let logger = Logger(subsystem: "com.easyindie.easyapiclock", category: "notifications")
    private lazy var delegate = NotificationDelegate { [weak self] eventID in
        Task { @MainActor in
            await self?.stop(eventID: eventID)
        }
    }

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        let stop = UNNotificationAction(
            identifier: NotificationID.stopAction,
            title: "停止提醒",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: NotificationID.strongCategory,
            actions: [stop],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
        center.delegate = delegate
        #if DEBUG
            if previewDiagnosticsEnabled {
                Task { [weak self] in
                    await self?.diagnosePreview(id: nil, phase: "launch-snapshot")
                }
            }
        #endif
    }

    public func authorizationStatus() async -> ReminderAuthorization {
        // Use the async API so the value is read on the main actor instead of a
        // UserNotifications callback queue. Reading it in a callback tripped the
        // Swift 6 actor-isolation assertion in Release builds.
        let settings = await center.notificationSettings()
        let status = reminderAuthorization(from: settings.authorizationStatus)
        logger.debug("通知授权状态：\(status.rawValue, privacy: .public)")
        return status
    }

    public func requestAuthorization() async -> ReminderAuthorization {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("请求通知授权失败：\(error.localizedDescription, privacy: .public)")
            return .denied
        }
        return await authorizationStatus()
    }

    public func replacePlan(_ reminders: [PlannedReminder], policy: ReminderPolicy) async {
        let now = Date()
        let requests = await pendingNotificationInfos()
        let keepLiveStrongRepeats = reminders.first?.intensity == .strong
        let stale = requests.filter { request in
            guard request.identifier.hasPrefix(NotificationID.prefix) else { return false }
            if keepLiveStrongRepeats,
                StrongRepeatRetention.shouldKeep(
                    identifier: request.identifier,
                    categoryIdentifier: request.categoryIdentifier,
                    eventID: request.eventID,
                    now: now,
                    policy: policy
                )
            {
                return false
            }
            return true
        }.map(\.identifier)
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }
        logger.info(
            "重排通知：\(reminders.count, privacy: .public) 个事件，清理 \(stale.count, privacy: .public) 个旧请求，保留强提醒重复：\(keepLiveStrongRepeats, privacy: .public)"
        )
        guard !reminders.isEmpty else { return }

        for reminder in reminders {
            for (index, fireDate) in reminder.allFireDates.enumerated() {
                let identifier =
                    index == 0
                    ? "\(NotificationID.prefix)\(reminder.id)"
                    : "\(NotificationID.prefix)\(reminder.id).r\(index)"
                let content = makeContent(for: reminder, policy: policy)
                let interval = max(1, fireDate.timeIntervalSinceNow)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                do {
                    try await center.add(request)
                } catch {
                    logger.error(
                        "安排通知失败 \(identifier, privacy: .public)：\(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
    }

    public func cancelAll() async {
        let requests = await pendingNotificationInfos()
        let identifiers = requests.map(\.identifier).filter { $0.hasPrefix(NotificationID.prefix) }
        if !identifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
        center.removeAllDeliveredNotifications()
        logger.info("已取消全部通知计划")
    }

    public func stop(eventID: String) async {
        let pending = await pendingNotificationInfos()
        let pendingIDs = pending.filter { $0.eventID == eventID }.map(\.identifier)
        if !pendingIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        }

        let delivered = await deliveredNotificationInfos()
        let deliveredIDs = delivered.filter { $0.eventID == eventID }.map(\.identifier)
        if !deliveredIDs.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        }
        logger.info(
            "停止强提醒 \(eventID, privacy: .public)：pending \(pendingIDs.count, privacy: .public)，delivered \(deliveredIDs.count, privacy: .public)"
        )
    }

    public func schedulePreview(id: String, intensity: ReminderIntensity, soundEnabled: Bool) async throws {
        let plan = ReminderPreviewPlan(intensity: intensity)
        let identifiers = plan.identifiers(id: id)
        do {
            for (identifier, offset) in zip(identifiers, plan.offsets) {
                try Task.checkCancellation()
                let content = UNMutableNotificationContent()
                content.title = ClockText.previewNotificationTitle
                content.body = ClockText.previewNotificationBody
                content.subtitle = ClockText.intensityName(intensity)
                content.sound = soundEnabled ? .default : nil
                content.threadIdentifier = "gudeng.preview"
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: offset, repeats: false)
                try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
                try Task.checkCancellation()
            }
            #if DEBUG
                await diagnosePreview(id: id, phase: "scheduled")
                try Task.checkCancellation()
                startPreviewProbe(id: id)
            #endif
        } catch {
            stopPreview(id: id)
            throw error
        }
    }

    public func stopPreview(id: String) {
        #if DEBUG
            previewProbes.removeValue(forKey: id)?.cancel()
        #endif
        let identifiers = ReminderPreviewPlan(intensity: .strong).identifiers(id: id)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        #if DEBUG
            if previewDiagnosticsEnabled {
                Task { [weak self] in
                    await self?.diagnosePreview(id: id, phase: "stop-snapshot")
                }
            }
        #endif
    }

    #if DEBUG
        private var previewDiagnosticsEnabled: Bool {
            ProcessInfo.processInfo.environment["GUDENG_NOTIFICATION_DIAGNOSTICS"] == "1"
        }

        private func startPreviewProbe(id: String) {
            guard previewDiagnosticsEnabled else { return }
            previewProbes[id] = Task { [weak self] in
                for delay in [2, 3, 3] {
                    do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                    guard !Task.isCancelled else { return }
                    await self?.diagnosePreview(id: id, phase: "delivery-probe")
                }
            }
        }

        private func notificationPresentationDiagnostics() async -> [String: String] {
            let settings = await center.notificationSettings()
            func name(_ value: UNNotificationSetting) -> String {
                switch value {
                case .enabled: "enabled"
                case .disabled: "disabled"
                case .notSupported: "not-supported"
                @unknown default: "unknown"
                }
            }
            let style: String
            switch settings.alertStyle {
            case .none: style = "none"
            case .banner: style = "banner"
            case .alert: style = "alert"
            @unknown default: style = "unknown"
            }
            return [
                "alerts": name(settings.alertSetting),
                "sound": name(settings.soundSetting),
                "notificationCenter": name(settings.notificationCenterSetting),
                "style": style,
            ]
        }

        private func diagnosePreview(id: String?, phase: String) async {
            guard previewDiagnosticsEnabled else { return }
            let prefix = id.map { "gudeng.preview.\($0)." } ?? "gudeng.preview."
            let pending = await pendingNotificationInfos()
            let delivered = await deliveredNotificationInfos()
            let status = await authorizationStatus()
            let presentation = await notificationPresentationDiagnostics()
            let record: [String: Any] = [
                "event": "gudeng.preview.diagnostic",
                "phase": phase,
                "previewID": id ?? "all",
                "authorization": status.rawValue,
                "presentation": presentation,
                "pendingPreviewIDs": pending.map(\.identifier).filter { $0.hasPrefix(prefix) },
                "deliveredPreviewIDs": delivered.map(\.identifier).filter { $0.hasPrefix(prefix) },
                "formalPendingCount": pending.filter { $0.identifier.hasPrefix(NotificationID.prefix) }.count,
            ]
            if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) {
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data([10]))
            }
        }
    #endif

    public func openSystemSettings() {
        #if os(macOS)
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                NSWorkspace.shared.open(url)
            }
        #elseif os(iOS)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        #endif
    }

    private func makeContent(for reminder: PlannedReminder, policy: ReminderPolicy) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = ReminderCopy.title(for: reminder)
        content.body = ReminderCopy.body(for: reminder)
        content.subtitle = ReminderCopy.subtitle(for: reminder) ?? ""
        content.sound = policy.soundEnabled ? .default : nil
        content.threadIdentifier = NotificationID.thread
        content.userInfo = [NotificationID.eventKey: reminder.id]
        if reminder.intensity == .strong {
            content.categoryIdentifier = NotificationID.strongCategory
        }
        return content
    }

    // MARK: - Sendable snapshots of platform objects
    //
    // `UNNotificationRequest` and `UNNotification` are not Sendable. Extract only
    // the strings we need inside the callback so this code compiles with both the
    // Xcode 16 and Xcode 27 SDKs under Swift 6 strict concurrency.

    private func pendingNotificationInfos() async -> [PendingNotificationInfo] {
        let requests = await center.pendingNotificationRequests()
        return requests.map { request in
            PendingNotificationInfo(
                identifier: request.identifier,
                categoryIdentifier: request.content.categoryIdentifier,
                eventID: request.content.userInfo[NotificationID.eventKey] as? String
            )
        }
    }

    private func deliveredNotificationInfos() async -> [DeliveredNotificationInfo] {
        let notifications = await center.deliveredNotifications()
        return notifications.map { notification in
            DeliveredNotificationInfo(
                identifier: notification.request.identifier,
                eventID: notification.request.content.userInfo[NotificationID.eventKey] as? String
            )
        }
    }
}

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let onStop: @Sendable (String) -> Void

    init(onStop: @escaping @Sendable (String) -> Void) {
        self.onStop = onStop
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        #if DEBUG
            if ProcessInfo.processInfo.environment["GUDENG_NOTIFICATION_DIAGNOSTICS"] == "1",
                notification.request.identifier.hasPrefix("gudeng.preview.")
            {
                let record = [
                    "event": "gudeng.preview.diagnostic", "phase": "will-present",
                    "identifier": notification.request.identifier,
                ]
                if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) {
                    FileHandle.standardOutput.write(data)
                    FileHandle.standardOutput.write(Data([10]))
                }
            }
        #endif
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == NotificationID.stopAction else { return }
        guard let eventID = response.notification.request.content.userInfo[NotificationID.eventKey] as? String else {
            return
        }
        onStop(eventID)
    }
}
