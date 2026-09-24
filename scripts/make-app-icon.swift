import AppKit
import CoreGraphics
import Foundation

let output = CommandLine.arguments.dropFirst().first ?? "resources/settime.iconset"
let iconset = URL(fileURLWithPath: output, isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func drawIcon(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "SettimeIcon", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let cg = context.cgContext
    let scale = CGFloat(size) / 1024
    cg.scaleBy(x: scale, y: scale)
    cg.setAllowsAntialiasing(true)
    cg.setShouldAntialias(true)
    cg.setLineCap(.round)
    cg.setLineJoin(.round)

    cg.setFillColor(color(0.075, 0.12, 0.15))
    cg.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    // Small crown and short neck make the clock read as a timer at icon size.
    cg.setFillColor(color(0.24, 0.38, 0.39))
    cg.addPath(CGPath(roundedRect: CGRect(x: 474, y: 726, width: 76, height: 82), cornerWidth: 24, cornerHeight: 24, transform: nil))
    cg.fillPath()
    cg.setFillColor(color(0.46, 0.92, 0.72))
    cg.addPath(CGPath(roundedRect: CGRect(x: 454, y: 790, width: 116, height: 34), cornerWidth: 17, cornerHeight: 17, transform: nil))
    cg.fillPath()

    let center = CGPoint(x: 512, y: 500)
    let radius: CGFloat = 248
    let ring = CGMutablePath()
    ring.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                               width: radius * 2, height: radius * 2))
    cg.setStrokeColor(color(0.57, 0.79, 0.74, 0.17))
    cg.setLineWidth(30)
    cg.addPath(ring)
    cg.strokePath()

    // A 300-degree mint arc leaves a deliberate opening at the upper right.
    let arc = CGMutablePath()
    arc.addArc(center: center, radius: radius, startAngle: -.pi / 2,
               endAngle: .pi * 7 / 6, clockwise: false)
    cg.setStrokeColor(color(0.46, 0.94, 0.72))
    cg.setLineWidth(30)
    cg.addPath(arc)
    cg.strokePath()

    let faceRadius: CGFloat = 197
    cg.setFillColor(color(0.055, 0.092, 0.105))
    cg.fillEllipse(in: CGRect(x: center.x - faceRadius, y: center.y - faceRadius,
                              width: faceRadius * 2, height: faceRadius * 2))
    cg.setStrokeColor(color(0.75, 0.91, 0.86, 0.16))
    cg.setLineWidth(3)
    cg.strokeEllipse(in: CGRect(x: center.x - faceRadius, y: center.y - faceRadius,
                                width: faceRadius * 2, height: faceRadius * 2))

    cg.setStrokeColor(color(0.92, 0.98, 0.95))
    cg.setLineWidth(21)
    let minute = CGMutablePath()
    minute.move(to: center)
    minute.addLine(to: CGPoint(x: 512, y: 640))
    cg.addPath(minute)
    cg.strokePath()

    let hour = CGMutablePath()
    hour.move(to: center)
    hour.addLine(to: CGPoint(x: 414, y: 452))
    cg.addPath(hour)
    cg.strokePath()

    cg.setFillColor(color(0.46, 0.94, 0.72))
    cg.fillEllipse(in: CGRect(x: 492, y: 480, width: 40, height: 40))
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SettimeIcon", code: 2)
    }
    return data
}

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, size) in variants {
    try drawIcon(size: size).write(to: iconset.appendingPathComponent(name), options: .atomic)
}
let extensionIcons = [("icon16.png", 16), ("icon32.png", 32), ("icon48.png", 48), ("icon128.png", 128)]
let extensionDirectory = iconset.deletingLastPathComponent().deletingLastPathComponent()
for (name, size) in extensionIcons {
    try drawIcon(size: size).write(to: extensionDirectory.appendingPathComponent("browser-extension").appendingPathComponent(name), options: .atomic)
}

let catalog: [[String: String]] = [
    ["filename": "icon_16x16.png", "idiom": "mac", "scale": "1x", "size": "16x16"],
    ["filename": "icon_16x16@2x.png", "idiom": "mac", "scale": "2x", "size": "16x16"],
    ["filename": "icon_32x32.png", "idiom": "mac", "scale": "1x", "size": "32x32"],
    ["filename": "icon_32x32@2x.png", "idiom": "mac", "scale": "2x", "size": "32x32"],
    ["filename": "icon_128x128.png", "idiom": "mac", "scale": "1x", "size": "128x128"],
    ["filename": "icon_128x128@2x.png", "idiom": "mac", "scale": "2x", "size": "128x128"],
    ["filename": "icon_256x256.png", "idiom": "mac", "scale": "1x", "size": "256x256"],
    ["filename": "icon_256x256@2x.png", "idiom": "mac", "scale": "2x", "size": "256x256"],
    ["filename": "icon_512x512.png", "idiom": "mac", "scale": "1x", "size": "512x512"],
    ["filename": "icon_512x512@2x.png", "idiom": "mac", "scale": "2x", "size": "512x512"]
]
let json: [String: Any] = ["images": catalog, "info": ["author": "xcode", "version": 1]]
let metadata = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
try metadata.write(to: iconset.appendingPathComponent("Contents.json"), options: .atomic)

func appendBigEndian(_ value: UInt32, to data: inout Data) {
    data.append(UInt8((value >> 24) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8(value & 0xff))
}

let chunks: [(String, String)] = [
    ("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"), ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]
var payload = Data()
for (type, filename) in chunks {
    let image = try Data(contentsOf: iconset.appendingPathComponent(filename))
    payload.append(contentsOf: type.utf8)
    appendBigEndian(UInt32(image.count + 8), to: &payload)
    payload.append(image)
}
var icns = Data("icns".utf8)
appendBigEndian(UInt32(payload.count + 8), to: &icns)
icns.append(payload)
try icns.write(to: iconset.deletingLastPathComponent().appendingPathComponent("settime.icns"), options: .atomic)
