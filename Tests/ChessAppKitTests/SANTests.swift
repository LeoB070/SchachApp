import Testing
import ChessAppKit

/// SAN-Notation und -Parsing (Roundtrip über kompakte SAN aller legalen Züge).
@Suite
struct SANTests {
    private func move(_ position: Position, _ uci: String) -> Move {
        position.legalMoves().first { $0.uci == uci }!
    }

    @Test func pawnPushNotationFromStart() throws {
        let position = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        #expect(SAN.notation(for: move(position, "e2e4"), in: position) == "e4")
        #expect(SAN.move(from: "e4", in: position)?.uci == "e2e4")
    }

    @Test func pawnCaptureNotation() throws {
        let position = try Position(fen: "8/8/8/3p4/4P3/8/8/k6K w - - 0 1")
        #expect(SAN.notation(for: move(position, "e4d5"), in: position) == "exd5")
        #expect(SAN.move(from: "exd5", in: position)?.uci == "e4d5")
    }

    @Test func castleKingsideNotationAndParse() throws {
        let position = try Position(fen: "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1")
        #expect(SAN.notation(for: move(position, "e1g1"), in: position) == "O-O")
        #expect(SAN.move(from: "O-O", in: position)?.uci == "e1g1")
        // Auch Nullen-Form akzeptieren (0-0).
        #expect(SAN.move(from: "0-0", in: position)?.uci == "e1g1")
    }

    @Test func castleQueensideNotationAndParse() throws {
        let position = try Position(fen: "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1")
        #expect(SAN.notation(for: move(position, "e1c1"), in: position) == "O-O-O")
        #expect(SAN.move(from: "O-O-O", in: position)?.uci == "e1c1")
    }

    @Test func promotionNotation() throws {
        let position = try Position(fen: "8/P6k/8/8/8/8/8/7K w - - 0 1")
        #expect(SAN.notation(for: move(position, "a7a8q"), in: position) == "a8=Q")
        #expect(SAN.move(from: "a8=Q", in: position)?.uci == "a7a8q")
    }

    @Test func disambiguationByFile() throws {
        // Türme a1/h1 können beide nach d1 (König f2 abseits) → Datei-Unterscheidung "Rad1".
        let position = try Position(fen: "6k1/8/8/8/8/8/5K2/R6R w - - 0 1")
        #expect(SAN.notation(for: move(position, "a1d1"), in: position) == "Rad1")
        #expect(SAN.move(from: "Rad1", in: position)?.uci == "a1d1")
    }

    @Test func disambiguationByRank() throws {
        // Türme a3/a5 (gleiche Datei) können beide nach a4 → Reihen-Unterscheidung "R5a4".
        let position = try Position(fen: "6k1/8/8/R7/8/R7/8/6K1 w - - 0 1")
        #expect(SAN.notation(for: move(position, "a5a4"), in: position) == "R5a4")
        #expect(SAN.move(from: "R5a4", in: position)?.uci == "a5a4")
    }

    @Test func checkmateSuffix() throws {
        // Rückrank-Matt: Dame a1 → a8, schwarzer König g8 hinter den Bauern f7g7h7.
        let position = try Position(fen: "6k1/5ppp/8/8/8/8/8/Q5K1 w - - 0 1")
        let queenMove = move(position, "a1a8")
        #expect(position.make(queenMove).isCheckmate)
        #expect(SAN.notation(for: queenMove, in: position) == "Qa8#")
        #expect(SAN.move(from: "Qa8#", in: position)?.uci == "a1a8")
        #expect(SAN.move(from: "Qa8", in: position)?.uci == "a1a8")
    }

    @Test func checkSuffixWithoutMate() throws {
        // Turm h1 → h7 gibt Schach an König h8; König kann nach g8 (kein Matt).
        let position = try Position(fen: "7k/8/6K1/8/8/8/8/7R w - - 0 1")
        #expect(SAN.notation(for: move(position, "h1h7"), in: position) == "Rh7+")
    }

    @Test func parseIgnoresCheckAndAnnotationMarks() throws {
        let position = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        #expect(SAN.move(from: "e4+", in: position)?.uci == "e2e4")
        #expect(SAN.move(from: "e4!?", in: position)?.uci == "e2e4")
    }

    @Test func parseUnknownSANReturnsNil() throws {
        let position = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        #expect(SAN.move(from: "e5", in: position) == nil)
        #expect(SAN.move(from: "kaputt", in: position) == nil)
    }
}
