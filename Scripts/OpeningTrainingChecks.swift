import Foundation
import ChessAppKit

@main
struct OpeningTrainingChecks {
    static func main() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let white = try OpeningLine(name: "Italienisch", pgn: "1. e4 e5 2. Nf3 Nc6 *", color: .white, now: now)
        var practice = try OpeningPractice(line: white)
        assert(practice.position.turn == .white && practice.ply == 0)
        assert(!practice.attempt(SAN.move(from: "d4", in: practice.position)!))
        assert(practice.ply == 0 && practice.hadError)
        assert(practice.attempt(SAN.move(from: "e4", in: practice.position)!))
        assert(practice.ply == 2 && practice.position.turn == .white)
        assert(practice.attempt(SAN.move(from: "Nf3", in: practice.position)!))
        assert(practice.complete && practice.ply == 4)
        var hinted = try OpeningPractice(line: white)
        hinted.hint()
        assert(hinted.usedHint && !hinted.complete && hinted.ply == 0)
        let black = try OpeningLine(name: "Schwarz", pgn: white.pgn, color: .black, now: now)
        let blackPractice = try OpeningPractice(line: black)
        assert(blackPractice.ply == 1 && blackPractice.position.turn == .black)
        var rejected = false
        do { _ = try OpeningLine(name: "leer", pgn: "1. e4 *", color: .black) } catch { rejected = true }
        assert(rejected)
        rejected = false
        do { _ = try OpeningLine(name: "kaputt", pgn: "1. Qh5 *", color: .white) } catch { rejected = true }
        assert(rejected)
        var scheduled = white
        scheduled.record(success: true, now: now)
        assert(scheduled.dueAt == now.addingTimeInterval(86400) && scheduled.stage == 1)
        scheduled.record(success: true, now: now)
        assert(scheduled.stage == 1 && scheduled.dueAt == now.addingTimeInterval(86400))
        scheduled.record(success: true, now: now.addingTimeInterval(86400))
        assert(scheduled.stage == 2 && scheduled.dueAt == now.addingTimeInterval(4 * 86400))
        scheduled.record(success: false, now: now)
        assert(scheduled.stage == 0 && scheduled.dueAt == now.addingTimeInterval(86400))
        let counters = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 17 45")
        assert(counters.repetitionKey == PGNGame().initialPosition.repetitionKey)
        let transpositionA = try PGN.parse("1. Nf3 Nf6 2. d4 d5 *").positions.last!
        let transpositionB = try PGN.parse("1. d4 d5 2. Nf3 Nf6 *").positions.last!
        assert(OpeningExplorer.positionKey(transpositionA) == OpeningExplorer.positionKey(transpositionB))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OpeningRepertoireStore(url: root.appendingPathComponent("lines.json"))
        let empty = try store.load()
        assert(empty.isEmpty)
        try store.save([white, black])
        let reloaded = try store.load()
        assert(reloaded.map(\.id) == [white.id, black.id])
        let duplicate = try OpeningLine(name: "other", pgn: "1.e4 e5 2.Nf3 Nc6 *", color: .white)
        assert(white.signature == duplicate.signature)
        try Data("broken".utf8).write(to: store.url)
        rejected = false
        do { try store.save([white]) } catch { rejected = true }
        let preserved = try String(contentsOf: store.url, encoding: .utf8)
        assert(rejected && preserved == "broken")
        let records = [
            OpeningGameRecord(id: UUID(), white: "Du", black: "Bot", result: "1-0", pgn: "1. e4 e5 *"),
            OpeningGameRecord(id: UUID(), white: "Bot", black: "Du", result: "0-1", pgn: "1. e4 c5 *"),
            OpeningGameRecord(id: UUID(), white: "Du", black: "Du", result: "1-0", pgn: "1. d4 *"),
            OpeningGameRecord(id: UUID(), white: "A", black: "B", result: "1-0", pgn: "1. d4 *")
        ]
        let rows = OpeningExplorer.rows(records: records, at: counters, ownColor: .white)
        assert(rows.count == 1 && rows[0].san == "e4" && rows[0].wins == 1 && rows[0].count == 1)
        let blackRows = OpeningExplorer.rows(records: records, at: counters, ownColor: .black)
        assert(blackRows.count == 1 && blackRows[0].wins == 1)
        let promotion = try OpeningLine(name: "Umwandlung", pgn: "[FEN \"8/P6k/8/8/8/8/7K/8 w - - 0 1\"]\n\n1. a8=N *", color: .white)
        var promotionPractice = try OpeningPractice(line: promotion)
        assert(promotionPractice.attempt(promotionPractice.game.moveList[0]) && promotionPractice.complete)
        print("Opening training checks passed")
    }
}
