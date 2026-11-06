import Foundation
import Testing
import ChessAppKit

@Suite
struct LessonDataTests {
    private struct Course: Decodable {
        let id: String
        let title: String
        let chapters: [Chapter]
    }
    private struct Chapter: Decodable {
        let title: String
        let lessons: [Lesson]
    }
    private struct Lesson: Decodable {
        let id: String
        let title: String
        let text: String
        let fen: String?
        let exercise: Exercise?
    }
    private struct Exercise: Decodable {
        let task: String
        let solutionMove: String
    }

    @Test func threeCoursesContainLegalExercises() throws {
        var courseIDs: Set<String> = []
        for name in ["basics", "tactics", "endgame"] {
            let url = try #require(ChessAppKitInfo.resourceBundle.url(forResource: name, withExtension: "json"))
            let course = try JSONDecoder().decode(Course.self, from: Data(contentsOf: url))
            #expect(courseIDs.insert(course.id).inserted)
            #expect(!course.title.isEmpty)
            let lessons = course.chapters.flatMap(\.lessons)
            #expect((2...3).contains(lessons.count))
            #expect(Set(lessons.map(\.id)).count == lessons.count)
            for chapter in course.chapters { #expect(!chapter.title.isEmpty) }
            for lesson in lessons {
                #expect(!lesson.title.isEmpty && !lesson.text.isEmpty)
                if let exercise = lesson.exercise {
                    #expect(!exercise.task.isEmpty)
                    let fen = try #require(lesson.fen)
                    let position = try Position(fen: fen)
                    let move = try #require(position.legalMoves().first { $0.uci == exercise.solutionMove })
                    if exercise.task.lowercased().contains("matt") {
                        #expect(position.make(move).isCheckmate)
                    }
                } else if let fen = lesson.fen {
                    _ = try Position(fen: fen)
                }
            }
        }
        #expect(courseIDs.count == 3)
    }
}
