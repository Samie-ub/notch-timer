import AppKit
import CoreGraphics

// A mint target matches the app's SF Symbol `scope` at toolbar sizes.
let directory = URL(fileURLWithPath: "browser-extension", isDirectory: true)
for size in [16, 32, 48, 128] {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Cannot create Focus Mode icon bitmap")
    }
    let cg = context.cgContext
    let scale = CGFloat(size) / 64
    cg.scaleBy(x: scale, y: scale)
    cg.setFillColor(CGColor(red: 0.075, green: 0.12, blue: 0.15, alpha: 1))
    cg.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 64, height: 64),
                      cornerWidth: 14, cornerHeight: 14, transform: nil))
    cg.fillPath()
    let mint = CGColor(red: 0.47, green: 0.93, blue: 0.73, alpha: 1)
    cg.setStrokeColor(mint)
    cg.setFillColor(mint)
    cg.setLineWidth(3.5)
    cg.setLineCap(.round)
    cg.strokeEllipse(in: CGRect(x: 15, y: 15, width: 34, height: 34))
    for (start, end) in [(CGPoint(x: 32, y: 9), CGPoint(x: 32, y: 20)),
                         (CGPoint(x: 32, y: 44), CGPoint(x: 32, y: 55)),
                         (CGPoint(x: 9, y: 32), CGPoint(x: 20, y: 32)),
                         (CGPoint(x: 44, y: 32), CGPoint(x: 55, y: 32))] {
        cg.move(to: start)
        cg.addLine(to: end)
        cg.strokePath()
    }
    cg.fillEllipse(in: CGRect(x: 27, y: 27, width: 10, height: 10))
    context.flushGraphics()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Cannot encode Focus Mode icon")
    }
    try data.write(to: directory.appendingPathComponent("icon\(size).png"), options: .atomic)
}
