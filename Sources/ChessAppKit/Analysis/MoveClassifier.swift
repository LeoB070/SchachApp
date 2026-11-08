import Foundation

/// Einfache Zugklassen anhand des Verlusts an Gewinnwahrscheinlichkeit.
public enum MoveClassifier {
    /// Bewertungsdaten; erweiterte Kontextfelder bleiben für spätere Zugklassen reserviert.
    public struct Context: Sendable {
        public let moveUCI: String?
        public let moveSAN: String?
        public let positionBefore: Position?
        public let positionAfter: Position?
        public let winPercentBefore: Double
        public let winPercentAfter: Double
        public let bestMoveUCI: String?
        public let bestMoveSAN: String?
        public let secondBestMoveLoss: Double?
        public let isBook: Bool
        public let previousOpponentLoss: Double?
        public let previousMoveClassification: MoveClassification?
        public let opponentRecapturedSacrifice: Bool?

        public init(
            moveUCI: String? = nil,
            moveSAN: String? = nil,
            positionBefore: Position? = nil,
            positionAfter: Position? = nil,
            winPercentBefore: Double,
            winPercentAfter: Double,
            bestMoveUCI: String? = nil,
            bestMoveSAN: String? = nil,
            secondBestMoveLoss: Double? = nil,
            isBook: Bool = false,
            previousOpponentLoss: Double? = nil,
            previousMoveClassification: MoveClassification? = nil,
            opponentRecapturedSacrifice: Bool? = nil
        ) {
            self.moveUCI = moveUCI
            self.moveSAN = moveSAN
            self.positionBefore = positionBefore
            self.positionAfter = positionAfter
            self.winPercentBefore = winPercentBefore
            self.winPercentAfter = winPercentAfter
            self.bestMoveUCI = bestMoveUCI
            self.bestMoveSAN = bestMoveSAN
            self.secondBestMoveLoss = secondBestMoveLoss
            self.isBook = isBook
            self.previousOpponentLoss = previousOpponentLoss
            self.previousMoveClassification = previousMoveClassification
            self.opponentRecapturedSacrifice = opponentRecapturedSacrifice
        }
    }

    /// Grundstufen anhand des Verlusts und des Engine-Bestzugs.
    /// - Parameter context: The evaluation context for this move.
    /// - Returns: The MoveClassification.
    public static func classify(context: Context) -> MoveClassification {
        if context.isBook { return .book }
        // TODO(CLAUDE): Brilliant, Great und Miss anhand verlässlicher Kontextdaten bewerten.
        let loss = max(0.0, context.winPercentBefore - context.winPercentAfter)

        // Check if move matches engine top recommendation
        let matchesEngineBest: Bool
        if let moveU = context.moveUCI, let bestU = context.bestMoveUCI, !moveU.isEmpty, !bestU.isEmpty {
            matchesEngineBest = (moveU.lowercased() == bestU.lowercased())
        } else if let moveS = context.moveSAN, let bestS = context.bestMoveSAN, !moveS.isEmpty, !bestS.isEmpty {
            matchesEngineBest = (cleanSAN(moveS) == cleanSAN(bestS))
        } else {
            matchesEngineBest = false
        }

        // 5. Best Move (★)
        // Matches the engine's #1 move or incurs virtually no win probability loss (<= 0.5%).
        if matchesEngineBest || loss <= 0.5 {
            return .best
        }

        // 6. Excellent (✓)
        // Loss <= 2.0%
        if loss <= 2.0 {
            return .excellent
        }

        // 7. Good (✔)
        // Loss <= 5.0%
        if loss <= 5.0 {
            return .good
        }

        // 8. Inaccuracy (?!)
        // Loss <= 10.0%
        if loss <= 10.0 {
            return .inaccuracy
        }

        // 9. Mistake (?)
        // Loss <= 15.0% (Lichess-Grenze; Chess.com nutzt 20%)
        if loss <= 15.0 {
            return .mistake
        }

        // 10. Blunder (??)
        // Significant loss > 15.0%
        return .blunder
    }

    // MARK: - Private Helpers

    private static func cleanSAN(_ san: String) -> String {
        san.trimmingCharacters(in: .whitespacesAndNewlines)
           .replacingOccurrences(of: "+", with: "")
           .replacingOccurrences(of: "#", with: "")
           .replacingOccurrences(of: "!", with: "")
           .replacingOccurrences(of: "?", with: "")
    }

}
