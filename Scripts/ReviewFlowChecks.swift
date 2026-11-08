import Foundation
import ChessAppKit

@main
struct ReviewFlowChecks {
    @MainActor
    static func main() throws {
        let parsed = try PGN.parse("1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 *")
        func entry(_ index: Int, loss: Double = 20, best: String? = nil) -> MoveAnalysis {
            let before = parsed.positions[index]
            let alternative = before.legalMoves().first { before.make($0).fen != parsed.positions[index + 1].fen }!
            return MoveAnalysis(ply: index + 1, san: parsed.sanList[index], fenBefore: before.fen,
                fenAfter: parsed.positions[index + 1].fen, evalBefore: 0, evalAfter: -100,
                bestMove: best ?? alternative.uci, classification: .mistake, accuracy: 30,
                winPercentBefore: 50, winPercentAfter: 30, winPercentLoss: loss)
        }
        let entries = (0..<6).map { entry($0, loss: Double($0 + 1)) }
        let own = ReviewPractice.moments(analyses: entries, positions: parsed.positions, ownSide: .black)
        assert(own.map(\.ply) == [6, 4, 2], "Choose largest losses from the player's side")
        assert(ReviewPractice.moments(analyses: entries, positions: parsed.positions, ownSide: nil).count == 3)
        assert(ReviewPractice.moments(analyses: [entry(0, best: "e2e5")], positions: parsed.positions, ownSide: nil).isEmpty)
        assert(ReviewPractice.moments(analyses: [entry(0, loss: 0)], positions: parsed.positions, ownSide: nil).isEmpty)
        assert(ReviewPractice.moments(analyses: entries, positions: [], ownSide: nil).isEmpty)
        var practice = ReviewPractice()
        practice.start(own[0])
        let source = practice.position!.fen
        let move = practice.position!.legalMoves().first { $0.uci == own[0].bestMove }!
        let other = practice.position!.legalMoves().first { $0 != move }!
        practice.attempt(other)
        assert(!practice.revealed && practice.feedback != nil, "Other legal moves allow another try")
        practice.attempt(move)
        assert(practice.revealed && practice.feedback != nil)
        assert(practice.position!.fen == source, "Practice must preserve the source position")
        practice.reset()
        assert(practice.moment == nil && practice.selected == nil && !practice.revealed && practice.feedback == nil)
        let promotionPosition = try Position(fen: "7k/P7/8/8/8/8/8/7K w - - 0 1")
        let promotion = promotionPosition.legalMoves().first { $0.uci == "a7a8n" }!
        let promoted = promotionPosition.make(promotion)
        let promotionMoment = MoveAnalysis(ply: 1, san: "a8=Q", fenBefore: promotionPosition.fen,
            fenAfter: promotionPosition.make(promotionPosition.legalMoves().first { $0.uci == "a7a8q" }!).fen,
            evalBefore: 0, evalAfter: 0, bestMove: promotion.uci, classification: .mistake,
            accuracy: 30, winPercentBefore: 50, winPercentAfter: 30, winPercentLoss: 20)
        practice.start(promotionMoment)
        practice.tap(Square(string: "a7")!)
        practice.tap(Square(string: "a8")!)
        assert(practice.pendingPromotion != nil && !practice.revealed)
        practice.promote(.knight)
        assert(practice.revealed && practice.solution?.uci == "a7a8n")
        assert(promoted.board[Square(string: "a8")!.index]?.type == .knight)
        practice.start(own[0])
        assert(!practice.revealed && practice.pendingPromotion == nil && practice.feedback == nil)
        let persistence = PersistenceController(inMemory: true)
        let saved = SavedGame(context: persistence.context)
        saved.whitePlayer = "Bot"; saved.blackPlayer = "Du"
        saved.pgn = "1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 *"
        saved.whitePlayer = "Emil"
        let model = ReviewViewModel()
        model.load(saved, context: persistence.context)
        model.loadGame(positions: parsed.positions, sans: parsed.sanList, analyses: entries, whiteAcc: 71, blackAcc: 63)
        assert(model.configuredBot(for: .white)?.elo == 500)
        assert(model.configuredBot(for: .black) == nil)
        assert(model.performanceText(for: .white) == "–", "Short games must not invent performance ratings")
        assert(model.performanceText(for: .black, phase: .endgame) == "–", "Missing phases have no rating")
        let longEntries = Array(repeating: entries, count: 10).flatMap { $0 }
        model.loadGame(positions: parsed.positions, sans: parsed.sanList, analyses: longEntries, whiteAcc: 60, blackAcc: 90)
        assert(model.performanceText(for: .black) == "≈ 850", "Player estimate uses Emil's 500 Elo as context")
        assert(model.performanceText(for: .white) == "≈ 150", "Bot performance and configured strength remain distinct")
        model.loadGame(positions: parsed.positions, sans: parsed.sanList, analyses: entries, whiteAcc: 71, blackAcc: 63)

        assert(model.keyMoments.map(\.ply) == [6, 4, 2])
        model.startPractice(model.keyMoments[0])
        model.practice.attempt(model.practice.solution!)
        model.nextMoment()
        assert(model.practice.moment?.ply == 4 && !model.practice.revealed)
        let meaningful = entry(1, loss: 20)
        model.loadGame(positions: parsed.positions, sans: parsed.sanList, analyses: [entries[0], meaningful] + Array(entries.dropFirst(2)), whiteAcc: 71, blackAcc: 63)
        assert(model.candidateMoments.map(\.ply) == [2])
        model.startCandidatePractice(meaningful)
        assert(model.practice.isCandidateChoice && model.currentEvalText == "?" && model.winPercentWhite == 50)
        model.practice.attempt(model.practice.solution!)
        assert(model.practice.revealed && model.currentEvalText != "?")
        model.nextMoment()
        assert(model.practice.moment == nil, "Candidate sequence stays within meaningful own errors")
        model.cancelAnalysis()
        assert(model.practice.moment == nil)
        assert(model.accuracyWhite == 71 && model.accuracyBlack == 63 && model.moveAnalyses.count == entries.count)
        assert(saved.pgn == "1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 *")
        model.startPractice(model.keyMoments[0])
        model.loadGame(positions: [], sans: [])
        assert(model.practice.moment == nil && model.keyMoments.isEmpty)
        print("Review flow checks passed: own side, impact ranking, legal alternatives, empty cases, retry and reset")
    }
}
