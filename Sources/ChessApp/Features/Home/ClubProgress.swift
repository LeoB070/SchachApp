import Foundation
import ChessAppKit

/// Fortschritt aus vorhandenen Partien; importierte Spielernamen werden nicht als eigene Spiele gezählt.
enum ClubProgress {
    static func ownSide(in game: SavedGame) -> PieceColor? {
        guard (game.whitePlayer == "Du") != (game.blackPlayer == "Du") else { return nil }
        return game.whitePlayer == "Du" ? .white : .black
    }

    static func victories(against bot: Bot, games: [SavedGame]) -> Int {
        games.filter { game in
            guard let side = ownSide(in: game) else { return false }
            let opponent = side == .white ? game.blackPlayer : game.whitePlayer
            return BotLibrary.matchesSavedName(opponent, bot: bot) && game.result == (side == .white ? "1-0" : "0-1")
        }.count
    }

    static func practiceMoves(in report: GameAnalysis, for game: SavedGame) -> [MoveAnalysis] {
        guard let side = ownSide(in: game) else { return [] }
        return report.moves.filter { move in
            guard move.winPercentLoss.isFinite, move.winPercentLoss > 10, let position = try? Position(fen: move.fenBefore),
                  position.turn == side,
                  let best = position.legalMoves().first(where: { $0.uci == move.bestMove }) else { return false }
            return position.make(best).fen != move.fenAfter
        }.sorted { $0.winPercentLoss > $1.winPercentLoss }
    }
}
