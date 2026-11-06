import SwiftUI
import ChessAppKit

/// Schach-Figur als Unicode-Symbol (später durch Asset-Bilder austauschbar).
struct PieceView: View {
    let piece: Piece

    var body: some View {
        Text(symbol(for: piece))
            .font(.system(size: 44, weight: .bold))
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

/// Umwandlungs-Dialog, wenn ein Bauer die letzte Reihe erreicht.
struct PromotionPicker: View {
    let pieceColor: Color
    let onSelect: (PieceType) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Umwandlung wählen").font(.headline)
            HStack(spacing: 16) {
                ForEach([PieceType.queen, .rook, .bishop, .knight], id: \.self) { type in
                    Button(action: { onSelect(type) }) {
                        PieceView(piece: Piece(color: pieceColor, type: type))
                            .frame(width: 60, height: 60)
                            .background(SwiftUI.Color.white.opacity(0.9))
                            .cornerRadius(8)
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                }
                Button("Abbrechen", action: onCancel)
            }
        }
        .padding(24)
        .background(SwiftUI.Color(.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SwiftUI.Color.black.opacity(0.35))
    }
}
