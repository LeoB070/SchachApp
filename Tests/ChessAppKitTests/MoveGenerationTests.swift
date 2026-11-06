import Testing
import ChessAppKit

/// Zuggenerierung: Startstellung, Umwandlung, Rochade, En passant, Materialregel, Partieausgang.
@Suite
struct MoveGenerationTests {
    private let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    private func uciSet(_ moves: [Move]) -> Set<String> {
        Set(moves.map(\.uci))
    }

    @Test func startPositionHas20LegalMoves() throws {
        #expect(try Position(fen: startFEN).legalMoves().count == 20)
    }

    @Test func promotionUCIForms() throws {
        // Weißer Bauer a7, schwarzer König h7: alle vier Umwandlungen nach a8.
        // (Nackter Zug "a7a8" existiert nicht – Umwandlung ist auf der letzten Reihe Pflicht.)
        let position = try Position(fen: "8/P6k/8/8/8/8/8/7K w - - 0 1")
        let ucis = uciSet(position.legalMoves())
        for promotion in ["q", "r", "b", "n"] {
            #expect(ucis.contains("a7a8\(promotion)"), "Fehlt: a7a8\(promotion)")
        }
    }

    @Test func castlingLegalFromBothSides() throws {
        let position = try Position(fen: "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1")
        let ucis = uciSet(position.legalMoves())
        #expect(ucis.contains("e1g1"))
        #expect(ucis.contains("e1c1"))
    }

    @Test func castlingForbiddenWhenIntermediateSquareAttacked() throws {
        // Schwarzer Turm f3 greift f1 an → O-O verboten; O-O-O (d1/c1/b1 frei und sicher) bleibt erlaubt.
        let position = try Position(fen: "4k3/8/8/8/8/5r2/8/R3K2R w KQ - 0 1")
        let ucis = uciSet(position.legalMoves())
        #expect(ucis.contains("e1g1") == false)
        #expect(ucis.contains("e1c1"))
    }

    @Test func castlingForbiddenWhenKingInCheck() throws {
        // Schwarzer Turm e4 greift den König auf e1 → keine Rochade möglich.
        let position = try Position(fen: "4k3/8/8/8/4r3/8/8/R3K2R w KQ - 0 1")
        let ucis = uciSet(position.legalMoves())
        #expect(ucis.contains("e1g1") == false)
        #expect(ucis.contains("e1c1") == false)
    }

    @Test func enPassantCaptureSequence() throws {
        // e2e4, b8c6, e4e5, d7d5 → EP-Feld d6; weiß schlägt e5xd6 en passant, Bauer d5 verschwindet.
        let start = try Position(fen: startFEN)
        let afterE4 = start.make(Move(from: Square(string: "e2")!, to: Square(string: "e4")!, flags: .doublePush))
        let afterNc6 = afterE4.make(Move(from: Square(string: "b8")!, to: Square(string: "c6")!))
        let afterE5 = afterNc6.make(Move(from: Square(string: "e4")!, to: Square(string: "e5")!))
        let afterD5 = afterE5.make(Move(from: Square(string: "d7")!, to: Square(string: "d5")!, flags: .doublePush))

        #expect(afterD5.turn == .white)
        #expect(afterD5.enPassant?.name == "d6")

        let epMove = afterD5.legalMoves().first { $0.uci == "e5d6" }
        #expect(epMove != nil, "Passantenschlag e5d6 fehlt")
        #expect(epMove!.flags.contains(.enPassant))
        #expect(epMove!.flags.contains(.capture))

        let afterCapture = afterD5.make(epMove!)
        #expect(afterCapture.board[Square(string: "d5")!.index] == nil)
        #expect(afterCapture.board[Square(string: "d6")!.index] == Piece(color: .white, type: .pawn))
    }

    @Test func enPassantCaptureFromParsedFENBlackSide() throws {
        // Weißer Bauer e4 (gerade doppelgezogen), schwarzer Bauer d4 schlägt nach e3.
        let position = try Position(fen: "8/8/8/8/3pP3/8/8/k6K b - e3 0 1")
        let epMove = position.legalMoves().first { $0.uci == "d4e3" }
        #expect(epMove != nil, "Passantenschlag d4e3 fehlt")
        #expect(epMove!.flags.contains(.enPassant))

        let afterCapture = position.make(epMove!)
        #expect(afterCapture.board[Square(string: "e4")!.index] == nil)
        #expect(afterCapture.board[Square(string: "e3")!.index] == Piece(color: .black, type: .pawn))
    }

    @Test func insufficientMaterial() throws {
        #expect(try Position(fen: "8/8/8/8/8/8/8/k6K w - - 0 1").hasInsufficientMaterial())       // K – K
        #expect(try Position(fen: "8/8/8/8/8/4N3/8/k6K w - - 0 1").hasInsufficientMaterial())     // K+S – K
        #expect(try Position(fen: "8/8/8/8/8/8/8/k5RK w - - 0 1").hasInsufficientMaterial() == false) // K+T
        #expect(try Position(fen: "8/8/8/4B3/8/8/5b2/k6K w - - 0 1").hasInsufficientMaterial())   // Läufer gleiche Feldfarbe
        #expect(try Position(fen: "8/8/8/4B3/8/8/6b1/k6K w - - 0 1").hasInsufficientMaterial() == false) // ungleiche Farbe
    }

    @Test func gameOutcomeEvaluation() throws {
        let start = try Position(fen: startFEN)
        #expect(GameOutcome.evaluate(position: start, repetitionCount: 0) == .ongoing)
        #expect(GameOutcome.evaluate(position: start, repetitionCount: 3) == .threefold)

        // 50-Züge-Regel
        let longGame = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 100 60")
        #expect(GameOutcome.evaluate(position: longGame, repetitionCount: 2) == .fiftyMove)
        // Material geht vor 50 Züge
        let bareKings = try Position(fen: "8/8/8/8/8/8/8/k6K w - - 100 60")
        #expect(GameOutcome.evaluate(position: bareKings, repetitionCount: 2) == .insufficientMaterial)
        // Matt geht vor allem anderen (hier wären schon 9 Wiederholungen gezählt).
        // Schwarz am Zug: Turm a8 gibt entlang der 8. Reihe Matt gegen König h8,
        // der weiße König g6 deckt g7/h7 (Rückzüge).
        let mate = try Position(fen: "R6k/8/6K1/8/8/8/8/8 b - - 0 1")
        #expect(mate.isCheckmate)
        #expect(GameOutcome.evaluate(position: mate, repetitionCount: 9) == .checkmate(winner: .white))
        // Patt: Schwarz f8, Bauer f7 (Weiß), König f6 (Weiß) – kein Schach, kein Zug.
        let stalemate = try Position(fen: "5k2/5P2/5K2/8/8/8/8/8 b - - 0 1")
        #expect(stalemate.isStalemate)
        #expect(GameOutcome.evaluate(position: stalemate, repetitionCount: 0) == .stalemate)
    }
}
