import Foundation
import ChessAppKit

func engineAnalysisChecks() async throws {
    check(abs(AccuracyCalculator.moveAccuracy(loss: 10) - (103.1668 * exp(-0.04354 * 10) - 3.1669)) < 0.000001,
          "Zug-Accuracy entspricht der vorgegebenen Formel")
    check(WinProbability.winPercent(cp: 2000) > 99.9, "Gewinnwahrscheinlichkeit ohne künstliche cp-Begrenzung")
    let book = try OpeningBook()
    check(book.openings.count >= 30, "Mindestens 30 Beispiel-Eröffnungen")
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

    if let path = EngineLocator.locateEngine() {
        let stockfish = try UCIEngine(executablePath: path, settings: EngineSettings(threads: 1, hashMB: 16))
        try await stockfish.start()
        let best = try await stockfish.bestMove(fen: start.fen, movetimeMs: 30)
        check(start.legalMoves().contains { $0.uci == best }, "Stockfish liefert legalen Zug")
        var lastInfo: EngineInfo?
        for await info in stockfish.analyze(fen: start.fen, depth: 3, multiPV: 2) { lastInfo = info }
        check(lastInfo != nil, "Stockfish liefert Analyse und beendet den Stream")
        await stockfish.stop()
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
