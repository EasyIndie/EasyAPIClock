#if os(macOS)
    import AppKit

    /// Native filled arrows indicate the current high/low price state.
    @MainActor
    enum MenuBarStatusIcon {
        static let peak = makeImage(name: "arrow.up.circle.fill", color: .systemOrange)
        static let valley = makeImage(name: "arrow.down.circle.fill", color: .systemGreen)

        private static func makeImage(name: String, color: NSColor) -> NSImage {
            let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
                .applying(.preferringMonochrome())
            let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration)
            let image = NSImage(size: NSSize(width: 21, height: 16), flipped: true) { rect in
                guard let symbol else { return false }
                let scale = min(rect.width / symbol.size.width, rect.height / symbol.size.height)
                let size = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
                let destination = NSRect(
                    x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                    width: size.width, height: size.height)
                symbol.draw(
                    in: destination, from: .zero, operation: .sourceOver, fraction: 1,
                    respectFlipped: true, hints: nil)
                color.setFill()
                rect.fill(using: .sourceIn)
                return true
            }
            image.isTemplate = false
            return image
        }
    }
#endif
