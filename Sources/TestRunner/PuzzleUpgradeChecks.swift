import Foundation
import ChessAppKit

func puzzleUpgradeChecks() throws {
    struct Fixture: Decodable {
        let id: String
        let fen: String
        let moves: [String]
        let themes: [String]
        let explanation: String?
    }
    let url = ChessAppKitInfo.resourceBundle.url(forResource: "puzzles", withExtension: "json")!
    let puzzles = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
    check(puzzles.count >= 50, "Expanded puzzle collection")
    for puzzle in puzzles {
        let position = try Position(fen: puzzle.fen)
        check(!position.isInCheck(position.turn.flipped), "\(puzzle.id) legal starting turn")
    }
    let combinations = puzzles.filter { $0.id.hasPrefix("combo-") }
    check(combinations.count >= 6, "At least six verified multi-move combinations")
    check(combinations.contains { $0.themes.contains("mateIn2") }, "Mate in two training")
    for puzzle in combinations {
        check(puzzle.moves.count >= 4, "\(puzzle.id) has multiple player decisions")
        check(!(puzzle.explanation ?? "").isEmpty, "\(puzzle.id) explains its idea")
        var position = try Position(fen: puzzle.fen)
        for uci in puzzle.moves {
            guard let move = position.legalMoves().first(where: { $0.uci == uci }) else {
                check(false, "\(puzzle.id) illegal line")
                break
            }
            check(SAN.notation(for: move, in: position) != "???", "\(puzzle.id) SAN available")
            position = position.make(move)
        }
        if puzzle.themes.contains("mateIn2") || puzzle.themes.contains("mateIn3") {
            check(position.isCheckmate, "\(puzzle.id) ends in mate")
        }
    }
}
