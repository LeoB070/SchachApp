import Foundation
import ChessAppKit

private struct PuzzleFixture: Decodable {
    let id: String
    let fen: String
    let moves: [String]
    let rating: Int
    let themes: [String]
}

private struct CourseFixture: Decodable {
    struct Chapter: Decodable {
        struct Lesson: Decodable {
            struct Exercise: Decodable { let task: String; let solutionMove: String }
            let id: String
            let title: String
            let text: String
            let fen: String?
            let exercise: Exercise?
        }
        let title: String
        let lessons: [Lesson]
    }
    let id: String
    let title: String
    let chapters: [Chapter]
}

func learningDataChecks() throws {
    func load<T: Decodable>(_ type: T.Type, name: String) throws -> T {
        guard let url = ChessAppKitInfo.resourceBundle.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
    let puzzles = try load([PuzzleFixture].self, name: "puzzles")
    check(puzzles.count >= 40, "At least 40 bundled puzzles")
    check(puzzles.contains { $0.rating <= 400 }, "Beginner puzzles available")
    check(Set(puzzles.flatMap(\.themes)).isSuperset(of: ["hangingPiece", "promotion", "fork"]), "New training themes")
    checkEqual(Set(puzzles.map(\.id)).count, puzzles.count, "Unique puzzle IDs")
    checkEqual(Set(puzzles.map(\.fen)).count, puzzles.count, "Distinct puzzle positions")
    var playerColors: Set<String> = []
    for puzzle in puzzles {
        check(puzzle.rating > 0 && !puzzle.themes.isEmpty, "\(puzzle.id) metadata")
        check(puzzle.moves.count >= 2 && puzzle.moves.count.isMultiple(of: 2), "\(puzzle.id) opponent starts, player finishes")
        var position = try Position(fen: puzzle.fen)
        for (index, uci) in puzzle.moves.enumerated() {
            guard let move = position.legalMoves().first(where: { $0.uci == uci }) else {
                check(false, "\(puzzle.id) illegal move \(uci)")
                break
            }
            if puzzle.themes.contains("hangingPiece") && index == 1 {
                check(move.flags.contains(.capture), "\(puzzle.id) wins a piece")
            }
            if puzzle.themes.contains("promotion") && index == 1 {
                check(move.promotion == .queen, "\(puzzle.id) promotes to queen")
            }
            position = position.make(move)
            if puzzle.themes.contains("fork") && index == 1 {
                check(position.isInCheck(position.turn), "\(puzzle.id) fork starts with check")
            }
            if index == 0 { playerColors.insert(position.turn == .white ? "white" : "black") }
        }
        if puzzle.themes.contains(where: { $0.lowercased().contains("mate") }) {
            check(position.isCheckmate, "\(puzzle.id) ends in checkmate")
        }
    }
    checkEqual(playerColors, Set(["white", "black"]), "Puzzles exercise both colors")
    var courseIDs: Set<String> = []
    for name in ["basics", "tactics", "endgame"] {
        let course = try load(CourseFixture.self, name: name)
        check(courseIDs.insert(course.id).inserted && !course.title.isEmpty, "\(name) course identity")
        let lessons = course.chapters.flatMap(\.lessons)
        check((2...3).contains(lessons.count), "\(name) has 2–3 lessons")
        checkEqual(Set(lessons.map(\.id)).count, lessons.count, "\(name) unique lesson IDs")
        for chapter in course.chapters { check(!chapter.title.isEmpty, "\(name) chapter title") }
        for lesson in lessons {
            check(!lesson.title.isEmpty && !lesson.text.isEmpty, "\(name)/\(lesson.id) lesson content")
            if let exercise = lesson.exercise {
                guard let fen = lesson.fen else {
                    check(false, "\(lesson.id) exercise needs a position")
                    continue
                }
                let position = try Position(fen: fen)
                let move = position.legalMoves().first { $0.uci == exercise.solutionMove }
                check(move != nil && !exercise.task.isEmpty, "\(lesson.id) legal exercise solution")
                if exercise.task.lowercased().contains("matt"), let move {
                    check(position.make(move).isCheckmate, "\(lesson.id) advertised mate")
                }
            } else if let fen = lesson.fen { _ = try Position(fen: fen) }
        }
    }
    checkEqual(courseIDs.count, 3, "3 bundled courses")
}
