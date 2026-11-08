import AppKit
import SwiftUI
import ChessAppKit

@main
@MainActor
struct PieceRenderingChecks {
    static func main() {
        for color in PieceColor.allCases {
            for type in PieceType.allCases {
                let renderer = ImageRenderer(content: PieceView(color: color, type: type, side: 128))
                guard let image = renderer.nsImage,
                      let data = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: data) else {
                    fatalError("PieceView did not render \(color) \(type)")
                }
                var visiblePixels = 0
                for y in stride(from: 0, to: bitmap.pixelsHigh, by: 4) {
                    for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
                        if bitmap.colorAt(x: x, y: y)!.alphaComponent > 0.5 { visiblePixels += 1 }
                    }
                }
                precondition(visiblePixels > 100, "PieceView rendered an empty image: \(color) \(type)")
            }
        }
        print("12 actual PieceViews rendered visible chess images")
    }
}
