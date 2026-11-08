import Foundation

struct PuzzleReviewSchedule: Codable {
    struct Entry: Codable, Equatable {
        var level: Int
        var dueAt: Date
    }
    var entries: [String: Entry] = [:]

    func dueCount(now: Date = Date()) -> Int { entries.values.filter { $0.dueAt <= now }.count }

    mutating func record(id: String, solved: Bool, assisted: Bool, now: Date = Date()) {
        guard !id.isEmpty else { return }
        if solved && !assisted, let previous = entries[id], previous.dueAt > now { return }
        let intervals = [1, 3, 7, 14, 30]
        let previous = entries[id]?.level ?? 0
        let level = solved && !assisted ? min(previous + 1, intervals.count) : 0
        let days = intervals[max(0, level - 1)]
        entries[id] = Entry(level: level, dueAt: now.addingTimeInterval(Double(days) * 86400))
    }
}

enum PuzzleReviewStore {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChessApp/puzzle-reviews.json")
    }

    static func load(from url: URL = url) throws -> PuzzleReviewSchedule {
        guard FileManager.default.fileExists(atPath: url.path) else { return PuzzleReviewSchedule() }
        let schedule = try JSONDecoder().decode(PuzzleReviewSchedule.self, from: Data(contentsOf: url))
        guard schedule.entries.allSatisfy({ !$0.key.isEmpty && (0...5).contains($0.value.level) && $0.value.dueAt.timeIntervalSince1970.isFinite }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return schedule
    }

    static func save(_ schedule: PuzzleReviewSchedule, to url: URL = url) throws {
        // Preserve an unreadable existing schedule instead of replacing it with an empty one.
        _ = try load(from: url)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(schedule).write(to: url, options: .atomic)
    }
}
