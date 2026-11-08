import Foundation
import ChessAppKit
import CoreData

@main
struct PuzzleFlowChecks {
    @MainActor
    static func main() async throws {
        let fen = "6k1/p4ppp/8/8/8/8/8/4R1K1 b - - 0 1"
        let items = [
            PuzzleItem(id: "a1", fen: fen, moves: ["a7a6", "e1e8"], rating: 1000, themes: ["mateIn1", "backRankMate"]),
            PuzzleItem(id: "a2", fen: fen, moves: ["a7a6", "e1e8"], rating: 900, themes: ["mateIn1", "backRankMate"]),
            PuzzleItem(id: "b1", fen: fen, moves: ["a7a6", "e1e8"], rating: 1100, themes: ["mateIn1", "rookMate"])
        ]
        let model = PuzzleViewModel()
        model.rating = 1000
        model.loadPuzzles(from: items)
        assert(model.availableThemes == ["backRankMate", "mateIn1", "rookMate"])
        assert(model.currentPuzzle?.id == "a1", "All themes still chooses the closest rating")
        model.selectTheme("backRankMate")
        assert(model.currentPuzzle?.id == "a1")
        model.nextPuzzle()
        assert(model.currentPuzzle?.id == "a2", "Filtered pool must exhaust before repeating")
        model.nextPuzzle()
        assert(model.currentPuzzle?.id == "a1", "Filtered pool must restart even with other puzzles unattempted")
        model.showHint()
        assert(model.hintSquare == nil, "First hint gives idea without exposing piece")
        model.showHint()
        assert(model.hintSquare != nil)
        model.selectTheme("rookMate")
        assert(model.currentPuzzle?.id == "b1" && model.hintSquare == nil)
        model.nextPuzzle()
        assert(model.currentPuzzle?.id == "b1", "A single-item pool remains usable")
        assert(model.rating == 1000 && model.solvedCount == 0, "Switching/skipping must not record attempts")
        model.selectTheme("")
        var visited = Set<String>()
        for _ in items.indices {
            visited.insert(model.currentPuzzle!.id)
            model.nextPuzzle()
        }
        assert(visited == Set(items.map(\.id)), "Returning to all themes resets its attempted pool")
        model.selectTheme("unbekannt")
        assert(model.currentPuzzle == nil && model.legalTargets.isEmpty && model.selectedSquare == nil)
        assert(model.statusMessage.contains("Keine Puzzles"))
        model.selectTheme("backRankMate")
        assert(model.currentPuzzle?.themes.contains("backRankMate") == true)
        model.squareTapped(Square(string: "e1")!, context: nil)
        model.squareTapped(Square(string: "e8")!, context: nil)
        assert(model.state == .solved && model.solvedCount == 1 && model.rating > 1000)
        let solvedRating = model.rating
        model.showSolution()
        assert(model.rating == solvedRating && model.solvedCount == 1, "Solved attempts cannot be recorded twice")
        model.retryPuzzle()
        model.squareTapped(Square(string: "e1")!, context: nil)
        model.squareTapped(Square(string: "e8")!, context: nil)
        assert(model.rating == solvedRating, "Practice cannot inflate rating")
        model.nextPuzzle()
        model.showSolution()
        let failedRating = model.rating
        model.showSolution()
        assert(model.rating == failedRating, "Showing a solution twice records only one failure")
        model.loadPuzzles(from: [])
        assert(model.currentPuzzle == nil && model.availableThemes.isEmpty && model.selectedTheme.isEmpty)
        model.loadPuzzles(from: items)
        assert(model.currentPuzzle != nil, "Reloading data recovers from an empty pool")
        assert(PuzzleViewModel.themeTitle("backRankMate") == "Grundreihenmatt")
        assert(PuzzleViewModel.themeTitle("futureTheme") == "futureTheme")
        model.selectDifficulty(.beginner)
        assert(model.currentPuzzle == nil, "An empty difficulty pool must clear the board")
        model.selectDifficulty(.practice)
        assert(model.currentPuzzle != nil && model.eligiblePuzzles.count == 3)
        model.selectTheme("rookMate")
        assert(model.eligiblePuzzles.count == 1 && model.currentPuzzle?.id == "b1")
        assert(!PuzzleDifficulty.beginner.contains(701) && PuzzleDifficulty.beginner.contains(700))
        assert(PuzzleDifficulty.practice.contains(701) && PuzzleDifficulty.practice.contains(1100))
        assert(!PuzzleDifficulty.challenge.contains(1100) && PuzzleDifficulty.challenge.contains(1101))
        assert(PuzzleViewModel.themeTitle("fork") == "Springergabel")
        let url = ChessAppKitInfo.resourceBundle.url(forResource: "puzzles", withExtension: "json")!
        let bundled = try JSONDecoder().decode([PuzzleItem].self, from: Data(contentsOf: url))
        for puzzle in bundled.filter({ $0.themes.contains("promotion") || $0.themes.contains("fork") || $0.themes.contains("hangingPiece") }) {
            model.startPuzzle(puzzle)
            while model.state == .waitingForUser {
                let uci = puzzle.moves[model.moveIndex]
                model.squareTapped(Square(string: String(uci.prefix(2)))!, context: nil)
                model.squareTapped(Square(string: String(uci.dropFirst(2).prefix(2)))!, context: nil)
                if model.state == .opponentThinking { try await Task.sleep(nanoseconds: 450_000_000) }
            }
            assert(model.state == .solved, "New training puzzle must be solvable through board clicks: \(puzzle.id)")
        }
        var personal = PuzzleItem(id: "own-test", fen: items[0].fen, moves: items[0].moves, rating: 0, themes: ["ownMistake"])
        personal.sourceGame = "Du – Bot"
        model.loadPuzzles(from: items + [personal])
        model.selectTheme("")
        model.selectSource(.personal)
        model.selectDifficulty(.challenge)
        assert(model.eligiblePuzzles.count == 1 && model.currentPuzzle?.isPersonal == true)
        let beforeOwn = model.rating
        model.squareTapped(Square(string: "e1")!, context: nil)
        model.squareTapped(Square(string: "e8")!, context: nil)
        assert(model.state == .solved && model.rating == beforeOwn)
        assert(model.solutionExplanation.contains("Re8#") && !model.solutionExplanation.contains("e1e8"))
        assert(PuzzleViewModel.isClearTacticalChoice(EngineInfo(depth: 16, cp: 300), EngineInfo(depth: 16, cp: 100), side: .white))
        assert(!PuzzleViewModel.isClearTacticalChoice(EngineInfo(depth: 16, cp: 300), EngineInfo(depth: 16, cp: 250), side: .white))
        assert(PuzzleViewModel.isClearTacticalChoice(EngineInfo(depth: 16, cp: -300), EngineInfo(depth: 16, cp: -100), side: .black))
        assert(!PuzzleViewModel.isClearTacticalChoice(EngineInfo(depth: 16, mate: 2), EngineInfo(depth: 16, mate: 3), side: .white))
        model.retryPuzzle()
        model.streak = 7
        model.showSolution()
        assert(model.streak == 7, "Unrated practice leaves rated streak intact")
        model.startPuzzle(items[0])
        model.streak = 7
        model.showHint()
        model.showSolution()
        assert(model.streak == 7, "Assisted attempts leave rated streak intact")
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        model.startPuzzle(items[0])
        model.showHint()
        let assistedRating = model.rating
        model.showSolution(context: context)
        let results = try context.fetch(NSFetchRequest<PuzzleResult>(entityName: "PuzzleResult"))
        assert(results.count == 1 && !results[0].solved && model.rating == assistedRating)
        model.retryPuzzle()
        model.squareTapped(Square(string: "e1")!, context: context)
        model.squareTapped(Square(string: "e8")!, context: context)
        let retried = try context.fetch(NSFetchRequest<PuzzleResult>(entityName: "PuzzleResult"))
        assert(retried.count == 2 && retried.contains { $0.solved } && model.rating == assistedRating)
        model.preparing = true
        let oldRun = model.preparationID
        model.cancelPreparation()
        assert(!model.preparing && oldRun != model.preparationID)
        if ProcessInfo.processInfo.environment["CHESS_VERIFY_ENGINE"] == "1" {
            let engine = try UCIEngine(settings: EngineSettings(threads: 1, hashMB: 64))
            try await engine.start()
            let fen = "rnb1kb1r/p2p1ppp/5nq1/1p3N2/4PpPP/3P4/PPP5/RNBQ1KR1 w kq - 1 13"
            var latest: [Int: EngineInfo] = [:]
            for await info in engine.analyze(fen: fen, depth: 16, multiPV: 2) { latest[info.multiPV] = info }
            await engine.stop()
            assert(latest[1]?.depth == 16 && latest[2]?.depth == 16)
            assert(latest[1]?.pv.first == "h4h5")
            assert(PuzzleViewModel.isClearTacticalChoice(latest[1]!, latest[2]!, side: .white), "Real Stockfish own-candidate gate accepts unique winning tactic")
            print("Personal candidate read-only Stockfish smoke passed; no personal cache touched")
        }
        print("Puzzle flow checks passed: theme pools, cycle reset, empty/reload recovery and attempt/rating semantics")
    }
}
