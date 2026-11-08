import Foundation
import CoreData
import ChessAppKit

@main
struct TrainingPositionChecks {
    @MainActor
    static func main() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.context
        let settings = AppSettings.fetchOrCreate(context: context)
        settings.enginePath = "/usr/bin/true"
        settings.soundEnabled = false
        let source = SavedGame(context: context)
        source.pgn = "1. e4 e5 *"
        try context.save()
        let position = try Position(fen: "7k/8/8/8/8/8/4P3/4K3 w - - 0 23")
        let model = PlayViewModel()
        model.startTraining(position: position, playerColor: .white, botID: BotLibrary.emil.id, context: context)
        assert(model.isTraining && model.currentPosition == position && model.sans.isEmpty)
        model.squareTapped(Square(string: "e2")!, context: context)
        model.squareTapped(Square(string: "e4")!, context: context)
        assert(model.sans == ["e4"])
        let trainingPGN = try PGN.parse(model.exportPGN())
        assert(trainingPGN.initialPosition == position && trainingPGN.positions.last == model.currentPosition)
        model.resign(context: context)
        model.save(context: context)
        assert(model.savedGame == nil)
        let count = try context.count(for: NSFetchRequest<SavedGame>(entityName: "SavedGame"))
        assert(count == 1)
        assert(source.pgn == "1. e4 e5 *", "Training preserves original game")
        model.rematch(context: context)
        assert(model.isTraining && model.currentPosition == position && model.sans.isEmpty)
        model.stop()
        model.startTraining(position: position, playerColor: .black, botID: BotLibrary.emil.id, context: context)
        assert(model.activePlayerColor == .black && model.isThinking, "Bot starts when opposite side is to move")
        model.stop()
        let mate = try Position(fen: "7k/6Q1/5K2/8/8/8/8/8 b - - 0 1")
        model.startTraining(position: mate, playerColor: .white, botID: BotLibrary.emil.id, context: context)
        assert(model.result == "1-0" && !model.isThinking && model.savedGame == nil)
        let stalemate = try Position(fen: "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
        model.startTraining(position: stalemate, playerColor: .white, botID: BotLibrary.emil.id, context: context)
        assert(model.result == "1/2-1/2" && !model.isThinking)
        model.playerColor = .white
        model.newGame(context: context)
        assert(!model.isTraining && model.currentPosition == PGNGame().initialPosition)
        model.stop()
        for exercise in EndgameExercise.all {
            let initial = try Position(fen: exercise.fen)
            assert(GameOutcome.evaluate(position: initial, repetitionCount: 1) == .ongoing)
            assert(!exercise.goalReached(in: initial, player: .white))
        }
        let promoted = try Position(fen: "Q7/7k/8/8/8/8/8/K7 b - - 0 1")
        assert(EndgameExercise.all.last!.goalReached(in: promoted, player: .white))
        print("Training position checks passed: custom FEN, PGN, archive isolation, restart, side-to-move, terminal positions and goals")
    }
}
