import Foundation
import ChessAppKit

/// Zustandsmaschine für eine lokale Partie (zwei Menschen am selben Gerät).
@Observable
@MainActor
final class PlayViewModel {
    var positions: [Position] = []
    var sans: [String] = []
    var selectedSquare: Square? = nil
    var legalTargets: Set<Square> = []
    var lastMove: Move? = nil
    var orientation: Color = .white
    var pendingPromotion: (from: Square, to: Square)? = nil

    var currentPosition: Position { positions.last! }

    init() {
        newGame()
    }

    var statusText: String {
        let pos = currentPosition
        let outcome = evaluate(pos: pos)
        switch outcome {
        case .checkmate(let winner):
            return "Matt – \(winner == .white ? "Schwarz" : "Weiß") gewinnt"
        case .stalemate:
            return "Patt – Remis"
        case .threefold:
            return "Dreifache Wiederholung – Remis"
        case .fiftyMove:
            return "50-Züge-Regel – Remis"
        case .insufficientMaterial:
            return "Ungenügendes Material – Remis"
        case .ongoing:
            return "\(currentPosition.turn == .white ? "Weiß" : "Schwarz") am Zug"
        }
    }

    func newGame() {
        do {
            let start = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
            positions = [start]
            sans = []
            selectedSquare = nil
            legalTargets = []
            lastMove = nil
            pendingPromotion = nil
        } catch {
            // Start-FEN ist immer gültig; hier nie erreicht.
        }
    }

    func flipBoard() {
        orientation = orientation == .white ? .black : .white
    }

    func squareTapped(_ square: Square) {
        guard pendingPromotion == nil else { return }

        let pos = currentPosition

        // Erster Klick: eigene Figur wählen / erneut klicken zum Deselect.
        if let selected = selectedSquare, selected == square {
            self.selectedSquare = nil
            self.legalTargets = []
            return
        }

        if let piece = pos.board[square.index], piece.color == pos.turn {
            selectedSquare = square
            legalTargets = Set(pos.legalMoves().filter { $0.from == square }.map { $0.to })
            return
        }

        // Zweiter Klick: legales Zielfeld.
        if let selected = selectedSquare, legalTargets.contains(square) {
            if let move = pos.move(from: selected, to: square) {
                if move.promotion != nil {
                    pendingPromotion = (selected, square)
                    return
                }
                apply(move)
            }
        }
    }

    func promote(to type: PieceType) {
        guard let (from, to) = pendingPromotion else { return }
        pendingPromotion = nil
        if let move = currentPosition.move(from: from, to: to, promotion: type) {
            apply(move)
        }
    }

    func cancelPromotion() {
        pendingPromotion = nil
    }

    private func apply(_ move: Move) {
        let pos = currentPosition
        let newPos = pos.make(move)
        sans.append(SAN.notation(for: move, in: pos))
        positions.append(newPos)
        lastMove = move
        selectedSquare = nil
        legalTargets = []
    }

    private func evaluate(pos: Position) -> GameOutcome {
        let count = positions.filter { $0.repetitionKey == pos.repetitionKey }.count
        return GameOutcome.evaluate(position: pos, repetitionCount: count)
    }
}
