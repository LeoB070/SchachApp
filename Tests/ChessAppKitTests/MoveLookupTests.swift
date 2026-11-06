// Zugsuche: UI-Klick (from/to, optional Umwandlung) -> fuelliger legaler Zug
// (inkl. flags wie enPassant/capture/Rochade). Erstellt fuer BoardView/PlayViewModel.
import Testing
import ChessAppKit

@Suite
struct MoveLookupTests {
    @Test func epCaptureCarriesFlags() throws {
        var p = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        for uci in ["e2e4", "b8c6", "e4e5", "d7d5"] {
            p = p.make(#require(p.legalMoves().first { $0.uci == uci }))
        }
        #expect(p.enPassant?.name == "d6")
        let ep = try #require(p.move(from: Square(file: 4, rank: 4), to: Square(file: 3, rank: 5)))
        #expect(ep.flags.contains(.enPassant))
        #expect(ep.flags.contains(.capture))
        #expect(p.make(ep).board[Square(file: 3, rank: 4).index] == nil)
    }
}
