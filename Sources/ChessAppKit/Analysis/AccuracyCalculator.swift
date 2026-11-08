import Foundation

/// Einfache Zug-Accuracy und vorläufiger Durchschnitt pro Spieler.
public enum AccuracyCalculator {
    /// Grobe Trainingsschätzung; keine offizielle oder kalibrierte Elo-Wertung.
    public static func estimatedElo(accuracy: Double, moveCount: Int, opponentElo: Int? = nil, opponentAccuracy: Double? = nil) -> Int? {
        guard moveCount >= 10, accuracy.isFinite else { return nil }
        let quality = min(100, max(0, accuracy)) / 100
        // shortcut: unkalibrierte Trainingsheuristik; mit Partien bekannter Ratings empirisch ersetzen.
        var estimate = 400 + 1600 * pow(quality, 3)
        if let opponentElo, let opponentAccuracy {
            guard (100...3500).contains(opponentElo), opponentAccuracy.isFinite else { return nil }
            let difference = accuracy - min(100, max(0, opponentAccuracy))
            let evidence = min(1, Double(moveCount) / 30)
            estimate = Double(opponentElo) + min(400, max(-400, difference * 12)) * evidence
        }
        return Int((min(3000, max(100, estimate)) / 50).rounded()) * 50
    }

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

    /// Lichess-Gesamtgenauigkeit: Mittel aus volatilitätsgewichtetem und harmonischem Mittel.
    /// Das harmonische Mittel bestraft einzelne Patzer stark, ein einfacher Durchschnitt wäre zu gutmütig.
    public static func gameAccuracy(for player: Color, moves: [MoveAnalysis]) -> Double {
        guard let first = moves.first else { return 100.0 }
        let movers: [Color] = moves.map { move in
            (try? Position(fen: move.fenBefore))?.turn ?? (move.ply % 2 != 0 ? .white : .black)
        }
        func white(_ percent: Double, _ mover: Color) -> Double { mover == .white ? percent : 100 - percent }
        let winsWhite = [white(first.winPercentBefore, movers[0])]
            + zip(moves, movers).map { white($0.winPercentAfter, $1) }

        let windowSize = min(max(moves.count / 10, 2), 8)
        let firstWindow = Array(winsWhite.prefix(windowSize))
        let windows = Array(repeating: firstWindow, count: windowSize - 2)
            + (0...(winsWhite.count - windowSize)).map { Array(winsWhite[$0..<($0 + windowSize)]) }
        let weights = windows.map { xs -> Double in
            let mean = xs.reduce(0, +) / Double(xs.count)
            let variance = xs.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(xs.count)
            return min(max(variance.squareRoot(), 0.5), 12)
        }

        let own = moves.indices.filter { movers[$0] == player }
        guard !own.isEmpty else { return 100.0 }
        let weighted = own.reduce(0) { $0 + moves[$1].accuracy * weights[$1] } / own.reduce(0) { $0 + weights[$1] }
        let harmonic = Double(own.count) / own.reduce(0) { $0 + 1 / max(1, moves[$1].accuracy) }
        return (weighted + harmonic) / 2
    }
}
