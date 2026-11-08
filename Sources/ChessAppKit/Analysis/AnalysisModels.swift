import Foundation

/// Classification of a chess move reflecting quality and tactical significance.
public enum MoveClassification: String, CaseIterable, Codable, Sendable {
    case brilliant
    case great
    case best
    case excellent
    case good
    case book
    case inaccuracy
    case mistake
    case miss
    case blunder

    /// Human-readable title for the classification.
    public var title: String {
        switch self {
        case .brilliant: return "Brilliant"
        case .great: return "Great"
        case .best: return "Best"
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .book: return "Book"
        case .inaccuracy: return "Inaccuracy"
        case .mistake: return "Mistake"
        case .miss: return "Miss"
        case .blunder: return "Blunder"
        }
    }

    /// Annotation symbol representing this classification.
    public var symbol: String {
        switch self {
        case .brilliant: return "!!"
        case .great: return "!"
        case .best: return "★"
        case .excellent: return "✓"
        case .good: return "✔"
        case .book: return "≡"
        case .inaccuracy: return "?!"
        case .mistake: return "?"
        case .miss: return "✖"
        case .blunder: return "??"
        }
    }

    /// Standard color name for UI representation.
    public var colorName: String {
        switch self {
        case .brilliant: return "cyan"
        case .great: return "blue"
        case .best: return "green"
        case .excellent: return "gold"
        case .good: return "olive"
        case .book: return "brown"
        case .inaccuracy: return "yellow"
        case .mistake: return "orange"
        case .miss: return "red"
        case .blunder: return "red"
        }
    }
}

public enum GamePhase: String, CaseIterable, Sendable {
    case opening = "Eröffnung"
    case middlegame = "Mittelspiel"
    case endgame = "Endspiel"
}

/// Detailed evaluation and classification for an individual move in a game.
public struct MoveAnalysis: Codable, Sendable, Identifiable {
    public var id: UUID
    public let ply: Int
    public let san: String
    public let fenBefore: String
    public let fenAfter: String
    /// Centipawn evaluation before move (normalized to White's perspective).
    public let evalBefore: Int?
    /// Centipawn evaluation after move (normalized to White's perspective).
    public let evalAfter: Int?
    /// Best engine move (UCI or SAN).
    public let bestMove: String
    public let classification: MoveClassification
    /// Move accuracy score in range 0...100.
    public let accuracy: Double
    /// Win probability before the move for the player whose turn it was (0...100).
    public let winPercentBefore: Double
    /// Win probability after the move for the player who just moved (0...100).
    public let winPercentAfter: Double
    /// Loss in win probability caused by the move: max(0.0, winPercentBefore - winPercentAfter).
    public let winPercentLoss: Double

    public var phase: GamePhase {
        let position = try? Position(fen: fenBefore)
        let material = position?.board.compactMap { $0 }.filter { $0.type != .king }.count ?? 32
        if material <= 10 { return .endgame }
        return ply <= 20 ? .opening : .middlegame
    }

    public init(
        id: UUID = UUID(),
        ply: Int,
        san: String,
        fenBefore: String,
        fenAfter: String,
        evalBefore: Int?,
        evalAfter: Int?,
        bestMove: String,
        classification: MoveClassification,
        accuracy: Double,
        winPercentBefore: Double,
        winPercentAfter: Double,
        winPercentLoss: Double
    ) {
        self.id = id
        self.ply = ply
        self.san = san
        self.fenBefore = fenBefore
        self.fenAfter = fenAfter
        self.evalBefore = evalBefore
        self.evalAfter = evalAfter
        self.bestMove = bestMove
        self.classification = classification
        self.accuracy = accuracy
        self.winPercentBefore = winPercentBefore
        self.winPercentAfter = winPercentAfter
        self.winPercentLoss = winPercentLoss
    }
}

/// Overall analysis report for an entire chess game.
public struct GameAnalysis: Codable, Sendable {
    public func estimatedElo(for player: Color, opponentElo: Int? = nil) -> Int? {
        let count = moves.filter {
            ((try? Position(fen: $0.fenBefore))?.turn ?? ($0.ply % 2 == 1 ? .white : .black)) == player
        }.count
        return AccuracyCalculator.estimatedElo(
            accuracy: player == .white ? accuracyWhite : accuracyBlack, moveCount: count,
            opponentElo: opponentElo, opponentAccuracy: player == .white ? accuracyBlack : accuracyWhite)
    }

    public let moves: [MoveAnalysis]
    public let accuracyWhite: Double
    public let accuracyBlack: Double
    public let eco: String?
    public let openingName: String?

    public init(
        moves: [MoveAnalysis],
        accuracyWhite: Double,
        accuracyBlack: Double,
        eco: String? = nil,
        openingName: String? = nil
    ) {
        self.moves = moves
        self.accuracyWhite = accuracyWhite
        self.accuracyBlack = accuracyBlack
        self.eco = eco
        self.openingName = openingName
    }
}
