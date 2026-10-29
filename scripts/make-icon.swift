import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let background = NSBezierPath(roundedRect: NSRect(x: 36, y: 36, width: 952, height: 952), xRadius: 218, yRadius: 218)
        NSGradient(starting: NSColor(red: 0.07, green: 0.32, blue: 0.28, alpha: 1), ending: NSColor(red: 0.025, green: 0.15, blue: 0.15, alpha: 1))!.draw(in: background, angle: -90)
        context.saveGState()
        context.translateBy(x: 512, y: 512)
        context.rotate(by: -0.17)
        NSColor(red: 0.89, green: 0.74, blue: 0.44, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: -270, y: -325, width: 470, height: 650), xRadius: 42, yRadius: 42).fill()
        context.restoreGState()
        NSColor(red: 0.99, green: 0.98, blue: 0.94, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 310, y: 180, width: 470, height: 650), xRadius: 42, yRadius: 42).fill()
        let ink = NSColor(red: 0.06, green: 0.23, blue: 0.21, alpha: 1)
        ("A" as NSString).draw(at: NSPoint(x: 349, y: 686), withAttributes: [.font: NSFont.systemFont(ofSize: 102, weight: .medium), .foregroundColor: ink])
        ("♣" as NSString).draw(at: NSPoint(x: 388, y: 315), withAttributes: [.font: NSFont.systemFont(ofSize: 300), .foregroundColor: ink])
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
