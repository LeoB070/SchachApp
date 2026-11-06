import Foundation

/// Einfache Zug-Accuracy und vorläufiger Durchschnitt pro Spieler.
public enum AccuracyCalculator {
    /// Lichess formula constant A.
    public static let constantA: Double = 103.1668
    /// Lichess formula exponential decay rate B.
    public static let decayRateB: Double = -0.04354
    /// Lichess formula constant C.
    public static let constantC: Double = 3.1669
    /// Kein zusätzlicher Bonus in der vorgegebenen Grundgerüst-Formel.
    public static let uncertaintyBonus: Double = 0.0

    /// Computes individual move accuracy from win probability loss.
    /// - Parameter loss: Win probability loss (0.0 to 100.0).
    /// - Returns: Move accuracy clamped to [0.0, 100.0].
    public static func moveAccuracy(loss: Double) -> Double {
        let clampedLoss = max(0.0, loss)
        let acc = constantA * exp(decayRateB * clampedLoss) - constantC
        return max(0.0, min(100.0, acc))
    }

    /// Computes individual move accuracy from before and after win percentages.
    /// - Parameters:
    ///   - winPercentBefore: Player's win probability before making the move.
    ///   - winPercentAfter: Player's win probability after making the move.
    /// - Returns: Move accuracy clamped to [0.0, 100.0].
    public static func moveAccuracy(winPercentBefore: Double, winPercentAfter: Double) -> Double {
        let loss = max(0.0, winPercentBefore - winPercentAfter)
        return moveAccuracy(loss: loss)
    }

    /// Vorläufig einfacher Durchschnitt der Zug-Accuracy eines Spielers.
    public static func gameAccuracy(for player: Color, moves: [MoveAnalysis]) -> Double {
        let playerMoves = moves.filter { move in
            if let pos = try? Position(fen: move.fenBefore) {
                return pos.turn == player
            }
            return (player == .white) ? (move.ply % 2 != 0) : (move.ply % 2 == 0)
        }

        guard !playerMoves.isEmpty else { return 100.0 }

        // TODO(CLAUDE): Gesamt-Accuracy exakt (volatilitätsgewichtetes und harmonisches Mittel).
        return playerMoves.reduce(0.0) { $0 + $1.accuracy } / Double(playerMoves.count)
    }
}
