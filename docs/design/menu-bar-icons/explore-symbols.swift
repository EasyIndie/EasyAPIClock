import AppKit

// Standalone concept sheet; no production UI or preferences are changed.
func symbol(_ concept: Int, peak: Bool) -> NSImage {
    let image = NSImage(size: NSSize(width: 21, height: 16), flipped: true) { _ in
        let color = peak ? NSColor.systemOrange : NSColor.systemGreen
        color.setStroke()
        color.setFill()
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: x, y: peak ? y : 16 - y)
        }
        func stroke(_ path: NSBezierPath, _ width: CGFloat) {
            path.lineWidth = width
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
        if concept == 0 {
            let ring = NSBezierPath()
            ring.move(to: NSPoint(x: 16, y: 3.5))
            ring.curve(to: NSPoint(x: 10.5, y: 1), controlPoint1: NSPoint(x: 14.5, y: 1.8), controlPoint2: NSPoint(x: 12.7, y: 1))
            ring.curve(to: NSPoint(x: 3.5, y: 8), controlPoint1: NSPoint(x: 6.6, y: 1), controlPoint2: NSPoint(x: 3.5, y: 4.1))
            ring.curve(to: NSPoint(x: 10.5, y: 15), controlPoint1: NSPoint(x: 3.5, y: 11.9), controlPoint2: NSPoint(x: 6.6, y: 15))
            ring.curve(to: NSPoint(x: 16, y: 12.5), controlPoint1: NSPoint(x: 12.7, y: 15), controlPoint2: NSPoint(x: 14.5, y: 14.2))
            stroke(ring, 1.6)
            let wave = NSBezierPath()
            wave.move(to: p(6, 10))
            wave.curve(to: p(10.5, 5), controlPoint1: p(7.5, 10), controlPoint2: p(8, 5))
            wave.curve(to: p(15, 10), controlPoint1: p(13, 5), controlPoint2: p(13.5, 10))
            stroke(wave, 2.2)
            NSBezierPath(ovalIn: NSRect(x: 8.75, y: peak ? 3.25 : 9.25, width: 3.5, height: 3.5)).fill()
            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: 18, y: 8)); tick.line(to: NSPoint(x: 20, y: 8))
            stroke(tick, 1.8)
        } else if concept == 1 {
            let brackets = NSBezierPath()
            brackets.move(to: NSPoint(x: 5, y: 2)); brackets.line(to: NSPoint(x: 2, y: 2)); brackets.line(to: NSPoint(x: 2, y: 14)); brackets.line(to: NSPoint(x: 5, y: 14))
            brackets.move(to: NSPoint(x: 16, y: 2)); brackets.line(to: NSPoint(x: 19, y: 2)); brackets.line(to: NSPoint(x: 19, y: 14)); brackets.line(to: NSPoint(x: 16, y: 14))
            stroke(brackets, 1.8)
            let step = NSBezierPath()
            step.move(to: p(6.5, 11)); step.line(to: p(6.5, 5)); step.line(to: p(14.5, 5)); step.line(to: p(14.5, 11))
            stroke(step, 2.7)
        } else {
            let wave = NSBezierPath()
            wave.move(to: p(1.5, 11)); wave.line(to: p(4, 11))
            wave.curve(to: p(10.5, 4), controlPoint1: p(6.5, 11), controlPoint2: p(6.5, 4))
            wave.curve(to: p(17, 11), controlPoint1: p(14.5, 4), controlPoint2: p(14.5, 11))
            wave.line(to: p(19.5, 11))
            stroke(wave, 2.8)
            NSBezierPath(ovalIn: NSRect(x: 8.25, y: peak ? 1.75 : 9.75, width: 4.5, height: 4.5)).fill()
        }
        return true
    }
    image.isTemplate = false
    return image
}
let symbols = (0..<3).map { [symbol($0, peak: true), symbol($0, peak: false)] }
let size = NSSize(width: 720, height: 420)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1440, pixelsHigh: 840, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let cg = NSGraphicsContext.current!.cgContext
cg.translateBy(x: 0, y: size.height); cg.scaleBy(x: 1, y: -1)
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
NSColor(calibratedWhite: 0.08, alpha: 1).setFill(); NSRect(origin: .zero, size: size).fill()
func text(_ value: String, x: CGFloat, y: CGFloat, size: CGFloat, color: NSColor = .white) {
    value.draw(at: NSPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color])
}
text("谷蹬 · 价格时段的专属符号", x: 24, y: 18, size: 19)
text("原尺寸 21×16pt · 放大 3× · 黑白轮廓", x: 24, y: 48, size: 11, color: .lightGray)
let names = ["A  相位环", "B  时隙", "C  谷弦"]
let descriptions = ["时钟 × 峰谷相位", "时间窗口 × 高低价台阶", "价格曲线 × 当前落点"]
for row in 0..<3 {
    let y = CGFloat(88 + row * 108)
    text(names[row], x: 24, y: y + 7, size: 16)
    text(descriptions[row], x: 24, y: y + 34, size: 11, color: .lightGray)
    for column in 0..<2 {
        let image = symbols[row][column]
        let x = CGFloat(220 + column * 190)
        image.draw(in: NSRect(x: x, y: y + 2, width: 21, height: 16), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        text(column == 0 ? "峰 · 2小时" : "谷 · 13小时38分", x: x + 26, y: y + 1, size: 12)
        image.draw(in: NSRect(x: x, y: y + 32, width: 63, height: 48), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        let mono = NSImage(size: image.size, flipped: true) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            NSColor.white.setFill(); rect.fill(using: .sourceIn)
            return true
        }
        mono.draw(in: NSRect(x: x + 85, y: y + 45, width: 21, height: 16), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
