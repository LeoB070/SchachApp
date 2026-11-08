import Foundation

public struct ReviewProgress: Sendable {
    public let completedPlies: Int
    public let totalPlies: Int
    public let analysis: GameAnalysis
}

/// Analysiert die Stellungen nacheinander; der Aufrufer verwendet eine eigene Engine für den Review.
public struct GameReviewService: Sendable {
    private let engine: any ChessEngine
    private let openingBook: OpeningBook?

    public init(engine: any ChessEngine, openingBook: OpeningBook? = try? OpeningBook()) {
        self.engine = engine
        self.openingBook = openingBook
    }

    public func review(positions: [Position], moves: [Move], depth: Int = 16) -> AsyncThrowingStream<ReviewProgress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard positions.count == moves.count + 1 else {
                        throw EngineError.unexpectedResponse("Zu jedem Zug werden die Stellung davor und danach benötigt.")
                    }
                    try await engine.start()
                    var analyses: [MoveAnalysis] = []
                    var sans: [String] = []
                    let startsAtStandardPosition = positions[0].fen == "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
                    var before = try await evaluate(positions[0], depth: depth)
                    for index in moves.indices {
                        try Task.checkCancellation()
                        let position = positions[index]
                        let move = moves[index]
                        guard position.legalMoves().contains(move), position.make(move) == positions[index + 1] else {
                            throw EngineError.unexpectedResponse("Die Zugfolge enthält einen ungültigen Zug.")
                        }
                        let after = try await evaluate(positions[index + 1], depth: depth)
                        let san = SAN.notation(for: move, in: position)
                        sans.append(san)
                        let winBefore = WinProbability.winPercent(evalCp: before.cp, mateIn: before.mate, for: position.turn)
                        let winAfter = WinProbability.winPercent(evalCp: after.cp, mateIn: after.mate, for: position.turn)
                        let loss = max(0, winBefore - winAfter)
                        let bestMove = before.pv.first ?? ""
                        let classification = MoveClassifier.classify(context: .init(
                            moveUCI: move.uci, winPercentBefore: winBefore, winPercentAfter: winAfter,
                            bestMoveUCI: bestMove,
                            isBook: startsAtStandardPosition && openingBook?.contains(sanMoves: sans) == true
                        ))
                        analyses.append(MoveAnalysis(
                            ply: index + 1, san: san, fenBefore: position.fen, fenAfter: positions[index + 1].fen,
                            evalBefore: before.cp, evalAfter: after.cp, bestMove: bestMove,
                            classification: classification, accuracy: AccuracyCalculator.moveAccuracy(loss: loss),
                            winPercentBefore: winBefore, winPercentAfter: winAfter, winPercentLoss: loss
                        ))
                        let opening = startsAtStandardPosition ? openingBook?.match(sanMoves: sans) : nil
                        continuation.yield(ReviewProgress(completedPlies: index + 1, totalPlies: moves.count,
                            analysis: GameAnalysis(moves: analyses,
                                accuracyWhite: AccuracyCalculator.gameAccuracy(for: .white, moves: analyses),
                                accuracyBlack: AccuracyCalculator.gameAccuracy(for: .black, moves: analyses),
                                eco: opening?.eco, openingName: opening?.name)))
                        before = after
                    }
                    if moves.isEmpty {
                        continuation.yield(ReviewProgress(completedPlies: 0, totalPlies: 0,
                            analysis: GameAnalysis(moves: [], accuracyWhite: 100, accuracyBlack: 100)))
                    }
                    await engine.stop()
                    continuation.finish()
                } catch {
                    await engine.stop()
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func evaluate(_ position: Position, depth: Int) async throws -> EngineInfo {
        try Task.checkCancellation()
        if position.legalMoves().isEmpty {
            if position.isInCheck(position.turn) {
                return EngineInfo(depth: 0, mate: position.turn == .white ? -1 : 1)
            }
            return EngineInfo(depth: 0, cp: 0)
        }
        var result: EngineInfo?
        for await info in engine.analyze(fen: position.fen, depth: max(1, depth), multiPV: 1) {
            try Task.checkCancellation()
            if info.multiPV == 1, info.cp != nil || info.mate != nil { result = info }
        }
        try Task.checkCancellation()
        guard let result else { throw EngineError.unexpectedResponse("Keine Stellungsbewertung von der Engine erhalten.") }
        return result
    }
}
