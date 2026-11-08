import SwiftUI
import ChessAppKit

/// Lokale Chessnut-Bilder; auch Umwandlung und Vorschau verwenden dieselben Motive.
struct PieceView: View {
    let piece: Piece
    var side: CGFloat = 44
    @AppStorage("pieceTheme") private var pieceTheme = "Klassisch"

    init(piece: Piece, side: CGFloat = 44) {
        self.piece = piece
        self.side = side
    }

    init(color: PieceColor, type: PieceType, side: CGFloat = 44) {
        self.piece = Piece(color: color, type: type)
        self.side = side
    }

    private var palette: String {
        switch pieceTheme {
        case "Walnuss": return "walnut"
        case "Ozean": return "ocean"
        default: return "classic"
        }
    }

    private static let images: [String: NSImage] = {
        let urls = ChessAppKitInfo.resourceBundle.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? []
        return Dictionary(uniqueKeysWithValues: urls.compactMap { url in
            guard url.lastPathComponent.hasPrefix("chessnut-"),
                  let image = NSImage(contentsOf: url) else { return nil }
            return (url.deletingPathExtension().lastPathComponent, image)
        })
    }()

    var body: some View {
        let name = "chessnut-\(palette)-\(piece.color.rawValue)\(piece.type.fenChar)"
        // Raw SwiftPM PNGs need URL loading; named SwiftUI images expect an asset catalog.
        let image = Self.images[name] ?? NSImage(systemSymbolName: "questionmark.square", accessibilityDescription: "Figurenbild fehlt")!
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}
