import Foundation
import GudengCore

/// Decides whether an already-scheduled strong repeat should survive a plan replacement.
///
/// A strong alert is delivered at the transition and then repeats for a bounded window.
/// The app refreshes every minute, which normally replaces all pending notifications.
/// Without this rule, the first refresh after the transition would cancel the rest of
/// the alert. Repeats are kept only while their own bounded window is still open, and
/// only when the current plan is still strong. Turning the intensity down/off, or
/// stopping the alert, removes them.
public enum StrongRepeatRetention {
    public static func shouldKeep(
        identifier: String,
        categoryIdentifier: String,
        eventID: String?,
        now: Date,
        policy: ReminderPolicy
    ) -> Bool {
        guard categoryIdentifier == NotificationCategory.strong else { return false }
        guard let suffix = identifier.split(separator: ".").last, suffix.hasPrefix("r") else {
            return false
        }
        guard let eventID, eventID.hasPrefix("t:"), let epoch = TimeInterval(eventID.dropFirst(2)) else {
            return false
        }
        let transition = Date(timeIntervalSince1970: epoch)
        let retention = Double(policy.strongRepeatIntervalSeconds * policy.strongMaxRepeats + 60)
        return now < transition.addingTimeInterval(retention)
    }
}

/// Shared notification identifiers used by the scheduler and tests.
public enum NotificationCategory {
    public static let strong = "lw.strong"
}
