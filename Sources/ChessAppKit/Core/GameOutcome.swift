import Foundation

/// Ausgang einer Partie nach den Regel-Enden.
public enum GameOutcome: Equatable {
    case checkmate(winner: Color)
    case stalemate
    case threefold
    case fiftyMove
    case insufficientMaterial
    case ongoing

    /// Bewertet eine Stellung. Wiederholungen zählt der Aufrufer und reicht `repetitionCount` rein.
    /// Reihenfolge: Matt > Patt > ungenügendes Material > 3-fach (count >= 3) > 50 Züge.
    public static func evaluate(position: Position, repetitionCount: Int) -> GameOutcome {
        if position.isCheckmate {
            return .checkmate(winner: position.turn.flipped)
        }
        if position.isStalemate {
            return .stalemate
        }
        if position.hasInsufficientMaterial() {
            return .insufficientMaterial
        }
        if repetitionCount >= 3 {
            return .threefold
        }
        if position.halfmoveClock >= 100 {
            return .fiftyMove
        }
        return .ongoing
    }
}
