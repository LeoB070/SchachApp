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
    let engine = BotCheckEngine()
    let fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    let bot = Bot(id: "check", name: "Check", description: "", elo: 400,
                  skillLevel: 0, randomness: 1, movetimeMs: 50)
    let move = try await bot.chooseMove(fen: fen, engine: engine)
    checkEqual(move, "e2e3", "Bot keeps completed MultiPV alternative")
    let limitedOptions = await engine.options
    checkEqual(limitedOptions["UCI_Elo"], "1320", "Bot clamps UCI Elo to supported minimum")
    checkEqual(limitedOptions["UCI_LimitStrength"], "true", "Weak bot limits engine strength")
    let strong = Bot(id: "strong", name: "Strong", description: "", elo: 3000,
                     skillLevel: 20, randomness: 0, movetimeMs: 50)
    checkEqual(try await strong.chooseMove(fen: fen, engine: engine), "e2e4", "Strong bot uses best move")
    let strongOptions = await engine.options
    checkEqual(strongOptions["UCI_LimitStrength"], "false", "Strong bot removes strength limit")
}
