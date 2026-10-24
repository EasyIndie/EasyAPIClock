import Foundation
import OSLog
// The Xcode 16 SDK does not mark UNUserNotificationCenter/UNNotificationSettings
// as Sendable. All calls below are made on the main actor; @preconcurrency keeps
// the SDK's incomplete annotations from turning into false-positive concurrency
// errors while leaving our own types under Swift 6 checking.
@preconcurrency import UserNotifications
import LiangWenCore

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
    static let thread = "liangwen.price-transition"
}

/// System notification delivery backed by UserNotifications.
///
/// Notifications are best-effort: Focus modes, silent mode and authorization can
/// suppress sound or presentation. The settings panel surfaces denied permission.
@MainActor
public final class UserNotificationScheduler: ReminderScheduling {
    private let center: UNUserNotificationCenter
    private let logger = Logger(subsystem: "app.liangwen", category: "notifications")
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
    }

    public func authorizationStatus() async -> ReminderAuthorization {
        // UNNotificationSettings is not Sendable on the Xcode 16 SDK. Read the
        // status inside the callback and resume with a Sendable enum value.
        let status: ReminderAuthorization = await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: reminderAuthorization(from: settings.authorizationStatus))
            }
        }
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
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(
                    returning: requests.map { request in
                        PendingNotificationInfo(
                            identifier: request.identifier,
                            categoryIdentifier: request.content.categoryIdentifier,
                            eventID: request.content.userInfo[NotificationID.eventKey] as? String
                        )
                    }
                )
            }
        }
    }

    private func deliveredNotificationInfos() async -> [DeliveredNotificationInfo] {
        await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { notifications in
                continuation.resume(
                    returning: notifications.map { notification in
                        DeliveredNotificationInfo(
                            identifier: notification.request.identifier,
                            eventID: notification.request.content.userInfo[NotificationID.eventKey] as? String
                        )
                    }
                )
            }
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
        [.banner, .list, .sound]
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
