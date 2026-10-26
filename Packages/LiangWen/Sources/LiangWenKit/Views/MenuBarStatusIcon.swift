#if os(macOS)
    import AppKit

    /// Preserve the native symbol alignment metrics instead of rasterizing into a custom canvas.
    @MainActor
    enum MenuBarStatusIcon {
        static let peak = makeImage(name: "arrow.up.circle.fill", color: .systemOrange)
        static let valley = makeImage(name: "arrow.down.circle.fill", color: .systemGreen)

        private static func makeImage(name: String, color: NSColor) -> NSImage {
            let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
                .applying(.preferringMonochrome())
            let image =
                NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration) ?? NSImage(size: NSSize(width: 16, height: 16))
            image.isTemplate = false
            return image
        }
    }
#endif
