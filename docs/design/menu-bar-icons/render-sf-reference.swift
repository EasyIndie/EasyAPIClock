import AppKit
let size = NSSize(width: 720, height: 260)
let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1440,pixelsHigh:520,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
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
text("Apple SF Symbols · 系统原生渲染",24,16,19)
text("每组左：放大观察  ／  右：21×16pt菜单栏占位",24,46,11,.lightGray)
let candidates:[(String,NSFont.Weight,String)] = [("mountain.2.fill",.semibold,"Semibold · 推荐"),("mountain.2.fill",.black,"Black · 更厚重"),("mountain.2.circle.fill",.semibold,"圆形填充 · 对照")]
for (i,item) in candidates.enumerated() {
 let x=CGFloat(24+i*236)
 let config=NSImage.SymbolConfiguration(pointSize:16,weight:item.1).applying(NSImage.SymbolConfiguration(paletteColors:[.systemOrange])).applying(.preferringMonochrome())
 guard let image=NSImage(systemSymbolName:item.0,accessibilityDescription:nil)?.withSymbolConfiguration(config) else { fatalError("Missing symbol: \(item.0)") }
 draw(image,NSRect(x:x,y:88,width:105,height:80))
 draw(image,NSRect(x:x+146,y:120,width:21,height:16))
 text(item.0,x,188,12)
 text(item.2,x,214,11,.lightGray)
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
