import Foundation
import CoreData
import ChessAppKit

@main
struct ClubFlowChecks {
    @MainActor static func main() throws {
        assert(BotLibrary.emil.name == "Emil" && BotLibrary.anna.name == "Anna", "Display first names without animal suffixes")
        let patterns = BotLibrary.allBots.map { PixelAvatarPattern.cells(for: $0.id) }
        assert(Set(patterns).count == patterns.count, "Every opponent has a distinct pixel avatar")
        for (bot, cells) in zip(BotLibrary.allBots, patterns) {
            assert(cells == PixelAvatarPattern.cells(for: bot.id), "Pixel avatars are stable")
            assert(cells.count == 7 && cells.allSatisfy { $0.count == 7 })
            assert(cells.allSatisfy { $0 == Array($0.reversed()) }, "Pixel patterns are symmetric")
            assert(cells.flatMap { $0 }.contains(true))
        }
        let context = PersistenceController(inMemory: true).context
        let game = SavedGame(context: context)
        game.whitePlayer = "Du"; game.blackPlayer = BotLibrary.emil.name; game.result = "1-0"
        assert(ClubProgress.ownSide(in: game) == .white)
        assert(ClubProgress.victories(against: BotLibrary.emil, games: [game]) == 1)
        game.whitePlayer = BotLibrary.emil.name; game.blackPlayer = "Du"; game.result = "0-1"
        assert(ClubProgress.ownSide(in: game) == .black)
        assert(ClubProgress.victories(against: BotLibrary.emil, games: [game]) == 1)
        for (bot, legacy) in [(BotLibrary.emil, "Emil Bär"), (BotLibrary.anna, "Anna Eule")] {
            game.whitePlayer = "Du"; game.blackPlayer = legacy; game.result = "1-0"
            assert(ClubProgress.victories(against: bot, games: [game]) == 1)
            game.whitePlayer = legacy; game.blackPlayer = "Du"; game.result = "0-1"
            assert(ClubProgress.victories(against: bot, games: [game]) == 1)
            game.blackPlayer = "Import"
            assert(ClubProgress.victories(against: bot, games: [game]) == 0)
        }
        game.result = "1/2-1/2"
        assert(ClubProgress.victories(against: BotLibrary.emil, games: [game]) == 0)
        game.whitePlayer = "Import"; game.blackPlayer = "Andere"; game.result = "1-0"
        assert(ClubProgress.ownSide(in: game) == nil)
        assert(ClubProgress.victories(against: BotLibrary.emil, games: [game]) == 0)
        game.whitePlayer = "Du"; game.blackPlayer = "Du"
        assert(ClubProgress.ownSide(in: game) == nil)
        game.whitePlayer = "Du"; game.blackPlayer = BotLibrary.emil.name
        let start = PGNGame().initialPosition
        let best = start.legalMoves().first { $0.uci == "e2e4" }!
        let played = start.legalMoves().first { $0.uci == "d2d4" }!
        let mistake = MoveAnalysis(ply: 1, san: "d4", fenBefore: start.fen, fenAfter: start.make(played).fen,
            evalBefore: 0, evalAfter: -300, bestMove: best.uci, classification: .blunder, accuracy: 40,
            winPercentBefore: 50, winPercentAfter: 30, winPercentLoss: 20)
        let report = GameAnalysis(moves: [mistake], accuracyWhite: 40, accuracyBlack: 100)
        assert(ClubProgress.practiceMoves(in: report, for: game).count == 1)
        game.whitePlayer = BotLibrary.emil.name; game.blackPlayer = "Du"
        assert(ClubProgress.practiceMoves(in: report, for: game).isEmpty, "Opponent errors are not personal training")
        let model = PlayViewModel()
        assert(!model.botMessage.isEmpty)
        let greeting = model.botMessage
        model.result = "1/2-1/2"
        assert(model.botMessage != greeting && model.botMessage.contains("Remis"))
        model.result = "1-0"
        assert(model.botMessage.contains("gewonnen"))
        let emilReaction = model.botMessage
        let settings = AppSettings.fetchOrCreate(context: context)
        settings.enginePath = "/usr/bin/true"
        model.botID = BotLibrary.anna.id
        model.playerColor = .black
        model.timeControl = .blitz3_2
        model.newGame(context: context)
        model.stop()
        model.result = "0-1"
        assert(model.botMessage != emilReaction, "Anna and Emil react differently to a human victory")
        model.botID = BotLibrary.pippa.id; model.playerColor = .white; model.timeControl = .unlimited
        model.rematch(context: context)
        model.stop()
        assert(model.activeBot.id == BotLibrary.anna.id && model.activePlayerColor == .black)
        assert(model.timeControl == .blitz3_2 && model.sans.isEmpty)
        print("Club flow checks passed: own sides, victories, imports, bot reactions")
    }
}
