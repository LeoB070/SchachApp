import Foundation
import ChessAppKit

@main
struct ReviewCandidateChecks {
    static func main() throws {
        let game = try PGN.parse("1. e4 e5 *")
        let before = game.initialPosition
        let best = before.legalMoves().first { $0.uci == "d2d4" }!
        func moment(loss: Double) -> MoveAnalysis {
            MoveAnalysis(ply: 1, san: "e4", fenBefore: before.fen, fenAfter: game.positions[1].fen,
                         evalBefore: 50, evalAfter: -200, bestMove: best.uci, classification: .mistake,
                         accuracy: 30, winPercentBefore: 70, winPercentAfter: 70 - loss, winPercentLoss: loss)
        }
        var practice = ReviewPractice()
        practice.startCandidates(moment(loss: 20))
        assert(practice.isCandidateChoice && practice.candidates.count == 2)
        let wrong = practice.candidates.first { $0.uci == "e2e4" }!
        practice.attempt(wrong)
        assert(practice.revealed && practice.feedback!.contains("Partiezug"))
        assert(practice.position == before, "Candidate quiz must not mutate original position")
        practice.startCandidates(moment(loss: 2))
        assert(practice.moment == nil, "Small gaps aren't meaningful choices")
        practice.startCandidates(moment(loss: 20))
        practice.attempt(best)
        assert(practice.revealed && practice.feedback!.contains("Empfehlung"))
        let mate = try Position(fen: "7k/8/5KQ1/8/8/8/8/8 w - - 0 1")
        let matingMove = mate.legalMoves().first { $0.uci == "g6g7" }!
        assert(ReviewPractice.moveFacts(matingMove, in: mate).contains("Matt"))
        let capture = try Position(fen: "7k/8/8/8/8/8/1r6/KR6 w - - 0 1")
        let take = capture.legalMoves().first { $0.uci == "b1b2" }!
        assert(ReviewPractice.moveFacts(take, in: capture).contains("Turm"))
        assert(!ReviewPractice.moveFacts(best, in: before).contains("Matt"))
        print("Review candidate checks passed: meaningful gap, two legal alternatives, reveal, source isolation and factual check/mate/capture text")
    }
}
