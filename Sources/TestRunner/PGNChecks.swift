import Foundation
import ChessAppKit

func pgnChecks() throws {
    for counters in ["-1 1", "0 0", "oops 1", "0 9223372036854775807", "9223372036854775807 1"] {
        do {
            _ = try Position(fen: "4k3/8/8/8/8/8/8/4K3 b - - \(counters)")
            check(false, "FEN: invalid counters rejected \(counters)")
        } catch FenError.invalid { check(true, "FEN: invalid counters rejected \(counters)") }
    }
    let game = try PGN.parse("1. e4 ; annotation\ne5 2. Nf3 Nc6 *")
    checkEqual(game.sanList, ["e4", "e5", "Nf3", "Nc6"], "PGN: semicolon preserves next line")
    let nested = try PGN.parse("1.e4 {hello} (1.d4 (1...d5) d5) e5 $1 2.Nf3!? Nc6 *")
    checkEqual(nested.sanList.count, 4, "PGN: nested variations skipped")
    checkEqual(try PGN.parse(PGN.export(nested)).sanList, nested.sanList, "PGN: export roundtrip")
    do {
        _ = try PGN.parse("[FEN \"invalid\"]\n\n1. e4 *")
        check(false, "PGN: invalid FEN rejected")
    } catch PGNError.invalidFEN { check(true, "PGN: invalid FEN rejected") }
    do {
        _ = try PGN.parse("1. e4 e5 2. garbage Nf3 *")
        check(false, "PGN: invalid move rejected")
    } catch PGNError.unreadableMove { check(true, "PGN: invalid move rejected") }
    let castle = try PGN.parse("1.e4 e5 2.Nf3 Nc6 3.Bb5 a6 4.Ba4 Nf6 5.0-0 *")
    checkEqual(castle.sanList.last, "O-O", "PGN: zero notation castle")
    let black = try PGN.parse("[FEN \"4k3/8/8/8/8/8/8/4K3 b - - 0 23\"]\n\n23... Kd7 *")
    checkEqual(try PGN.parse(PGN.export(black)).positions.last?.fen, black.positions.last?.fen,
               "PGN: black-to-move FEN roundtrip")
}
