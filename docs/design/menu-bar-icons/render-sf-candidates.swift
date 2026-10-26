import AppKit
let pairs = [
    ("A  高低相位", "简洁、抽象，优先推荐", "circle.tophalf.filled", "circle.bottomhalf.filled"),
    ("B  高低刻度", "更直观，略像仪表盘", "gauge.with.dots.needle.67percent", "gauge.with.dots.needle.33percent"),
    ("C  上下方向", "醒目，但容易理解为涨跌", "arrow.up.circle.fill", "arrow.down.circle.fill"),
    ("D  价格加减", "实心饱满，容易理解为操作", "plus.circle.fill", "minus.circle.fill"),
    ("E  统一时钟", "图标固定，状态交给文字", "clock.fill", "clock.fill"),
]
let size = NSSize(width: 780, height: 590)
let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1560,pixelsHigh:1180,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
rep.size=size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
let cg=NSGraphicsContext.current!.cgContext
cg.translateBy(x:0,y:size.height); cg.scaleBy(x:1,y:-1)
NSGraphicsContext.current=NSGraphicsContext(cgContext:cg,flipped:true)
NSColor(calibratedWhite:0.08,alpha:1).setFill(); NSRect(origin:.zero,size:size).fill()
func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ font:CGFloat,_ color:NSColor = .white) {
 s.draw(at:NSPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:font,weight:.medium),.foregroundColor:color])
}
func draw(_ image:NSImage,_ rect:NSRect) {
 let ratio=min(rect.width/image.size.width,rect.height/image.size.height)
 let s=NSSize(width:image.size.width*ratio,height:image.size.height*ratio)
 image.draw(in:NSRect(x:rect.midX-s.width/2,y:rect.midY-s.height/2,width:s.width,height:s.height),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
}
text("谷蹬 · SF Symbols 成对候选",24,18,20)
text("每侧：放大轮廓 + 21×16pt原尺寸与文案  ／  Semibold · 单色",24,50,11,.lightGray)
for (i,pair) in pairs.enumerated() {
 let y=CGFloat(90+i*96)
 text(pair.0,24,y+9,15)
 text(pair.1,24,y+37,10,.lightGray)
 for j in 0..<2 {
  let x=CGFloat(222+j*272)
  let name=j == 0 ? pair.2 : pair.3
  let color:NSColor=j == 0 ? .systemOrange : .systemGreen
  let config=NSImage.SymbolConfiguration(pointSize:16,weight:.semibold).applying(.preferringMonochrome())
  guard let source=NSImage(systemSymbolName:name,accessibilityDescription:nil)?.withSymbolConfiguration(config) else {fatalError("Missing \(name)")}
  let image=NSImage(size:source.size,flipped:true) { rect in
   // Half-circle images need their semantic top/bottom orientation preserved in this flipped canvas.
   source.draw(in:rect,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:!name.hasPrefix("circle."),hints:nil)
   color.setFill(); rect.fill(using:.sourceIn)
   return true
  }
  draw(image,NSRect(x:x,y:y,width:46,height:42))
  draw(image,NSRect(x:x+63,y:y+13,width:21,height:16))
  text(j == 0 ? "峰 · 2小时" : "谷 · 13小时38分",x+89,y+13,12)
  text(name,x,y+56,9,.lightGray)
 }
 NSColor(calibratedWhite:0.24,alpha:1).setFill()
 NSRect(x:24,y:y+84,width:732,height:0.5).fill()
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
