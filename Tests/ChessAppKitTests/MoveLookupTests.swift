// Zugsuche: UI-Klick (from/to, optional Umwandlung) -> fuelliger legaler Zug
// (inkl. flags wie enPassant/capture/Rochade). Erstellt fuer BoardView/PlayViewModel.
import Testing
import ChessAppKit

@Suite
struct MoveLookupTests {
    @Test func epCaptureCarriesFlags() throws {
        var p = try Position(fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1")
        let black = try #require(SAN.move(from: "d7d5", in: p))
        p = p.make(black)
        let ep = p.move(from: Square(file: 4, rank: 3), to: Square(string: "d6")!)
        #expect(ep != nil)
        #expect(ep?.flags.contains(.enPassant) == true)
        #expect(ep?.flags.contains(.capture) == true)
        let after = p.make(ep!)
        #expect(after.board[Square(string: "d5")!.index] == nil)
    }
}
