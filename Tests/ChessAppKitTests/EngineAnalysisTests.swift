import Foundation
import Testing
import ChessAppKit

@Suite struct EngineAnalysisTests {
    @Test func formulasFollowScaffoldSpecification() {
        #expect(abs(AccuracyCalculator.moveAccuracy(loss: 10) - (103.1668 * exp(-0.04354 * 10) - 3.1669)) < 0.000001)
        #expect(WinProbability.winPercent(cp: 2000) > 99.9)
    }

    @Test func gameAccuracyPunishesBlundersHarderThanPlainMean() throws {
        let start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        let black = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"
        // Weiß: 9 gute Züge (Accuracy 95) und ein Patzer (Accuracy 5); Schwarz spielt neutral.
        let moves = (1...20).map { ply -> MoveAnalysis in
            let isWhite = ply % 2 == 1
            let acc = isWhite ? (ply == 11 ? 5.0 : 95.0) : 90.0
            return MoveAnalysis(ply: ply, san: "x", fenBefore: isWhite ? start : black, fenAfter: start,
                evalBefore: 0, evalAfter: 0, bestMove: "", classification: .good, accuracy: acc,
                winPercentBefore: 50, winPercentAfter: ply == 11 ? 10 : 50, winPercentLoss: 0)
        }
        let white = AccuracyCalculator.gameAccuracy(for: .white, moves: moves)
        #expect(white < 86 - 10) // einfacher Durchschnitt wäre 86
        #expect(abs(AccuracyCalculator.gameAccuracy(for: .black, moves: moves) - 90) < 0.001)
    }

    @Test func immediateEngineRepliesAreNotLost() async throws {
        let url = try makeEngineScript("echo 'bestmove e2e4'")
        defer { try? FileManager.default.removeItem(at: url) }
        let engine = try UCIEngine(executablePath: url.path)
        try await engine.start()
        let move = try await engine.bestMove(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", movetimeMs: 1)
        #expect(move == "e2e4")
        await engine.stop()
    }

    @Test func cancellationReleasesBestMoveWaiter() async throws {
        let url = try makeEngineScript(":")
        defer { try? FileManager.default.removeItem(at: url) }
        let engine = try UCIEngine(executablePath: url.path)
        try await engine.start()
        let task = Task { try await engine.bestMove(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", movetimeMs: 1) }
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Cancelled search returned a move")
        } catch {
            #expect(error is CancellationError || error as? EngineError == .cancelled)
        }
        await engine.stop()
    }

    @Test func openingBookUsesLongestMatchingPrefix() throws {
        let book = OpeningBook(openings: [
            .init(eco: "B00", name: "King Pawn", moves: ["e4"]),
            .init(eco: "B20", name: "Sicilian", moves: ["e4", "c5"])
        ])
        #expect(book.match(sanMoves: ["e4", "c5", "Nf3"])?.eco == "B20")
        #expect(book.match(sanMoves: ["d4"]) == nil)
        #expect(try OpeningBook().openings.count >= 30)
    }

    @Test func reviewBuildsPersistableReportWithWhiteNormalizedEvaluations() async throws {
        let url = try makeEngineScript("echo 'info depth 2 score cp 100 pv e2e4'; echo 'bestmove e2e4'")
        defer { try? FileManager.default.removeItem(at: url) }
        let engine = try UCIEngine(executablePath: url.path)
        let initial = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        let move = try #require(initial.legalMoves().first { $0.uci == "e2e4" })
        let service = GameReviewService(engine: engine)
        var report: GameAnalysis?
        for try await progress in service.review(positions: [initial, initial.make(move)], moves: [move], depth: 2) {
            #expect(progress.completedPlies == 1)
            #expect(progress.totalPlies == 1)
            report = progress.analysis
        }
        let analysis = try #require(report)
        #expect(analysis.moves.first?.evalBefore == 100)
        #expect(analysis.moves.first?.evalAfter == -100)
        #expect(analysis.moves.first?.san == "e4")
        #expect(analysis.moves.first?.winPercentLoss ?? 0 > 0)
        let data = try JSONEncoder().encode(analysis)
        #expect(try JSONDecoder().decode(GameAnalysis.self, from: data).moves.count == 1)
    }

    private func makeEngineScript(_ goResponse: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let script = """
        #!/bin/sh
        while IFS= read -r command; do
          case "$command" in
            uci) echo uciok ;;
            isready) echo readyok ;;
            go*) \(goResponse) ;;
            quit) exit 0 ;;
          esac
        done
        """
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }
}
