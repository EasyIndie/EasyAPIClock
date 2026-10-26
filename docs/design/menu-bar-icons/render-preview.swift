import AppKit

let peakImage = MenuBarStatusIcon.peak
let valleyImage = MenuBarStatusIcon.valley
let size = NSSize(width: 480, height: 180)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 960, pixelsHigh: 360, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let context = NSGraphicsContext.current!.cgContext
context.translateBy(x: 0, y: size.height)
context.scaleBy(x: 1, y: -1)
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
for (row, appearanceName) in [NSAppearance.Name.darkAqua, .aqua].enumerated() {
    let appearance = NSAppearance(named: appearanceName)!
    appearance.performAsCurrentDrawingAppearance {
        (row == 0 ? NSColor(calibratedWhite: 0.08, alpha: 1) : NSColor(calibratedWhite: 0.96, alpha: 1)).setFill()
        NSRect(x: 0, y: row * 90, width: 480, height: 90).fill()
        for (column, isPeak) in [true, false].enumerated() {
            let x = CGFloat(24 + column * 240)
            let y = CGFloat(row * 90 + 20)
            let image = isPeak ? peakImage : valleyImage
            image.draw(in: NSRect(x: x, y: y, width: 21, height: 16), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.labelColor]
            (isPeak ? "峰 · 2小时" : "谷 · 13小时38分").draw(at: NSPoint(x: x + 26, y: y - 1), withAttributes: attributes)
            image.draw(in: NSRect(x: x, y: y + 28, width: 42, height: 32), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
    }
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
