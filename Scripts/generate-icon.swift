import AppKit
import Foundation

// Renders the 1024pt source artwork for the macOS app icon. The shell wrapper
// downsamples it into the required AppIcon sizes. No text is used so the mark
// stays legible at 16pt.
//
// A blue time orbit, mint valley and coral phase node convey the price clock.

extension NSColor {
    convenience init(hex: String) {
        var value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }
        let number = UInt64(value, radix: 16) ?? 0
        let red = CGFloat((number >> 16) & 0xFF) / 255
        let green = CGFloat((number >> 8) & 0xFF) / 255
        let blue = CGFloat(number & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}

let canvas = 1024
guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: canvas,
        pixelsHigh: canvas,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
else {
    fatalError("无法创建位图")
}
bitmap.size = NSSize(width: canvas, height: canvas)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: canvas, height: canvas).fill()

// A time orbit surrounds a soft valley; the coral node marks a changing price window.
// Original artwork, not the DeepSeek logo. Native paths stay crisp at small sizes.
let plateRect = NSRect(x: 64, y: 64, width: 896, height: 896)
let plate = NSBezierPath(roundedRect: plateRect, xRadius: 204, yRadius: 204)
NSGradient(starting: NSColor(hex: "#17275C"), ending: NSColor(hex: "#4C6CF0"))!
    .draw(in: plate, angle: 65)
NSColor.white.withAlphaComponent(0.12).setStroke()
plate.lineWidth = 5
plate.stroke()

let orbit = NSBezierPath()
orbit.appendArc(
    withCenter: NSPoint(x: 500, y: 514), radius: 278,
    startAngle: 40, endAngle: 320, clockwise: false)
orbit.lineWidth = 72
orbit.lineCapStyle = .round
NSColor(hex: "#F5F8FF").setStroke()
orbit.stroke()

let valley = NSBezierPath()
valley.move(to: NSPoint(x: 348, y: 582))
valley.curve(to: NSPoint(x: 500, y: 406), controlPoint1: NSPoint(x: 406, y: 440), controlPoint2: NSPoint(x: 436, y: 406))
valley.curve(to: NSPoint(x: 652, y: 582), controlPoint1: NSPoint(x: 564, y: 406), controlPoint2: NSPoint(x: 598, y: 460))
valley.lineWidth = 76
valley.lineCapStyle = .round
NSColor(hex: "#64E6CE").setStroke()
valley.stroke()

let node = NSBezierPath(ovalIn: NSRect(x: 737, y: 467, width: 94, height: 94))
NSColor(hex: "#FFAC83").setFill()
node.fill()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("无法编码 PNG")
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = root.appendingPathComponent("Apps/Mac/Sources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try png.write(to: outputDirectory.appendingPathComponent("icon_1024x1024.png"))
print("已生成 \(outputDirectory.appendingPathComponent("icon_1024x1024.png").path)")
