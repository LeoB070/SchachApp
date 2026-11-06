import SwiftUI
import CoreData
import ChessAppKit

public struct ExerciseData: Codable, Hashable, Sendable {
    public let task: String
    public let solutionMove: String // UCI notation e.g. "e2e4"

    public init(task: String, solutionMove: String) {
        self.task = task
        self.solutionMove = solutionMove
    }
}

public struct LessonItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let content: String
    public let fen: String?
    public let exercise: ExerciseData?

    enum CodingKeys: String, CodingKey {
        case id, title, fen, exercise
        case content = "text"
    }

    public init(id: String, title: String, content: String, fen: String? = nil, exercise: ExerciseData? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.fen = fen
        self.exercise = exercise
    }
}

public struct CourseItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let icon: String
    public let lessons: [LessonItem]

    private struct Chapter: Decodable { let lessons: [LessonItem] }
    private enum CodingKeys: String, CodingKey { case id, title, description, icon, chapters, lessons }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        description = try values.decode(String.self, forKey: .description)
        icon = try values.decode(String.self, forKey: .icon)
        if values.contains(.chapters) {
            lessons = try values.decode([Chapter].self, forKey: .chapters).flatMap(\.lessons)
        } else {
            lessons = try values.decode([LessonItem].self, forKey: .lessons)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(title, forKey: .title)
        try values.encode(description, forKey: .description)
        try values.encode(icon, forKey: .icon)
        try values.encode(lessons, forKey: .lessons)
    }

    public init(id: String, title: String, description: String, icon: String, lessons: [LessonItem]) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.lessons = lessons
    }
}

struct LessonView: View {
    @Environment(\.managedObjectContext) private var context
    let courseID: String
    let lesson: LessonItem

    @LocalState private var position: Position = try! Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    @LocalState private var selectedSquare: Square? = nil
    @LocalState private var legalTargets: Set<Square> = []
    @LocalState private var lastMove: Move? = nil
    @LocalState private var exerciseSolved: Bool = false
    @LocalState private var exerciseFailed: Bool = false
    @LocalState private var isCompleted: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lesson.title)
                            .font(.largeTitle).bold()
                        if isCompleted {
                            Label("Abgeschlossen", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(SwiftUI.Color.green)
                                .font(.subheadline)
                        }
                    }
                    Spacer()
                }

                // Lesson Text
                Text(lesson.content)
                    .font(.body)
                    .lineSpacing(6)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(SwiftUI.Color.secondary.opacity(0.08)))

                // Interactive Exercise (if present)
                if let ex = lesson.exercise, lesson.fen != nil {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Übungsaufgabe")
                            .font(.title2).bold()
                        Text(ex.task)
                            .font(.headline)
                            .foregroundStyle(SwiftUI.Color.accentColor)

                        HStack(spacing: 24) {
                            BoardView(
                                position: position,
                                orientation: (try? Position(fen: lesson.fen ?? ""))?.turn ?? .white,
                                legalTargets: legalTargets,
                                lastMove: lastMove,
                                arrows: [],
                                selected: selectedSquare,
                                onSquareTap: { handleSquareTap($0, solution: ex.solutionMove) }
                            )
                            .frame(width: 360, height: 360)

                            VStack(alignment: .leading, spacing: 14) {
                                if exerciseSolved {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("Hervorragend gelöst!", systemImage: "checkmark.seal.fill")
                                            .font(.title3).bold()
                                            .foregroundStyle(SwiftUI.Color.green)
                                        Text("Du hast die Aufgabe korrekt abgeschlossen.")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 8).fill(SwiftUI.Color.green.opacity(0.12)))
                                } else if exerciseFailed {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("Nicht ganz richtig", systemImage: "xmark.circle.fill")
                                            .font(.headline)
                                            .foregroundStyle(SwiftUI.Color.red)
                                        Text("Versuche einen anderen Zug!")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 8).fill(SwiftUI.Color.red.opacity(0.12)))
                                } else {
                                    Text("Führe den Lösungszug auf dem Brett aus.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Button("Stellung zurücksetzen") {
                                    resetExercise()
                                }
                                .buttonStyle(.bordered)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(SwiftUI.Color.secondary.opacity(0.05)))
                }

                // Completion Toggle
                Button(action: { toggleCompleted() }) {
                    Label(
                        isCompleted ? "Als unvollständig markieren" : "Lektion als abgeschlossen markieren",
                        systemImage: isCompleted ? "checkmark.circle" : "circle"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 10)
            }
            .padding(24)
        }
        .onAppear { loadLesson() }
    }

    private func loadLesson() {
        if let fen = lesson.fen, let p = try? Position(fen: fen) {
            position = p
        }
        let key = "\(courseID)|\(lesson.id)"
        if let record = LessonProgress.find(key: key, context: context) {
            isCompleted = record.completed
        }
    }

    private func handleSquareTap(_ square: Square, solution: String) {
        guard !exerciseSolved, !exerciseFailed else { return }
        if let selected = selectedSquare {
            if let move = position.move(from: selected, to: square, promotion: position.board[selected.index]?.type == .pawn && (square.rank == 0 || square.rank == 7) ? .queen : nil) {
                applyMove(move, solution: solution)
                selectedSquare = nil
                legalTargets = []
                return
            }
        }

        if let piece = position.board[square.index], piece.color == position.turn {
            selectedSquare = square
            legalTargets = Set(position.legalMoves().filter { $0.from == square }.map { $0.to })
        } else {
            selectedSquare = nil
            legalTargets = []
        }
    }

    private func applyMove(_ move: Move, solution: String) {
        if move.uci == solution {
            position = position.make(move)
            lastMove = move
            exerciseSolved = true
            exerciseFailed = false
            if !isCompleted {
                markCompleted(true)
            }
        } else {
            exerciseFailed = true
        }
    }

    private func resetExercise() {
        if let fen = lesson.fen, let p = try? Position(fen: fen) {
            position = p
            lastMove = nil
            selectedSquare = nil
            legalTargets = []
            exerciseSolved = false
            exerciseFailed = false
        }
    }

    private func toggleCompleted() {
        markCompleted(!isCompleted)
    }

    private func markCompleted(_ completed: Bool) {
        isCompleted = completed
        let key = "\(courseID)|\(lesson.id)"
        LessonProgress.setCompleted(key: key, completed: completed, context: context)
    }
}

struct LessonListView: View {
    @Environment(\.managedObjectContext) private var context
    @LocalState private var selectedCourse: CourseItem? = nil
    @LocalState private var selectedLesson: LessonItem? = nil

    @FetchRequest(sortDescriptors: []) private var progress: FetchedResults<LessonProgress>
    @LocalState private var courses: [CourseItem] = []
    @LocalState private var loadError: String? = nil

    var body: some View {
        NavigationSplitView {
            List(courses, id: \.id, selection: $selectedCourse) { course in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: course.icon)
                            .foregroundStyle(SwiftUI.Color.accentColor)
                        Text(course.title)
                            .font(.headline)
                    }
                    Text(course.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .tag(course)
            }
            .navigationTitle("Lektionen")
            .frame(minWidth: 260)
        } content: {
            if let course = selectedCourse {
                List(course.lessons, id: \.id, selection: $selectedLesson) { lesson in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lesson.title)
                                .font(.body).bold()
                            if lesson.exercise != nil {
                                Text("Mit interaktiver Übung")
                                    .font(.caption2)
                                    .foregroundStyle(SwiftUI.Color.accentColor)
                            }
                        }
                        Spacer()
                        if isLessonDone(courseID: course.id, lessonID: lesson.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(SwiftUI.Color.green)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(lesson)
                }
                .navigationTitle(course.title)
                .frame(minWidth: 260)
            } else {
                Text("Wähle einen Kurs aus")
                    .foregroundStyle(.secondary)
            }
        } detail: {
            if let course = selectedCourse, let lesson = selectedLesson {
                LessonView(courseID: course.id, lesson: lesson)
                    .id("\(course.id)|\(lesson.id)")
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(loadError ?? "Wähle eine Lektion zum Lernen aus")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: selectedCourse) { _, course in selectedLesson = course?.lessons.first }
        .onAppear {
            if courses.isEmpty {
                do {
                    courses = try ["basics", "tactics", "endgame"].map { name in
                        guard let url = ChessAppKitInfo.resourceBundle.url(forResource: name, withExtension: "json") else {
                            throw CocoaError(.fileNoSuchFile)
                        }
                        return try JSONDecoder().decode(CourseItem.self, from: Data(contentsOf: url))
                    }
                } catch { loadError = "Lektionen konnten nicht geladen werden: \(error.localizedDescription)" }
            }
            if selectedCourse == nil {
                selectedCourse = courses.first
                selectedLesson = courses.first?.lessons.first
            }
        }
    }

    private func isLessonDone(courseID: String, lessonID: String) -> Bool {
        let key = "\(courseID)|\(lessonID)"
        return progress.first { $0.key == key }?.completed ?? false
    }
}
