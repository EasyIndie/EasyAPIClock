import AppKit
import SwiftUI
import GudengKit

@main
struct GudengMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let environment = AppEnvironment.shared

    var body: some Scene {
        MenuBarExtra {
            ClockPanelView(model: environment.model) {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            MenuBarStatusLabel(model: environment.model)
        }
        .menuBarExtraStyle(.window)
    }
}
