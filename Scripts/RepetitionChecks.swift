import Foundation
import CoreData
import ChessAppKit

@main
struct RepetitionChecks {
    @MainActor static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("reviews.json")
        let now = Date(timeIntervalSince1970: 1_000_000)
        var schedule = try PuzzleReviewStore.load(from: url)
        assert(schedule.dueCount(now: now) == 0)
        schedule.record(id: "puzzle", solved: true, assisted: false, now: now)
        assert(schedule.entries["puzzle"]?.level == 1)
        assert(schedule.entries["puzzle"]?.dueAt == now.addingTimeInterval(86400))
        assert(schedule.dueCount(now: now) == 0 && schedule.dueCount(now: now.addingTimeInterval(86400)) == 1)
        let firstSuccess = schedule.entries["puzzle"]
        schedule.record(id: "puzzle", solved: true, assisted: false, now: now.addingTimeInterval(3600))
        assert(schedule.entries["puzzle"] == firstSuccess, "An early clean replay must preserve both retention level and due date")
        let tomorrow = now.addingTimeInterval(86400)
        schedule.record(id: "puzzle", solved: true, assisted: false, now: tomorrow)
        assert(schedule.entries["puzzle"]?.dueAt == tomorrow.addingTimeInterval(3 * 86400))
        schedule.record(id: "puzzle", solved: true, assisted: true, now: tomorrow)
        assert(schedule.entries["puzzle"]?.level == 0)
        assert(schedule.entries["puzzle"]?.dueAt == tomorrow.addingTimeInterval(86400))
        schedule.record(id: "puzzle", solved: false, assisted: false, now: tomorrow)
        assert(schedule.entries["puzzle"]?.level == 0)
        var progression = PuzzleReviewSchedule()
        var date = now
        for expectedDays in [1, 3, 7, 14, 30, 30] {
            progression.record(id: "long", solved: true, assisted: false, now: date)
            assert(progression.entries["long"]?.dueAt == date.addingTimeInterval(Double(expectedDays) * 86400))
            date = progression.entries["long"]!.dueAt
        }
        try PuzzleReviewStore.save(schedule, to: url)
        let restored = try PuzzleReviewStore.load(from: url)
        assert(restored.entries == schedule.entries)
        try Data("broken".utf8).write(to: url)
        do { _ = try PuzzleReviewStore.load(from: url); assertionFailure("Corrupt data must be reported") } catch {}
        do { try PuzzleReviewStore.save(schedule, to: url); assertionFailure("Corrupt data must never be overwritten") } catch {}
        let preserved = try Data(contentsOf: url)
        assert(preserved == Data("broken".utf8))

        let vmURL = folder.appendingPathComponent("model.json")
        let puzzle = PuzzleItem(id: "mate", fen: "6k1/p4ppp/8/8/8/8/8/4R1K1 b - - 0 1", moves: ["a7a6", "e1e8"], rating: 1000, themes: ["mateIn1"])
        var due = PuzzleReviewSchedule()
        due.record(id: "mate", solved: false, assisted: false, now: Date().addingTimeInterval(-2 * 86400))
        try PuzzleReviewStore.save(due, to: vmURL)
        let model = PuzzleViewModel(reviewURL: vmURL)
        model.selectReview(true)
        model.loadPuzzles(from: [puzzle])
        assert(model.currentPuzzle?.id == "mate")
        model.rating = 1000
        model.streak = 7
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        model.squareTapped(Square(string: "e1")!, context: context)
        model.squareTapped(Square(string: "e8")!, context: context)
        let results = try context.fetch(NSFetchRequest<PuzzleResult>(entityName: "PuzzleResult"))
        let progress = try context.fetch(NSFetchRequest<PuzzleProgress>(entityName: "PuzzleProgress"))
        assert(results.count == 1 && results[0].solved && results[0].ratingAfter == 1000 && progress.isEmpty)
        assert(model.state == .solved && model.rating == 1000 && model.streak == 7 && model.solvedCount == 0)
        let after = try PuzzleReviewStore.load(from: vmURL)
        let fresh = PuzzleViewModel(reviewURL: vmURL)
        fresh.loadPuzzles(from: [puzzle])
        fresh.squareTapped(Square(string: "e1")!, context: nil)
        fresh.squareTapped(Square(string: "e8")!, context: nil)
        let earlyReplay = try PuzzleReviewStore.load(from: vmURL)
        assert(earlyReplay.entries == after.entries, "A fresh free-training session must not advance a not-yet-due puzzle")
        model.showSolution()
        let duplicate = try PuzzleReviewStore.load(from: vmURL)
        assert(duplicate.entries == after.entries, "One completion is recorded only once")
        model.nextPuzzle()
        assert(model.currentPuzzle == nil && model.statusMessage.contains("fällig"), "Empty due queue cannot fall back to new rated tasks")
        var overdue = earlyReplay
        overdue.entries["mate"]!.dueAt = .distantPast
        try PuzzleReviewStore.save(overdue, to: vmURL)
        let dueReplay = PuzzleViewModel(reviewURL: vmURL)
        dueReplay.selectReview(true)
        dueReplay.loadPuzzles(from: [puzzle])
        dueReplay.squareTapped(Square(string: "e1")!, context: nil)
        dueReplay.squareTapped(Square(string: "e8")!, context: nil)
        let advanced = try PuzzleReviewStore.load(from: vmURL)
        assert(advanced.entries["mate"]?.level == 2, "A genuinely due replay advances retention after the early replay was ignored")
        assert(advanced.entries["mate"]!.dueAt.timeIntervalSinceNow > 3 * 86400 - 60)
        model.selectReview(false)
        assert(model.currentPuzzle != nil)
        model.showHint()
        let hinted = try PuzzleReviewStore.load(from: vmURL)
        assert(hinted.entries["mate"]?.level == 0, "Hints immediately reset retention")
        model.retryPuzzle()
        model.squareTapped(Square(string: "e1")!, context: context)
        model.squareTapped(Square(string: "e8")!, context: context)
        let retriedSchedule = try PuzzleReviewStore.load(from: vmURL)
        assert(retriedSchedule.entries["mate"]?.level == 0 && model.rating == 1000, "Immediate retry cannot extend retention or inflate rating")
        let blocked = folder.appendingPathComponent("not-a-folder")
        try Data().write(to: blocked)
        do { try PuzzleReviewStore.save(schedule, to: blocked.appendingPathComponent("reviews.json")); assertionFailure("Write failures must surface") } catch {}
        let corruptModel = PuzzleViewModel(reviewURL: url)
        corruptModel.loadPuzzles(from: [puzzle])
        corruptModel.showSolution()
        assert(corruptModel.reviewError != nil)
        let stillPreserved = try Data(contentsOf: url)
        assert(stillPreserved == Data("broken".utf8))
        print("Repetition checks passed: due dates, assistance, persistence/corruption, empty queue, once-only attempts and rating neutrality")
    }
}
