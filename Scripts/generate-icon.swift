import AppKit
import Foundation

// Renders the 1024pt source artwork for the macOS app icon. The shell wrapper
// downsamples it into the required AppIcon sizes. No text is used so the mark
// stays legible at 16pt.
//
// Left = peak (warm orange), right = valley (mint), with cream clock hands at
// 9:00 — the start of the first weekday peak window.

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

let plateRect = NSRect(x: 64, y: 64, width: 896, height: 896)
let plate = NSBezierPath(roundedRect: plateRect, xRadius: 204, yRadius: 204)
NSColor(hex: "#242629").setFill()
plate.fill()

NSColor.white.withAlphaComponent(0.07).setStroke()
plate.lineWidth = 6
plate.stroke()

let circleRect = NSRect(x: 214, y: 214, width: 596, height: 596)
let circle = NSBezierPath(ovalIn: circleRect)

NSGraphicsContext.saveGraphicsState()
circle.addClip()
NSColor(hex: "#E9B47E").setFill()
NSRect(
    x: circleRect.minX,
    y: circleRect.minY,
    width: circleRect.width / 2,
    height: circleRect.height
).fill()
NSColor(hex: "#8ACEB4").setFill()
NSRect(
    x: circleRect.midX,
    y: circleRect.minY,
    width: circleRect.width / 2,
    height: circleRect.height
).fill()
NSGraphicsContext.restoreGraphicsState()

NSColor(hex: "#FDFDFD").withAlphaComponent(0.92).setStroke()
circle.lineWidth = 10
circle.stroke()

let center = NSPoint(x: 512, y: 512)

func hand(to point: NSPoint, width: CGFloat) {
    let path = NSBezierPath()
    path.move(to: center)
    path.line(to: point)
    path.lineWidth = width
    path.lineCapStyle = .round
    NSColor(hex: "#FDFDFD").setStroke()
    path.stroke()
}

// Minute hand up, hour hand left: 9:00, the first weekday peak boundary.
hand(to: NSPoint(x: 512, y: 724), width: 20)
hand(to: NSPoint(x: 300, y: 512), width: 28)

let hub = NSBezierPath(ovalIn: NSRect(x: center.x - 24, y: center.y - 24, width: 48, height: 48))
NSColor(hex: "#FDFDFD").setFill()
hub.fill()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("无法编码 PNG")
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = root.appendingPathComponent("Apps/Mac/Sources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try png.write(to: outputDirectory.appendingPathComponent("icon_1024x1024.png"))
print("已生成 \(outputDirectory.appendingPathComponent("icon_1024x1024.png").path)")
