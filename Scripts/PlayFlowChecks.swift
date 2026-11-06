import Foundation
import CoreData
import ChessAppKit

@main
struct PlayFlowChecks {
    @MainActor
    static func main() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.context
        let settings = AppSettings.fetchOrCreate(context: context)
        // No process is started: all queued bot tasks are cancelled synchronously below.
        settings.enginePath = "/usr/bin/true"
        settings.soundEnabled = false
        let model = PlayViewModel()
        model.timeControl = .blitz3_2
        model.newGame(context: context)
        model.tick(context: context, now: Date().addingTimeInterval(5))
        assert(abs(model.whiteTime! - 175) < 1)
        assert(model.blackTime == 180)
        model.squareTapped(Square(string: "e2")!, context: context)
        model.squareTapped(Square(string: "e4")!, context: context)
        assert(model.sans == ["e4"])
        assert(abs(model.whiteTime! - 177) < 1, "Increment must go to the mover")
        model.squareTapped(Square(string: "e7")!, context: context)
        assert(model.selectedSquare == nil, "Human cannot select the bot's pieces")
        model.resign(context: context)
        assert(model.result == "0-1")
        let parsed = try PGN.parse(model.savedGame!.pgn)
        assert(parsed.sanList == ["e4"])
        model.save(context: context)
        let request = NSFetchRequest<SavedGame>(entityName: "SavedGame")
        let savedCount = try context.count(for: request)
        assert(savedCount == 1, "Autosave must not create duplicates")
        model.playerColor = .black
        model.newGame(context: context)
        model.resign(context: context)
        assert(model.result == "1-0", "Resignation depends on the human's color")
        model.playerColor = .white
        model.timeControl = .blitz5_0
        model.newGame(context: context)
        model.tick(context: context, now: Date().addingTimeInterval(301))
        assert(model.result == "0-1" && model.whiteTime == 0)
        model.squareTapped(Square(string: "e2")!, context: context)
        assert(model.selectedSquare == nil, "Finished games reject input")
        let finalCount = try context.count(for: request)
        assert(finalCount == 3)
        print("Play flow checks passed: clocks, increment, turn gating, resignation, timeout, autosave")
    }
}
