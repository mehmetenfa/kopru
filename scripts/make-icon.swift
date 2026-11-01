// Kullanım: swift scripts/make-icon.swift <çıktı.png>  — 1024px köprü logosu
import AppKit
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
let rect = CGRect(x: 40, y: 40, width: size-80, height: size-80)
let bg = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
bg.addClip()
NSGradient(colors: [NSColor(red: 0.08, green: 0.55, blue: 0.95, alpha: 1), NSColor(red: 0.30, green: 0.18, blue: 0.80, alpha: 1)])!.draw(in: rect, angle: -60)
ctx.setStrokeColor(NSColor.white.cgColor); ctx.setLineCap(.round)
// köprü kemeri
ctx.setLineWidth(46)
ctx.move(to: CGPoint(x: 190, y: 400)); ctx.addQuadCurve(to: CGPoint(x: 834, y: 400), control: CGPoint(x: 512, y: 900)); ctx.strokePath()
// tabliye
ctx.setLineWidth(56); ctx.move(to: CGPoint(x: 150, y: 400)); ctx.addLine(to: CGPoint(x: 874, y: 400)); ctx.strokePath()
// askılar
ctx.setLineWidth(26)
for x in stride(from: 300, through: 724, by: 106) {
    let t = (x - 190) / 644
    let y = 400 + 4 * t * (1 - t) * 250  // kemer yüksekliği
    ctx.move(to: CGPoint(x: x, y: 400)); ctx.addLine(to: CGPoint(x: x, y: y)); ctx.strokePath()
}
// ayaklar
ctx.setLineWidth(46); for x in [260.0, 764.0] { ctx.move(to: CGPoint(x: x, y: 372)); ctx.addLine(to: CGPoint(x: x, y: 230)); ctx.strokePath() }
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
