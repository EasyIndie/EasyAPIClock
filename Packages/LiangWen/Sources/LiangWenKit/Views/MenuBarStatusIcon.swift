#if os(macOS)
    import AppKit

    /// Use the native symbol size with an optical correction for the Chinese status title.
    @MainActor
    enum MenuBarStatusIcon {
        static let peak = makeImage(name: "arrow.up.circle.fill", color: .systemOrange)
        static let valley = makeImage(name: "arrow.down.circle.fill", color: .systemGreen)

        private static func makeImage(name: String, color: NSColor) -> NSImage {
            let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
                .applying(.preferringMonochrome())
            guard
                let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                    .withSymbolConfiguration(configuration)
            else { return NSImage(size: NSSize(width: 20, height: 20)) }
            // MenuBarExtra ignores alignmentRect corrections when extracting its status image.
            // Keep the native canvas size and raise the drawn glyph by 1pt inside it instead.
            let image = NSImage(size: symbol.size, flipped: false) { rect in
                symbol.draw(
                    in: rect.offsetBy(dx: 0, dy: 1), from: .zero,
                    operation: .sourceOver, fraction: 1,
                    respectFlipped: true, hints: nil)
                return true
            }
            image.alignmentRect = symbol.alignmentRect
            image.isTemplate = false
            return image
        }
    }
#endif
