import Testing
import ChessAppKit

/// Zählt Blattknoten (Rekursion: make + legalMoves).
@Suite
struct PerftTests {
    private func perft(_ position: Position, _ depth: Int) -> Int {
        if depth == 0 { return 1 }
        if depth == 1 { return position.legalMoves().count }
        var count = 0
        for move in position.legalMoves() {
            count += perft(position.make(move), depth - 1)
        }
        return count
    }

    @Test func perftStartPosition() throws {
        let position = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        #expect(perft(position, 1) == 20)
        #expect(perft(position, 2) == 400)
        #expect(perft(position, 3) == 8902)
        #expect(perft(position, 4) == 197281)
    }

    @Test func perftKiwipete() throws {
        let position = try Position(fen: "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
        #expect(perft(position, 1) == 48)
        #expect(perft(position, 2) == 2039)
        #expect(perft(position, 3) == 97862)
    }

    @Test func perftPosition3() throws {
        let position = try Position(fen: "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
        #expect(perft(position, 1) == 14)
        #expect(perft(position, 2) == 191)
        #expect(perft(position, 3) == 2812)
    }
}
