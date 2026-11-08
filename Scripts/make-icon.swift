// Rendert das App-Icon (Springer auf grünem Squircle) nach Resources/AppIcon.icns.
// Nutzung: swift Scripts/make-icon.swift
import AppKit

let knight = NSImage(contentsOfFile: "Sources/ChessAppKit/Resources/Chessnut/chessnut-classic-wN.png")!
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    // macOS-Raster: Icon-Körper 824/1024 mit Rand für den Schatten.
    let body = NSRect(x: s * 100 / 1024, y: s * 100 / 1024, width: s * 824 / 1024, height: s * 824 / 1024)
    let path = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = s * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    NSGraphicsContext.saveGraphicsState(); shadow.set()
    NSColor.black.setFill(); path.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState(); path.addClip()
    NSGradient(starting: NSColor(red: 0.36, green: 0.50, blue: 0.31, alpha: 1),
               ending: NSColor(red: 0.14, green: 0.22, blue: 0.13, alpha: 1))!.draw(in: body, angle: -90)
    // Dezentes 4×4-Schachbrettmuster im Hintergrund.
    let cell = body.width / 4
    NSColor.white.withAlphaComponent(0.06).setFill()
    for r in 0..<4 { for f in 0..<4 where (r + f) % 2 == 0 {
        NSRect(x: body.minX + CGFloat(f) * cell, y: body.minY + CGFloat(r) * cell, width: cell, height: cell).fill()
    } }
    NSGraphicsContext.restoreGraphicsState()
    let k = body.width * 0.66
    let pieceShadow = NSShadow()
    pieceShadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
    pieceShadow.shadowBlurRadius = s * 0.025
    pieceShadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    NSGraphicsContext.saveGraphicsState(); pieceShadow.set()
    knight.draw(in: NSRect(x: body.midX - k / 2, y: body.midY - k / 2, width: k, height: k))
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try! render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try! render(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! task.run(); task.waitUntilExit()
print(task.terminationStatus == 0 ? "Resources/AppIcon.icns erstellt" : "iconutil fehlgeschlagen")
