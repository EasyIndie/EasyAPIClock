import Foundation
import LiangWenCore

public enum ReminderAuthorization: String, Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown

    public var allowsNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral: true
        case .notDetermined, .denied, .unknown: false
        }
    }

    public var isDenied: Bool { self == .denied }
}

@MainActor
public protocol PreferencesStoring: AnyObject {
    func load() -> UserPreferences?
    func save(_ preferences: UserPreferences)
}

@MainActor
public protocol ReminderScheduling: AnyObject {
    func authorizationStatus() async -> ReminderAuthorization
    func requestAuthorization() async -> ReminderAuthorization
    func replacePlan(_ reminders: [PlannedReminder], policy: ReminderPolicy) async
    func cancelAll() async
    func stop(eventID: String) async
    func schedulePreview(id: String, intensity: ReminderIntensity, soundEnabled: Bool) async throws
    func stopPreview(id: String)
    func openSystemSettings()
}
