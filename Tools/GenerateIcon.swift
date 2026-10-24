// Original code-drawn Meetrail icon. No imported artwork.
import AppKit
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let entries: [(Int, Int)] = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
var images: [[String:String]] = []
for (points, scale) in entries {
    let pixels = points * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let factor = CGFloat(pixels) / 1024
    let transform = NSAffineTransform(); transform.scale(by: factor); transform.concat()
    NSColor(red: 0.72, green: 0.28, blue: 0.12, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 32,y: 32,width: 960,height: 960), xRadius: 216,yRadius: 216).fill()
    NSColor.white.setStroke()
    let paper = NSBezierPath(roundedRect: NSRect(x: 260,y: 210,width: 504,height: 604), xRadius: 56,yRadius: 56)
    paper.lineWidth = 38; paper.stroke()
    for y in [CGFloat(640),480,320] {
        let dot = NSBezierPath(ovalIn: NSRect(x: 340,y: y-18,width: 36,height: 36)); NSColor.white.setFill(); dot.fill()
        let line = NSBezierPath(); line.move(to: NSPoint(x: 416,y:y)); line.line(to: NSPoint(x: 660,y:y)); line.lineWidth = 36; line.lineCapStyle = .round; line.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    let filename = "icon-\(points)@\(scale)x.png"
    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(filename))
    images.append(["idiom":"mac","size":"\(points)x\(points)","scale":"\(scale)x","filename":filename])
}
let json: [String:Any] = ["images": images, "info": ["author":"xcode","version":1]]
try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted,.sortedKeys]).write(to: directory.appendingPathComponent("Contents.json"))
