import Foundation
import Testing
import ChessAppKit

@Suite
struct PuzzleDataTests {
    private struct Puzzle: Decodable {
        let id: String
        let fen: String
        let moves: [String]
        let rating: Int
        let themes: [String]
    }

    @Test func bundledSolutionsAreLegalAndMateLabelsAreTrue() throws {
        let url = try #require(ChessAppKitInfo.resourceBundle.url(forResource: "puzzles", withExtension: "json"))
        let puzzles = try JSONDecoder().decode([Puzzle].self, from: Data(contentsOf: url))
        #expect(puzzles.count >= 50)
        #expect(puzzles.filter { $0.moves.count >= 4 }.count >= 6)
        #expect(puzzles.contains { $0.themes.contains("mateIn2") })
        #expect(Set(puzzles.map(\.id)).count == puzzles.count)
        #expect(Set(puzzles.map(\.fen)).count == puzzles.count)
        var playerColors: Set<String> = []
        for puzzle in puzzles {
            #expect(puzzle.rating > 0)
            #expect(!puzzle.themes.isEmpty)
            #expect(puzzle.moves.count >= 2 && puzzle.moves.count.isMultiple(of: 2))
            var position = try Position(fen: puzzle.fen)
            #expect(!position.isInCheck(position.turn.flipped), "Side not to move cannot already be in check: \(puzzle.id)")
            for (index, uci) in puzzle.moves.enumerated() {
                let move = try #require(position.legalMoves().first { $0.uci == uci }, "\(puzzle.id): \(uci)")
                position = position.make(move)
                if index == 0 { playerColors.insert(position.turn == .white ? "white" : "black") }
            }
            if puzzle.themes.contains(where: { $0.lowercased().contains("mate") }) {
                #expect(position.isCheckmate, "\(puzzle.id) must end in mate")
            }
        }
        #expect(playerColors == ["white", "black"])
    }
}
