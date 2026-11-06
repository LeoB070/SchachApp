import Foundation

/// Win probability calculation based on the official Lichess mathematical model.
public enum WinProbability {
    /// Exact constant used in the Lichess winning chances formula.
    public static let lichessMultiplier: Double = -0.00368208

    /// Calculates winning probability (0.0% to 100.0%) from centipawns (cp).
    /// - Parameter cp: Advantage in centipawns from the perspective of the player
    ///   (positive = advantage, negative = disadvantage).
    public static func winPercent(cp: Double) -> Double {
        let exponent = lichessMultiplier * cp
        let term = 2.0 / (1.0 + exp(exponent)) - 1.0
        return 50.0 + 50.0 * term
    }

    /// Calculates winning probability when a checkmate is on the board or forced.
    /// - Parameters:
    ///   - mateIn: Distance to mate. Positive means side to move (or favored side) delivers mate;
    ///             negative means side gets mated.
    ///   - forSideToMove: True if the perspective is the side with the mate announcement.
    public static func winPercent(mateIn: Int, forSideToMove: Bool) -> Double {
        if mateIn > 0 {
            return forSideToMove ? 100.0 : 0.0
        } else if mateIn < 0 {
            return forSideToMove ? 0.0 : 100.0
        } else {
            // Mate already delivered (0 plies left)
            return forSideToMove ? 100.0 : 0.0
        }
    }

    /// Calculates winning probability for a specific player (White or Black) given
    /// centipawn evaluation or mate distance normalized to White's perspective.
    /// - Parameters:
    ///   - evalCp: Evaluation in centipawns, normalized to White (positive = White leads).
    ///   - mateIn: Mate in N plies/moves, normalized to White (positive = White mates).
    ///   - player: Player for whom the win percentage is computed.
    public static func winPercent(evalCp: Int?, mateIn: Int?, for player: Color) -> Double {
        if let mate = mateIn {
            if player == .white {
                return mate > 0 ? 100.0 : (mate < 0 ? 0.0 : 100.0)
            } else {
                return mate < 0 ? 100.0 : (mate > 0 ? 0.0 : 100.0)
            }
        }

        if let cp = evalCp {
            let playerCp = (player == .white) ? Double(cp) : -Double(cp)
            return winPercent(cp: playerCp)
        }

        // Even position / lack of engine evaluation
        return 50.0
    }
}
