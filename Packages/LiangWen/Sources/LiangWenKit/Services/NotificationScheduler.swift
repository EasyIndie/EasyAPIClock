import Foundation
import UserNotifications
import LiangWenCore

#if os(macOS)
    import AppKit
#elseif os(iOS)
    import UIKit
#endif

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
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        case .ephemeral: return .ephemeral
        @unknown default: return .unknown
        }
    }

    public func requestAuthorization() async -> ReminderAuthorization {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return .denied
        }
        return await authorizationStatus()
    }

    public func replacePlan(_ reminders: [PlannedReminder], policy: ReminderPolicy) async {
        let now = Date()
        let requests = await pendingRequests()
        let keepLiveStrongRepeats = reminders.first?.intensity == .strong
        let stale = requests.filter { request in
            guard request.identifier.hasPrefix(NotificationID.prefix) else { return false }
            if keepLiveStrongRepeats,
                StrongRepeatRetention.shouldKeep(
                    identifier: request.identifier,
                    categoryIdentifier: request.content.categoryIdentifier,
                    eventID: request.content.userInfo[NotificationID.eventKey] as? String,
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
                try? await center.add(request)
            }
        }
    }

    public func cancelAll() async {
        let requests = await pendingRequests()
        let identifiers = requests.map(\.identifier).filter { $0.hasPrefix(NotificationID.prefix) }
        if !identifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
        center.removeAllDeliveredNotifications()
    }

    public func stop(eventID: String) async {
        let pending = await pendingRequests()
        let pendingIDs =
            pending
            .filter { $0.content.userInfo[NotificationID.eventKey] as? String == eventID }
            .map(\.identifier)
        if !pendingIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        }

        let delivered = await deliveredNotifications()
        let deliveredIDs =
            delivered
            .filter { $0.request.content.userInfo[NotificationID.eventKey] as? String == eventID }
            .map(\.request.identifier)
        if !deliveredIDs.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        }
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

    private func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    private func deliveredNotifications() async -> [UNNotification] {
        await center.deliveredNotifications()
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
