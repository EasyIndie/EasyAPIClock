import AppKit
let base = NSImage.SymbolConfiguration(pointSize:16,weight:.semibold)
let configs:[(String,NSImage.SymbolConfiguration)] = [
("palette",base.applying(.init(paletteColors:[.systemGreen]))),
("palette-mono",base.applying(.init(paletteColors:[.systemGreen])).applying(.preferringMonochrome())),
("mono-palette",base.applying(.preferringMonochrome()).applying(.init(paletteColors:[.systemGreen]))),
("two-palette",base.applying(.init(paletteColors:[.black,.systemGreen])))
]
for (name,config) in configs {
 let symbol = NSImage(systemSymbolName:"arrow.down.circle.fill",accessibilityDescription:nil)!.withSymbolConfiguration(config)!
 let canvas = NSImage(size:NSSize(width:80,height:50))
 canvas.lockFocus(); NSColor.darkGray.setFill(); NSRect(x:0,y:0,width:80,height:50).fill();symbol.draw(at:NSPoint(x:20,y:15),from:.zero,operation:.sourceOver,fraction:1); canvas.unlockFocus()
 let rep = NSBitmapImageRep(data:canvas.tiffRepresentation!)!;try! rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"/tmp/gudeng-\(name).png"))
 print(name,symbol.size,symbol.alignmentRect)
}
