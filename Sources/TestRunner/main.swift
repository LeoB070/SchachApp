import Foundation
import ChessAppKit

// Selbstgebauter Test-Runner: die CommandLineTools laufen ohne Xcode, daher kann
// `swift test` auf dieser Maschine das Test-Bundle nicht ausführen (kein Host).
// Dieses Executable führt denselben Assertions-Satz aus und beendet sich mit
// Code 1, sobald eine Prüfung scheitert.

var passedCount = 0
var failedCount = 0

func check(_ condition: Bool, _ label: String) {
    if condition {
        passedCount += 1
        print("PASS \(label)")
    } else {
        failedCount += 1
        print("FAIL \(label)")
    }
}

func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
    check(actual == expected, "\(label) (\(actual) erwartet: \(expected))")
}

// MARK: - Perft

private func perft(_ position: Position, _ depth: Int) -> Int {
    if depth == 0 { return 1 }
    if depth == 1 { return position.legalMoves().count }
    var count = 0
    for move in position.legalMoves() {
        count += perft(position.make(move), depth - 1)
    }
    return count
}

private func perftChecks() throws {
    let start = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    checkEqual(perft(start, 1), 20, "perft start d1")
    checkEqual(perft(start, 2), 400, "perft start d2")
    checkEqual(perft(start, 3), 8902, "perft start d3")
    checkEqual(perft(start, 4), 197281, "perft start d4")

    let kiwipete = try Position(fen: "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
    checkEqual(perft(kiwipete, 1), 48, "perft kiwipete d1")
    checkEqual(perft(kiwipete, 2), 2039, "perft kiwipete d2")
    checkEqual(perft(kiwipete, 3), 97862, "perft kiwipete d3")

    let position3 = try Position(fen: "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
    checkEqual(perft(position3, 1), 14, "perft position3 d1")
    checkEqual(perft(position3, 2), 191, "perft position3 d2")
    checkEqual(perft(position3, 3), 2812, "perft position3 d3")
}

// MARK: - FEN

private func fenChecks() throws {
    let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    checkEqual(try Position(fen: startFEN).fen, startFEN, "FEN roundtrip start")

    let kiwipete = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
    checkEqual(try Position(fen: kiwipete).fen, kiwipete, "FEN roundtrip kiwipete")

    // EP-Feld ohne möglichen Passantenschlag wird trotzdem übernommen.
    let impossibleEP = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq e3 0 1"
    let parsed = try Position(fen: impossibleEP)
    checkEqual(parsed.enPassant?.name ?? "-", "e3", "FEN EP-Feld übernehmen")
    checkEqual(parsed.fen, impossibleEP, "FEN roundtrip unmögliches EP")

    do {
        _ = try Position(fen: "unmoeglich")
        check(false, "kaputte FEN wirft")
    } catch {
        check(true, "kaputte FEN wirft")
    }

    let expectedKey = startFEN.split(separator: " ").prefix(4).joined(separator: " ")
    checkEqual(try Position(fen: startFEN).repetitionKey, expectedKey, "repetitionKey = FEN-Felder 1-4")
}

// MARK: - Zuggenerierung

private func uciSet(_ moves: [Move]) -> Set<String> {
    Set(moves.map(\.uci))
}

private func moveGenerationChecks() throws {
    let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    checkEqual(try Position(fen: startFEN).legalMoves().count, 20, "Startstellung: 20 legale Züge")

    // Umwandlung: alle vier Varianten, Springer im UCI als "n".
    // (Nackter Zug "a7a8" existiert nicht – auf der letzten Reihe ist Umwandlung Pflicht.)
    let promotion = try Position(fen: "8/P6k/8/8/8/8/8/7K w - - 0 1")
    let promotionUCIs = uciSet(promotion.legalMoves())
    for code in ["q", "r", "b", "n"] {
        check(promotionUCIs.contains("a7a8\(code)"), "Umwandlung a7a8\(code)")
    }
    checkEqual(promotion.legalMoves().first { $0.uci == "a7a8n" }?.promotion, PieceType.knight, "Springer-Umwandlung = .knight")

    // Rochade beidseitig legal.
    let castle = try Position(fen: "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1")
    let castleUCIs = uciSet(castle.legalMoves())
    check(castleUCIs.contains("e1g1"), "O-O erlaubt")
    check(castleUCIs.contains("e1c1"), "O-O-O erlaubt")

    // Turm f3 greift f1 → O-O verboten, O-O-O erlaubt.
    let attacked = try Position(fen: "4k3/8/8/8/8/5r2/8/R3K2R w KQ - 0 1")
    let attackedUCIs = uciSet(attacked.legalMoves())
    check(!attackedUCIs.contains("e1g1"), "O-O verboten, wenn f1 angegriffen")
    check(attackedUCIs.contains("e1c1"), "O-O-O bleibt erlaubt")

    // Turm auf e-Datei greift den König an → gar keine Rochade.
    let inCheck = try Position(fen: "4k3/8/8/8/4r3/8/8/R3K2R w KQ - 0 1")
    let inCheckUCIs = uciSet(inCheck.legalMoves())
    check(!inCheckUCIs.contains("e1g1"), "kein O-O im Schach")
    check(!inCheckUCIs.contains("e1c1"), "kein O-O-O im Schach")

    // En passant: voller Ablauf e2e4 b8c6 e4e5 d7d5 → e5xd6 e.p.
    let start = try Position(fen: startFEN)
    let afterE4 = start.make(Move(from: Square(string: "e2")!, to: Square(string: "e4")!, flags: .doublePush))
    let afterNc6 = afterE4.make(Move(from: Square(string: "b8")!, to: Square(string: "c6")!))
    let afterE5 = afterNc6.make(Move(from: Square(string: "e4")!, to: Square(string: "e5")!))
    let afterD5 = afterE5.make(Move(from: Square(string: "d7")!, to: Square(string: "d5")!, flags: .doublePush))
    checkEqual(afterD5.turn, Color.white, "EP-Seq: weiß am Zug")
    checkEqual(afterD5.enPassant?.name ?? "-", "d6", "EP-Seq: EP-Feld d6")
    let epMove = afterD5.legalMoves().first { $0.uci == "e5d6" }
    check(epMove != nil, "Passantenschlag e5d6 vorhanden")
    if let epMove {
        check(epMove.flags.contains(.enPassant), "e5d6 Flag enPassant")
        check(epMove.flags.contains(.capture), "e5d6 Flag capture")
        let captured = afterD5.make(epMove)
        check(captured.board[Square(string: "d5")!.index] == nil, "EP: Bauer d5 weg")
        checkEqual(captured.board[Square(string: "d6")!.index] ?? nil, Piece(color: .white, type: .pawn), "EP: Bauer auf d6")
    }

    // En passant aus parsed FEN (schwarze Richtung): weißer Bauer e4, d4 schlägt nach e3.
    let fenEP = try Position(fen: "8/8/8/8/3pP3/8/8/k6K b - e3 0 1")
    let blackEP = fenEP.legalMoves().first { $0.uci == "d4e3" }
    check(blackEP != nil, "Passantenschlag d4e3 vorhanden")
    if let blackEP {
        check(blackEP.flags.contains(.enPassant), "d4e3 Flag enPassant")
        let captured = fenEP.make(blackEP)
        check(captured.board[Square(string: "e4")!.index] == nil, "EP: weißer Bauer e4 weg")
        checkEqual(captured.board[Square(string: "e3")!.index] ?? nil, Piece(color: .black, type: .pawn), "EP: Bauer auf e3")
    }
}

// MARK: - Material und Partieausgang

private func materialAndOutcomeChecks() throws {
    check(try Position(fen: "8/8/8/8/8/8/8/k6K w - - 0 1").hasInsufficientMaterial(), "K–K = ungenügend")
    check(try Position(fen: "8/8/8/8/8/4N3/8/k6K w - - 0 1").hasInsufficientMaterial(), "K+S–K = ungenügend")
    check(!(try Position(fen: "8/8/8/8/8/8/8/k5RK w - - 0 1").hasInsufficientMaterial()), "K+T–K = genug")
    check(try Position(fen: "8/8/8/4B3/8/8/5b2/k6K w - - 0 1").hasInsufficientMaterial(), "Läufer gleiche Feldfarbe")
    check(!(try Position(fen: "8/8/8/4B3/8/8/6b1/k6K w - - 0 1").hasInsufficientMaterial()), "Läufer ungleiche Feldfarbe")

    let start = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    checkEqual(GameOutcome.evaluate(position: start, repetitionCount: 0), GameOutcome.ongoing, "Ausgang: laufend")
    checkEqual(GameOutcome.evaluate(position: start, repetitionCount: 3), GameOutcome.threefold, "Ausgang: 3-fach")

    let longGame = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 100 60")
    checkEqual(GameOutcome.evaluate(position: longGame, repetitionCount: 2), GameOutcome.fiftyMove, "Ausgang: 50 Züge")
    // Material geht vor 50 Züge.
    let bareKings = try Position(fen: "8/8/8/8/8/8/8/k6K w - - 100 60")
    checkEqual(GameOutcome.evaluate(position: bareKings, repetitionCount: 2), GameOutcome.insufficientMaterial, "Ausgang: Material vor 50 Züge")
    // Matt geht vor allem anderen (hier wären schon 9 Wiederholungen gezählt).
    // Schwarz am Zug: Turm a8 gibt entlang der 8. Reihe Matt gegen König h8,
    // der weiße König g6 deckt g7/h7 (Rückzüge).
    let mate = try Position(fen: "R6k/8/6K1/8/8/8/8/8 b - - 0 1")
    check(mate.isCheckmate, "Matt erkannt")
    checkEqual(GameOutcome.evaluate(position: mate, repetitionCount: 9), GameOutcome.checkmate(winner: .white), "Ausgang: Matt")
    // Patt: Schwarz f8, Bauer f7 (Weiß), König f6 (Weiß) – kein Schach, kein Zug.
    let stalemate = try Position(fen: "5k2/5P2/5K2/8/8/8/8/8 b - - 0 1")
    check(stalemate.isStalemate, "Patt erkannt")
    checkEqual(GameOutcome.evaluate(position: stalemate, repetitionCount: 0), GameOutcome.stalemate, "Ausgang: Patt")
}

// MARK: - SAN

private func sanChecks() throws {
    func legalMove(_ position: Position, _ uci: String) -> Move {
        position.legalMoves().first { $0.uci == uci }!
    }

    let start = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    checkEqual(SAN.notation(for: legalMove(start, "e2e4"), in: start), "e4", "SAN e4")
    checkEqual(SAN.move(from: "e4", in: start)?.uci ?? "?", "e2e4", "SAN parse e4")
    checkEqual(SAN.move(from: "e4+", in: start)?.uci ?? "?", "e2e4", "SAN parse e4+")
    checkEqual(SAN.move(from: "e4!?", in: start)?.uci ?? "?", "e2e4", "SAN parse e4!?")
    check(SAN.move(from: "e5", in: start) == nil, "SAN parse unbekannt -> nil")
    check(SAN.move(from: "kaputt", in: start) == nil, "SAN parse Unsinn -> nil")

    let capture = try Position(fen: "8/8/8/3p4/4P3/8/8/k6K w - - 0 1")
    checkEqual(SAN.notation(for: legalMove(capture, "e4d5"), in: capture), "exd5", "SAN exd5")
    checkEqual(SAN.move(from: "exd5", in: capture)?.uci ?? "?", "e4d5", "SAN parse exd5")

    let castle = try Position(fen: "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1")
    checkEqual(SAN.notation(for: legalMove(castle, "e1g1"), in: castle), "O-O", "SAN O-O")
    checkEqual(SAN.move(from: "O-O", in: castle)?.uci ?? "?", "e1g1", "SAN parse O-O")
    checkEqual(SAN.move(from: "0-0", in: castle)?.uci ?? "?", "e1g1", "SAN parse 0-0")
    checkEqual(SAN.notation(for: legalMove(castle, "e1c1"), in: castle), "O-O-O", "SAN O-O-O")
    checkEqual(SAN.move(from: "O-O-O", in: castle)?.uci ?? "?", "e1c1", "SAN parse O-O-O")

    let promotion = try Position(fen: "8/P6k/8/8/8/8/8/7K w - - 0 1")
    checkEqual(SAN.notation(for: legalMove(promotion, "a7a8q"), in: promotion), "a8=Q", "SAN a8=Q")
    checkEqual(SAN.move(from: "a8=Q", in: promotion)?.uci ?? "?", "a7a8q", "SAN parse a8=Q")

    // Disambiguierung nach Datei: Türme a1/h1 beide nach d1 (König steht abseits).
    let rooksFile = try Position(fen: "6k1/8/8/8/8/8/5K2/R6R w - - 0 1")
    checkEqual(SAN.notation(for: legalMove(rooksFile, "a1d1"), in: rooksFile), "Rad1", "SAN Rad1")
    checkEqual(SAN.move(from: "Rad1", in: rooksFile)?.uci ?? "?", "a1d1", "SAN parse Rad1")

    // Disambiguierung nach Reihe: Türme a3/a5 beide nach a4.
    let rooksRank = try Position(fen: "6k1/8/8/R7/8/R7/8/6K1 w - - 0 1")
    checkEqual(SAN.notation(for: legalMove(rooksRank, "a5a4"), in: rooksRank), "R5a4", "SAN R5a4")
    checkEqual(SAN.move(from: "R5a4", in: rooksRank)?.uci ?? "?", "a5a4", "SAN parse R5a4")

    // Rückrank-Matt "Qa8#".
    let mate = try Position(fen: "6k1/5ppp/8/8/8/8/8/Q5K1 w - - 0 1")
    let queenMove = legalMove(mate, "a1a8")
    check(mate.make(queenMove).isCheckmate, "Qa8 ist Matt")
    checkEqual(SAN.notation(for: queenMove, in: mate), "Qa8#", "SAN Qa8#")
    checkEqual(SAN.move(from: "Qa8#", in: mate)?.uci ?? "?", "a1a8", "SAN parse Qa8#")
    checkEqual(SAN.move(from: "Qa8", in: mate)?.uci ?? "?", "a1a8", "SAN parse Qa8 ohne #")

    // Schach, aber kein Matt: Rh7+.
    let checkOnly = try Position(fen: "7k/8/6K1/8/8/8/8/7R w - - 0 1")
    checkEqual(SAN.notation(for: legalMove(checkOnly, "h1h7"), in: checkOnly), "Rh7+", "SAN Rh7+")
}

// MARK: - Start

func main() throws {
    try perftChecks()
    try fenChecks()
    try moveGenerationChecks()
    try materialAndOutcomeChecks()
    try sanChecks()
    print("Ergebnis: \(passedCount) bestanden, \(failedCount) gescheitert")
    exit(failedCount == 0 ? 0 : 1)
}

try main()
