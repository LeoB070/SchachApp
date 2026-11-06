import SwiftUI
import ChessAppKit

/// Schach-Figur als Unicode-Symbol (später durch Asset-Bilder austauschbar).
struct PieceView: View {
    let piece: Piece
    var side: CGFloat = 44

    init(piece: Piece, side: CGFloat = 44) {
        self.piece = piece
        self.side = side
    }

    init(color: PieceColor, type: PieceType, side: CGFloat = 44) {
        self.piece = Piece(color: color, type: type)
        self.side = side
    }

    var body: some View {
        Text(symbol(for: piece))
            .font(.system(size: side, weight: .bold))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }

    private func symbol(for piece: Piece) -> String {
        let white = ["♙", "♘", "♗", "♖", "♕", "♔"]
        let black = ["♟", "♞", "♝", "♜", "♛", "♚"]
        let set = piece.color == .white ? white : black
        let all = PieceType.allCases
        if let idx = all.firstIndex(of: piece.type) {
            return set[idx]
        }
        return "?"
    }
}
