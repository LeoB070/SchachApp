import Foundation
import ChessAppKit

struct EndgameExercise: Identifiable {
    enum Goal { case checkmate, promotion }
    let id: String
    let title: String
    let fen: String
    let goal: Goal
    let advice: String

    static let all = [
        EndgameExercise(id: "rook", title: "Matt mit Turm", fen: "7k/8/5K2/8/8/8/8/R7 w - - 0 1", goal: .checkmate,
                        advice: "Dränge den König an den Rand. Dein König hilft dem Turm; vermeide Patt."),
        EndgameExercise(id: "queen", title: "Matt mit Dame", fen: "7k/8/5K2/8/8/8/8/Q7 w - - 0 1", goal: .checkmate,
                        advice: "Verkleinere den Raum des gegnerischen Königs. Lass ihm bis zum Matt einen legalen Zug."),
        EndgameExercise(id: "pawn", title: "Bauern umwandeln", fen: "8/4P2k/4K3/8/8/8/8/8 w - - 0 1", goal: .promotion,
                        advice: "Bringe deinen Bauern sicher auf die letzte Reihe. Probiere auch die Umwandlungsauswahl aus.")
    ]

    func goalReached(in position: Position, player: PieceColor) -> Bool {
        switch goal {
        case .checkmate: return position.isCheckmate && position.turn != player
        case .promotion:
            return (0..<8).contains { file in
                let index = (player == .white ? 7 : 0) * 8 + file
                guard let piece = position.board[index], piece.color == player else { return false }
                return piece.type != .king && piece.type != .pawn
            }
        }
    }
}
