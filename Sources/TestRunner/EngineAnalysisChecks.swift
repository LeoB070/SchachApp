import Foundation
import ChessAppKit

func engineAnalysisChecks() async throws {
    let ryzen = DeepAnalysisProfile(processorCount: 16, memoryBytes: 32 * 1024 * 1024 * 1024)
    checkEqual(ryzen.threads, 14, "Tiefanalyse lässt zwei logische CPUs frei")
    check(ryzen.depth > 16, "Tiefanalyse sucht tiefer als Standardanalyse")
    let small = DeepAnalysisProfile(processorCount: 1, memoryBytes: 512 * 1024 * 1024)
    checkEqual(small.threads, 1, "Tiefanalyse funktioniert mit einer CPU")
    check(small.hashMB <= 64, "Hash lässt auf kleinem Rechner RAM frei")
    let large = DeepAnalysisProfile(processorCount: 256, memoryBytes: UInt64.max)
    check(large.hashMB <= 4096 && large.threads <= 32, "Tiefanalyse begrenzt Ressourcen")

    checkEqual(AccuracyCalculator.estimatedElo(accuracy: 80, moveCount: 9), nil, "Keine Elo bei zu wenigen Zügen")
    checkEqual(AccuracyCalculator.estimatedElo(accuracy: .nan, moveCount: 20), nil, "Keine Elo bei ungültiger Accuracy")
    checkEqual(AccuracyCalculator.estimatedElo(accuracy: -10, moveCount: 20), 400, "Elo-Untergrenze")
    checkEqual(AccuracyCalculator.estimatedElo(accuracy: 110, moveCount: 20), 2000, "Vorsichtige Elo-Obergrenze ohne Ratingkontext")
    check(AccuracyCalculator.estimatedElo(accuracy: 90, moveCount: 20)! > AccuracyCalculator.estimatedElo(accuracy: 60, moveCount: 20)!, "Höhere Accuracy ergibt höhere Elo-Schätzung")
    check(AccuracyCalculator.estimatedElo(accuracy: 90, moveCount: 20)! < 1800, "90 Prozent sind keine Meister-Elo")
    checkEqual(AccuracyCalculator.estimatedElo(accuracy: 90, moveCount: 30, opponentElo: 500, opponentAccuracy: 60), 850, "Hohe Accuracy gegen Emil bleibt gegnerbezogen")
    checkEqual(AccuracyCalculator.estimatedElo(accuracy: 70, moveCount: 30, opponentElo: 500, opponentAccuracy: 70), 500, "Gleiche Genauigkeit bleibt am Referenzrating")
    checkEqual(AccuracyCalculator.estimatedElo(accuracy: 100, moveCount: 30, opponentElo: 500, opponentAccuracy: 0), 900, "Eine Partie begrenzt den Abstand zum Referenzrating")
    checkEqual(AccuracyCalculator.estimatedElo(accuracy: 90, moveCount: 30, opponentElo: 500, opponentAccuracy: .nan), nil, "Ungültige Gegner-Accuracy wird abgewiesen")
    checkEqual(AccuracyCalculator.estimatedElo(accuracy: .infinity, moveCount: 30), nil, "Unendliche Accuracy wird abgewiesen")
    check(abs(AccuracyCalculator.moveAccuracy(loss: 10) - (103.1668 * exp(-0.04354 * 10) - 3.1669)) < 0.000001,
          "Zug-Accuracy entspricht der vorgegebenen Formel")
    do {
        let start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        let black = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"
        let moves = (1...20).map { ply -> MoveAnalysis in
            let isWhite = ply % 2 == 1
            return MoveAnalysis(ply: ply, san: "x", fenBefore: isWhite ? start : black, fenAfter: start,
                evalBefore: 0, evalAfter: 0, bestMove: "", classification: .good,
                accuracy: isWhite ? (ply == 11 ? 5 : 95) : 90,
                winPercentBefore: 50, winPercentAfter: ply == 11 ? 10 : 50, winPercentLoss: 0)
        }
        let partial = GameAnalysis(moves: Array(moves.prefix(19)), accuracyWhite: 80, accuracyBlack: 60)
        check(partial.estimatedElo(for: .white) != nil, "Zehn weiße Züge erlauben Schätzung")
        checkEqual(partial.estimatedElo(for: .black), nil, "Neun schwarze Züge erlauben keine Schätzung")
        let blackStart = GameAnalysis(moves: Array(repeating: moves[1], count: 10), accuracyWhite: 80, accuracyBlack: 60)
        check(blackStart.estimatedElo(for: .black) != nil, "Elo zählt die Seite anhand der Stellung")
        checkEqual(blackStart.estimatedElo(for: .white), nil, "Keine Schätzung für eine Seite ohne Züge")
        let white = AccuracyCalculator.gameAccuracy(for: .white, moves: moves)
        check(white < 76, "Ein Patzer drückt die Partie-Genauigkeit deutlich unter den Schnitt (\(white))")
        check(abs(AccuracyCalculator.gameAccuracy(for: .black, moves: moves) - 90) < 0.001, "Konstante Genauigkeit bleibt erhalten")
    }
    check(WinProbability.winPercent(cp: 2000) > 99.9, "Gewinnwahrscheinlichkeit ohne künstliche cp-Begrenzung")
    let book = try OpeningBook()
    checkEqual(book.openings.count, 3865, "Offizielle Eröffnungsdatenbank vollständig geladen")
    checkEqual(Set(book.openings.map(\.eco)).count, 500, "Alle 500 ECO-Codes enthalten")
    let prefixBook = OpeningBook(openings: [
        .init(eco: "B00", name: "King Pawn", moves: ["e4"]),
        .init(eco: "B20", name: "Sicilian", moves: ["e4", "c5"])
    ])
    checkEqual(prefixBook.match(sanMoves: ["e4", "c5", "Nf3"])?.eco, "B20", "Längste passende Eröffnung")
    check(prefixBook.match(sanMoves: ["d4"]) == nil, "Unbekannte Eröffnung bleibt leer")
    let start = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    let missing = try UCIEngine(executablePath: "/nonexistent/stockfish")
    do {
        try await missing.start()
        check(false, "Fehlendes Engine-Binary meldet Fehler")
    } catch { check(error as? EngineError == .binaryNotFound("/nonexistent/stockfish"), "Fehlendes Engine-Binary meldet Fehler") }

    let immediate = try engineFixture(goResponse: "echo 'info depth 2 score cp 100 pv e2e4'; echo 'bestmove e2e4'")
    defer { try? FileManager.default.removeItem(at: immediate) }
    let engine = try UCIEngine(executablePath: immediate.path)
    try await engine.start()
    checkEqual(try await engine.bestMove(fen: start.fen, movetimeMs: 1), "e2e4", "Sofortige bestmove-Antwort geht nicht verloren")
    await engine.stop()
    let move = start.legalMoves().first { $0.uci == "e2e4" }!
    var report: GameAnalysis?
    for try await progress in GameReviewService(engine: engine).review(positions: [start, start.make(move)], moves: [move], depth: 2) {
        checkEqual(progress.completedPlies, 1, "Review meldet Fortschritt")
        report = progress.analysis
    }
    checkEqual(report?.moves.first?.evalBefore, 100, "Review-Bewertung vor Zug aus Weißsicht")
    checkEqual(report?.moves.first?.evalAfter, -100, "Review normalisiert Schwarz-Bewertung")
    checkEqual(report?.moves.first?.san, "e4", "Review erzeugt SAN")
    if let report {
        let roundtrip = try JSONDecoder().decode(GameAnalysis.self, from: JSONEncoder().encode(report))
        checkEqual(roundtrip.moves.count, 1, "Review-Bericht ist speicherbar")
    }

    let silent = try engineFixture(goResponse: ":")
    defer { try? FileManager.default.removeItem(at: silent) }
    let cancellable = try UCIEngine(executablePath: silent.path)
    try await cancellable.start()
    let search = Task { try await cancellable.bestMove(fen: start.fen, movetimeMs: 1) }
    try await Task.sleep(nanoseconds: 100_000_000)
    let cancellationStart = Date()
    search.cancel()
    do {
        _ = try await search.value
        check(false, "Abgebrochene Engine-Suche wirft Fehler")
    } catch {
        check(error is CancellationError || error as? EngineError == .cancelled, "Abgebrochene Engine-Suche wirft Fehler")
    }
    check(Date().timeIntervalSince(cancellationStart) < 2, "Engine-Abbruch löst Continuation zeitnah auf")
    await cancellable.stop()

    let bounded = try UCIEngine(executablePath: silent.path, analysisTimeoutSeconds: 1)
    try await bounded.start()
    let streamStart = Date()
    for await _ in bounded.analyze(fen: start.fen, depth: 30, multiPV: 3) {}
    check(Date().timeIntervalSince(streamStart) < 3, "Tiefanalyse beendet Stream am Zeitbudget")
    await bounded.stop()

    let streamEngine = try UCIEngine(executablePath: silent.path)
    try await streamEngine.start()
    let streamSearch = Task {
        for await _ in streamEngine.analyze(fen: start.fen, depth: 30, multiPV: 3) {}
    }
    try await Task.sleep(nanoseconds: 100_000_000)
    let streamCancelStart = Date()
    streamSearch.cancel()
    await streamSearch.value
    check(Date().timeIntervalSince(streamCancelStart) < 2, "Tiefanalyse-Stream ist zeitnah abbrechbar")
    await streamEngine.stop()

    let noHandshake = try engineFixture(goResponse: ":", handshake: ":")
    defer { try? FileManager.default.removeItem(at: noHandshake) }
    let unresponsive = try UCIEngine(executablePath: noHandshake.path)
    let timeoutStart = Date()
    do {
        try await unresponsive.start()
        check(false, "Fehlender UCI-Handshake endet mit Timeout")
    } catch { check(error as? EngineError == .timeout, "Fehlender UCI-Handshake endet mit Timeout") }
    check(Date().timeIntervalSince(timeoutStart) < 6, "Handshake-Timeout hängt nicht an Continuation")
    await unresponsive.stop()

    let pidFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let stubborn = try engineFixture(goResponse: "trap '' TERM; echo $$ > '\(pidFile.path)'; while :; do :; done")
    defer {
        try? FileManager.default.removeItem(at: stubborn)
        try? FileManager.default.removeItem(at: pidFile)
    }
    let stubbornEngine = try UCIEngine(executablePath: stubborn.path)
    try await stubbornEngine.start()
    let stubbornSearch = Task { try await stubbornEngine.bestMove(fen: start.fen, movetimeMs: 1) }
    for _ in 0..<100 where !FileManager.default.fileExists(atPath: pidFile.path) {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    let pid = Int32(try String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines))!
    defer { if kill(pid, 0) == 0 { kill(pid, SIGKILL) } }
    await stubbornEngine.stop()
    _ = try? await stubbornSearch.value
    for _ in 0..<150 where kill(pid, 0) == 0 {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    check(kill(pid, 0) != 0, "Engine-Stopp beendet auch Prozesse, die SIGTERM ignorieren")

    if let path = EngineLocator.locateEngine() {
        let stockfish = try UCIEngine(executablePath: path, settings: EngineSettings(threads: 1, hashMB: 16))
        try await stockfish.start()
        let best = try await stockfish.bestMove(fen: start.fen, movetimeMs: 30)
        check(start.legalMoves().contains { $0.uci == best }, "Stockfish liefert legalen Zug")
        var lastInfo: EngineInfo?
        for await info in stockfish.analyze(fen: start.fen, depth: 3, multiPV: 2) { lastInfo = info }
        check(lastInfo != nil, "Stockfish liefert Analyse und beendet den Stream")
        let deepSearch = Task {
            for await _ in stockfish.analyze(fen: start.fen, depth: 60, multiPV: 3) {}
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        let deepCancelStart = Date()
        deepSearch.cancel()
        await deepSearch.value
        await stockfish.stop()
        check(Date().timeIntervalSince(deepCancelStart) < 2, "Lokale Stockfish-Tiefanalyse wird zeitnah abgebrochen")
    } else {
        print("SKIP Stockfish-Smoke-Test: kein lokales Binary")
    }
}

private func engineFixture(goResponse: String, handshake: String = "echo uciok") throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let script = """
    #!/bin/sh
    while IFS= read -r command; do
      case "$command" in
        uci) \(handshake) ;;
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
