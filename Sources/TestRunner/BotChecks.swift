import Foundation
import ChessAppKit

private actor BotCheckEngine: ChessEngine {
    private(set) var options: [String: String] = [:]
    func start() async throws {}
    func stop() async {}
    func setOption(name: String, value: String) async throws { options[name] = value }
    func bestMove(fen: String, movetimeMs: Int) async throws -> String { "e2e4" }
    nonisolated func analyze(fen: String, depth: Int, multiPV: Int) -> AsyncStream<EngineInfo> {
        AsyncStream { continuation in
            continuation.yield(EngineInfo(depth: depth, multiPV: 1, pv: ["e2e4"]))
            continuation.yield(EngineInfo(depth: depth, multiPV: 2, pv: ["e2e3"]))
            continuation.finish()
        }
    }
}

func botChecks() async throws {
    checkEqual(BotLibrary.allBots.filter { $0.elo <= 1000 }.map(\.elo), Array(stride(from: 100, through: 1000, by: 100)), "Beginner opponents in 100 Elo steps")
    checkEqual(Set(BotLibrary.allBots.map(\.id)).count, BotLibrary.allBots.count, "Unique bot identities")
    checkEqual(BotLibrary.emil.name, "Emil", "Neutral first name")
    checkEqual(BotLibrary.anna.name, "Anna", "Neutral first name")
    check(BotLibrary.matchesSavedName("Emil Bär", bot: BotLibrary.emil), "Legacy Emil archive name")
    check(BotLibrary.matchesSavedName("Anna Eule", bot: BotLibrary.anna), "Legacy Anna archive name")
    for bot in BotLibrary.allBots {
        check(BotLibrary.matchesSavedName(bot.name, bot: bot), "Current archive name: \(bot.id)")
    }
    check(!BotLibrary.matchesSavedName("Emil Bär", bot: BotLibrary.anna), "Legacy names do not match other opponents")
    let randomEngine = BotCheckEngine()
    let beginner = Bot(id: "random", name: "Random", description: "", elo: 100, skillLevel: 0, randomness: 1, movetimeMs: 50)
    let randomFEN = "8/8/8/8/8/8/4K3/7k w - - 0 1"
    let randomMove = try await beginner.chooseMove(fen: randomFEN, engine: randomEngine)
    check(try Position(fen: randomFEN).legalMoves().contains { $0.uci == randomMove }, "Beginner always chooses a legal move without engine advice")
    let randomOptions = await randomEngine.options
    check(randomOptions.isEmpty, "Pure beginner move does not require engine advice")
    let mateFEN = "R6k/8/6K1/8/8/8/8/8 b - - 0 1"
    checkEqual(try await beginner.chooseMove(fen: mateFEN, engine: randomEngine), "0000", "No move in terminal position")
    let engine = BotCheckEngine()
    let fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    let bot = Bot(id: "check", name: "Check", description: "", elo: 1400,
                  skillLevel: 0, randomness: 1, movetimeMs: 50)
    let move = try await bot.chooseMove(fen: fen, engine: engine)
    checkEqual(move, "e2e3", "Bot keeps completed MultiPV alternative")
    let limitedOptions = await engine.options
    checkEqual(limitedOptions["UCI_Elo"], "1400", "Bot configures supported UCI Elo")
    checkEqual(limitedOptions["UCI_LimitStrength"], "true", "Weak bot limits engine strength")
    let strong = Bot(id: "strong", name: "Strong", description: "", elo: 3000,
                     skillLevel: 20, randomness: 0, movetimeMs: 50)
    checkEqual(try await strong.chooseMove(fen: fen, engine: engine), "e2e4", "Strong bot uses best move")
    let strongOptions = await engine.options
    checkEqual(strongOptions["UCI_LimitStrength"], "false", "Strong bot removes strength limit")
}
