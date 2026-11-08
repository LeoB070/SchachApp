import AppKit
import Foundation

// swift Scripts/BoardAssetChecks.swift [resource directory]
let resources = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Sources/ChessAppKit/Resources/Chessnut")
for palette in ["classic", "walnut", "ocean"] {
    for color in ["w", "b"] {
        for piece in ["P", "N", "B", "R", "Q", "K"] {
            let url = resources.appendingPathComponent("chessnut-\(palette)-\(color)\(piece).png")
            guard let image = NSImage(contentsOf: url),
                  let data = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: data) else {
                fatalError("Missing or unreadable chess image: \(url.path)")
            }
            precondition(bitmap.pixelsWide == 256 && bitmap.pixelsHigh == 256)
            precondition(bitmap.hasAlpha, "Chess image must have a transparent background")
            precondition(bitmap.colorAt(x: 0, y: 0)!.alphaComponent == 0)
            var filledPixels = 0
            var brightness = 0.0
            for y in stride(from: 0, to: 256, by: 4) {
                for x in stride(from: 0, to: 256, by: 4) {
                    let pixel = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                    if pixel.alphaComponent > 0.9 {
                        filledPixels += 1
                        brightness += (pixel.redComponent + pixel.greenComponent + pixel.blueComponent) / 3
                    }
                }
            }
            precondition(filledPixels > 600, "Piece silhouette must be filled: \(url.lastPathComponent)")
            brightness /= Double(filledPixels)
            precondition(color == "w" ? brightness > 0.50 : brightness < 0.45,
                         "Opposing piece colors must remain clearly distinct: \(url.lastPathComponent)")
        }
    }
}
print("36 chess images decoded: size, transparency, filled interiors and opposing colors passed")
