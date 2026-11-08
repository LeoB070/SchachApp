import Foundation
import ChessAppKit

/// Counts recorded training outcomes; these include assisted attempts and repetitions.
enum TrainingInsights {
    struct ThemeProgress: Identifiable {
        let theme: String
        let attempts: Int
        let failed: Int
        var id: String { theme }
        var failureRate: Double { Double(failed) / Double(attempts) }
    }

    struct PhaseProgress: Identifiable {
        let phase: GamePhase
        let moves: Int
        let errors: Int
        let games: Int
        var id: String { phase.rawValue }
    }

    static func themes(results: [PuzzleResult], themesByPuzzle: [String: [String]]) -> [ThemeProgress] {
        var counts: [String: (attempts: Int, failed: Int)] = [:]
        for result in results {
            for theme in Set(themesByPuzzle[result.puzzleID] ?? []) {
                counts[theme, default: (0, 0)].attempts += 1
                if !result.solved { counts[theme, default: (0, 0)].failed += 1 }
            }
        }
        return counts.map { ThemeProgress(theme: $0.key, attempts: $0.value.attempts, failed: $0.value.failed) }
            .sorted {
                if $0.failureRate != $1.failureRate { return $0.failureRate > $1.failureRate }
                if $0.attempts != $1.attempts { return $0.attempts > $1.attempts }
                return $0.theme < $1.theme
            }
    }

    static func recommendedTheme(in progress: [ThemeProgress]) -> ThemeProgress? {
        progress.first { $0.attempts >= 3 && $0.failed > 0 }
    }

    static func phases(games: [SavedGame], entries: [GameAnalysisEntry]) -> [PhaseProgress] {
        var seen = Set<UUID>()
        var counts: [GamePhase: (moves: Int, errors: Int, games: Set<UUID>)] = [:]
        for entry in entries.sorted(by: { $0.createdAt > $1.createdAt }) {
            guard let gameID = entry.gameID, seen.insert(gameID).inserted,
                  let game = games.first(where: { $0.id == gameID }),
                  let own = ClubProgress.ownSide(in: game),
                  let report = try? JSONDecoder().decode(GameAnalysis.self, from: entry.analysisJSON) else { continue }
            var plies = Set<Int>()
            for move in report.moves {
                guard move.ply > 0, plies.insert(move.ply).inserted,
                      move.winPercentLoss.isFinite, (0...100).contains(move.winPercentLoss),
                      let position = try? Position(fen: move.fenBefore), position.turn == own else { continue }
                counts[move.phase, default: (0, 0, [])].moves += 1
                if move.winPercentLoss >= 10 { counts[move.phase, default: (0, 0, [])].errors += 1 }
                counts[move.phase, default: (0, 0, [])].games.insert(gameID)
            }
        }
        return GamePhase.allCases.compactMap { phase in
            counts[phase].map { PhaseProgress(phase: phase, moves: $0.moves, errors: $0.errors, games: $0.games.count) }
        }
    }
}
