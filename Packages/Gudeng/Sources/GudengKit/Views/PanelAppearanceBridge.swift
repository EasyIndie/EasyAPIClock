#if os(macOS)
    import AppKit
    import SwiftUI

    /// MenuBarExtra does not consistently propagate preferredColorScheme to its panel.
    struct PanelAppearanceBridge: NSViewRepresentable {
        let mode: String

        func makeNSView(context: Context) -> AppearanceView {
            AppearanceView()
        }

        func updateNSView(_ view: AppearanceView, context: Context) {
            view.mode = mode
            view.applyAppearance()
        }

        final class AppearanceView: NSView {
            var mode = "system"

            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                applyAppearance()
            }

            func applyAppearance() {
                switch mode {
                case "light": window?.appearance = NSAppearance(named: .aqua)
                case "dark": window?.appearance = NSAppearance(named: .darkAqua)
                default: window?.appearance = nil
                }
            }
        }
    }
#endif
