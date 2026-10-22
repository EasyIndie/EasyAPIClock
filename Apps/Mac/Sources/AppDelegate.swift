import AppKit
import LiangWenKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppEnvironment.shared.start()
        observeSystemChanges()
    }

    /// Recalculate immediately after wake, manual clock changes and time-zone changes.
    private func observeSystemChanges() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AppEnvironment.shared.refreshNow()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .NSSystemClockDidChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AppEnvironment.shared.refreshNow()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AppEnvironment.shared.refreshNow()
            }
        }
    }
}
