import Testing
import ChessAppKit

/// FEN-Parsen/-Schreiben (Roundtrip) und Wiederholungs-Schlüssel.
@Suite
struct FENTests {
    private let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    @Test func startRoundtrip() throws {
        #expect(try Position(fen: startFEN).fen == startFEN)
    }

    @Test func kiwipeteRoundtrip() throws {
        let fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
        #expect(try Position(fen: fen).fen == fen)
    }

    @Test func impossibleEnPassantFieldRoundtrip() throws {
        // EP-Feld ohne möglichen Passantenschlag wird trotzdem übernommen.
        let fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq e3 0 1"
        let position = try Position(fen: fen)
        #expect(position.enPassant?.name == "e3")
        #expect(position.fen == fen)
    }

    @Test func invalidFenThrows() {
        #expect(throws: FenError.self) {
            try Position(fen: "unmoeglich")
        }
    }

    @Test func repetitionKeyIsFirstFourFENFields() throws {
        let expected = startFEN.split(separator: " ").prefix(4).joined(separator: " ")
        #expect(try Position(fen: startFEN).repetitionKey == expected)
    }
}
