import Foundation
import CoreData
import ChessAppKit

@main
struct TrainingInsightsChecks {
    @MainActor static func main() throws {
        let context = PersistenceController(inMemory: true).context
        func result(_ id: String, _ solved: Bool) -> PuzzleResult {
            let item = PuzzleResult(context: context)
            item.puzzleID = id; item.solved = solved
            return item
        }
        let themes = ["fork-1": ["fork"], "fork-2": ["fork"], "mate": ["mateIn1"]]
        let attempts = [result("fork-1", false), result("fork-2", false), result("fork-1", true), result("mate", true), result("removed", false)]
        let progress = TrainingInsights.themes(results: attempts, themesByPuzzle: themes)
        assert(progress.first?.theme == "fork")
        assert(progress.first?.attempts == 3 && progress.first?.failed == 2)
        assert(TrainingInsights.recommendedTheme(in: progress)?.theme == "fork")
        assert(TrainingInsights.recommendedTheme(in: Array(progress.dropFirst())) == nil, "One result cannot establish a weakness")
        let own = SavedGame(context: context)
        own.whitePlayer = "Du"; own.blackPlayer = "Emil"
        let imported = SavedGame(context: context)
        imported.whitePlayer = "A"; imported.blackPlayer = "B"
        let parsed = try PGN.parse("1. e4 e5 2. Nf3 Nc6 *")
        let moves = parsed.moveList.enumerated().map { index, move in
            MoveAnalysis(ply: index + 1, san: parsed.sanList[index], fenBefore: parsed.positions[index].fen,
                fenAfter: parsed.positions[index + 1].fen, evalBefore: 0, evalAfter: -300,
                bestMove: move.uci, classification: .blunder, accuracy: 40,
                winPercentBefore: 50, winPercentAfter: 30, winPercentLoss: 20)
        }
        func entry(_ game: SavedGame, _ date: Date) throws -> GameAnalysisEntry {
            let item = GameAnalysisEntry(context: context)
            item.gameID = game.id; item.createdAt = date
            item.analysisJSON = try JSONEncoder().encode(GameAnalysis(moves: moves, accuracyWhite: 40, accuracyBlack: 40))
            return item
        }
        let old = try entry(own, Date(timeIntervalSince1970: 0))
        let latest = try entry(own, Date(timeIntervalSince1970: 5))
        let other = try entry(imported, Date())
        let summary = TrainingInsights.phases(games: [own, imported], entries: [old, other, latest])
        assert(summary.count == 1 && summary[0].moves == 2 && summary[0].errors == 2 && summary[0].games == 1,
               "Only own moves in the newest report of an own game count")
        own.whitePlayer = "Emil"; own.blackPlayer = "Du"
        assert(TrainingInsights.phases(games: [own], entries: [latest])[0].moves == 2)
        own.whitePlayer = "Du"
        assert(TrainingInsights.phases(games: [own], entries: [latest]).isEmpty, "Ambiguous own side excluded")
        print("Training insight checks passed: topics, sample thresholds, own sides, imports, latest analysis")
    }
}
