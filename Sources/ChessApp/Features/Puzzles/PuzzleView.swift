import SwiftUI
import Combine
import CoreData
import ChessAppKit

public struct PuzzleItem: Identifiable, Codable, Sendable {
    public let id: String
    public let fen: String
    public let moves: [String] // First move is opponent move, then user, then opponent, etc.
    public let rating: Int
    public let themes: [String]
    public var sourceGame: String? = nil
    public var explanation: String? = nil
    var isPersonal: Bool { sourceGame != nil }

    public init(id: String, fen: String, moves: [String], rating: Int, themes: [String]) {
        self.id = id
        self.fen = fen
        self.moves = moves
        self.rating = rating
        self.themes = themes
    }
}

enum PuzzleSource: String, CaseIterable {
    case all = "Alle Quellen", bundled = "Sammlung", personal = "Eigene Partien"
}

enum PuzzleDifficulty: String, CaseIterable {
    case all = "Alle Stärken"
    case beginner = "Einstieg · bis 700"
    case practice = "Übung · 701–1100"
    case challenge = "Knifflig · ab 1101"

    func contains(_ rating: Int) -> Bool {
        switch self {
        case .all: return true
        case .beginner: return rating <= 700
        case .practice: return (701...1100).contains(rating)
        case .challenge: return rating >= 1101
        }
    }
}

@MainActor
final class PuzzleViewModel: ObservableObject {
    enum PuzzleState {
        case waitingForUser
        case opponentThinking
        case solved
        case failed
    }

    private var attemptedIDs: Set<String> = []
    private var attemptRecorded = false
    private var assisted = false
    private var practice = false
    private var scheduleRecorded = false
    private let reviewURL: URL?
    @Published private(set) var reviewSchedule = PuzzleReviewSchedule()
    @Published private(set) var reviewingDue = false
    @Published private(set) var reviewError: String?
    @Published private(set) var hintLevel = 0
    @Published var failedIDs: Set<String> = []
    @Published var source: PuzzleSource = .all
    @Published var preparing = false
    @Published var preparationMessage = ""
    var preparationTask: Task<Void, Never>?
    var personalEngine: UCIEngine?
    var preparationID = UUID()
    private var opponentTask: Task<Void, Never>?
    @Published var puzzles: [PuzzleItem] = []
    @Published private(set) var selectedTheme = ""
    @Published private(set) var difficulty: PuzzleDifficulty = .all
    @Published var currentPuzzle: PuzzleItem? = nil
    @Published var position: Position
    @Published var orientation: PieceColor = .white
    @Published var state: PuzzleState = .waitingForUser
    @Published var moveIndex: Int = 0 // Index into currentPuzzle.moves
    @Published var legalTargets: Set<Square> = []
    @Published var selectedSquare: Square? = nil
    @Published var lastMove: Move? = nil
    @Published var hintSquare: Square? = nil
    @Published var rating: Int = 1500
    @Published var streak: Int = 0
    @Published var solvedCount: Int = 0
    @Published var statusMessage: String = ""

    var availableThemes: [String] { Array(Set(puzzles.flatMap(\.themes))).sorted() }

    static func themeTitle(_ theme: String) -> String {
        switch theme {
        case "pin": return "Fesselung"
        case "discoveredAttack": return "Abzugsangriff"
        case "combination": return "Kombination"
        case "advantage": return "Vorteil sichern"
        case "mateIn2": return "Matt in zwei Zügen"
        case "mateIn3": return "Matt in drei Zügen"
        case "ownMistake": return "Deine verpasste Chance"
        case "hangingPiece": return "Ungedeckte Figuren"
        case "promotion": return "Bauernumwandlung"
        case "fork": return "Springergabel"
        case "mateIn1": return "Matt in einem Zug"
        case "backRankMate": return "Grundreihenmatt"
        case "queenMate": return "Damenmatt"
        case "rookMate": return "Turmmatt"
        case "openingMate": return "Eröffnungsmatt"
        default: return theme
        }
    }

    static func themeAdvice(_ theme: String) -> String {
        switch theme {
        case "hangingPiece": return "Suche eine wertvolle gegnerische Figur, die du sicher schlagen kannst."
        case "promotion": return "Bringe deinen Bauern auf die letzte Reihe. In diesen Aufgaben wird er automatisch zur Dame."
        case "fork": return "Ein Springer kann zwei Figuren gleichzeitig angreifen. Suche zuerst nach einem Schachgebot."
        case "backRankMate": return "Die eigenen Bauern können dem König die Flucht versperren. Nutze die offene Grundreihe."
        default: return "Prüfe zuerst Schachgebote, dann Schlagzüge und Drohungen."
        }
    }

    var dueCount: Int {
        let ids = Set(puzzles.map(\.id))
        return reviewSchedule.entries.filter { ids.contains($0.key) && $0.value.dueAt <= Date() }.count
    }

    var eligiblePuzzles: [PuzzleItem] {
        puzzles.filter { (!reviewingDue || (reviewSchedule.entries[$0.id]?.dueAt ?? .distantFuture) <= Date()) && (source == .all || (source == .personal) == $0.isPersonal) && (selectedTheme.isEmpty || $0.themes.contains(selectedTheme)) && ($0.isPersonal || difficulty.contains($0.rating)) }
    }

    func selectDifficulty(_ value: PuzzleDifficulty) {
        guard value != difficulty else { return }
        difficulty = value
        attemptedIDs.removeAll()
        nextPuzzle()
    }

    // Views supply a store URL; model-only callers can work without touching a person's saved schedule.
    init(reviewURL: URL? = nil) {
        self.reviewURL = reviewURL
        let start = try! Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        self.position = start
        reloadReviewSchedule()
    }

    func reloadReviewSchedule() {
        guard let reviewURL else { return }
        do {
            reviewSchedule = try PuzzleReviewStore.load(from: reviewURL)
            reviewError = nil
        } catch {
            reviewError = "Wiederholungsplan konnte nicht gelesen werden. Die Datei bleibt erhalten: \(error.localizedDescription)"
        }
    }

    func selectReview(_ value: Bool) {
        reviewingDue = value
        attemptedIDs.removeAll()
        reloadReviewSchedule()
        nextPuzzle()
    }

    private func recordReview(solved: Bool) {
        guard !scheduleRecorded, let id = currentPuzzle?.id else { return }
        scheduleRecorded = true
        do {
            var schedule = try reviewURL.map { try PuzzleReviewStore.load(from: $0) } ?? reviewSchedule
            schedule.record(id: id, solved: solved, assisted: assisted || practice)
            if let reviewURL { try PuzzleReviewStore.save(schedule, to: reviewURL) }
            reviewSchedule = schedule
            reviewError = nil
        } catch {
            reviewError = "Wiederholung konnte nicht gespeichert werden. Vorhandene Daten bleiben erhalten: \(error.localizedDescription)"
        }
    }

    func loadPuzzles(from items: [PuzzleItem]) {
        self.puzzles = items
        attemptedIDs.removeAll()
        if !availableThemes.contains(selectedTheme) { selectedTheme = "" }
        nextPuzzle()
    }

    func selectTheme(_ theme: String) {
        guard theme != selectedTheme else { return }
        selectedTheme = theme
        attemptedIDs.removeAll()
        nextPuzzle()
    }

    func nextPuzzle() {

        let eligible = eligiblePuzzles
        guard !eligible.isEmpty else {
            opponentTask?.cancel()
            currentPuzzle = nil
            selectedSquare = nil
            legalTargets = []
            lastMove = nil
            hintSquare = nil
            state = .failed
            statusMessage = reviewingDue ? "Keine Wiederholungen für diese Auswahl fällig. Du kannst im freien Training weiterüben." : "Keine Puzzles für diese Auswahl verfügbar. Wähle eine andere Stärke oder ein anderes Thema."
            return
        }
        if !reviewingDue && eligible.allSatisfy({ attemptedIDs.contains($0.id) }) { attemptedIDs.removeAll() }
        let remaining = eligible.filter { !attemptedIDs.contains($0.id) }
        guard let candidate = remaining.min(by: {
            if reviewingDue {
                return (reviewSchedule.entries[$0.id]?.dueAt ?? .distantFuture) < (reviewSchedule.entries[$1.id]?.dueAt ?? .distantFuture)
            }
            return abs($0.rating - rating) < abs($1.rating - rating)
        }) else {
            currentPuzzle = nil
            opponentTask?.cancel()
            selectedSquare = nil; legalTargets = []; lastMove = nil; hintSquare = nil
            state = .failed
            statusMessage = "Alle fälligen Aufgaben dieser Runde gesehen. Offene Aufgaben kommen zur nächsten Wiederholung wieder."
            return
        }
        attemptedIDs.insert(candidate.id)
        startPuzzle(candidate)
    }

    func startPuzzle(_ puzzle: PuzzleItem) {
        opponentTask?.cancel()
        attemptRecorded = false
        scheduleRecorded = false
        assisted = false
        practice = false
        hintLevel = 0
        self.currentPuzzle = puzzle
        do {
            var validated = try Position(fen: puzzle.fen)
            guard puzzle.moves.count >= 2, puzzle.moves.count.isMultiple(of: 2) else {
                state = .failed
                statusMessage = "Ungültige Puzzle-Lösungsfolge."
                return
            }
            for uci in puzzle.moves {
                guard let move = parseUCI(uci, in: validated) else {
                    state = .failed
                    statusMessage = "Ungültiger Zug in der Puzzle-Lösung."
                    return
                }
                validated = validated.make(move)
            }
            let startPos = try Position(fen: puzzle.fen)
            self.position = startPos
            self.moveIndex = 0
            self.state = .waitingForUser
            self.selectedSquare = nil
            self.legalTargets = []
            self.lastMove = nil
            self.hintSquare = nil
            self.statusMessage = reviewingDue ? "Fällige Wiederholung · ohne Rating" : "Finde den besten Zug!"

            // The side to move AFTER opponent's move is the player's side
            if let firstMoveUCI = puzzle.moves.first, let opponentMove = parseUCI(firstMoveUCI, in: startPos) {
                let afterOpponent = startPos.make(opponentMove)
                self.orientation = afterOpponent.turn
                self.position = afterOpponent
                self.lastMove = opponentMove
                self.moveIndex = 1
            } else {
                self.orientation = startPos.turn
            }
        } catch {
            self.state = .failed
            self.statusMessage = "Fehler beim Laden der Stellung."
        }
    }

    func squareTapped(_ square: Square, context: NSManagedObjectContext?) {
        guard state == .waitingForUser else { return }

        if let selected = selectedSquare {
            if let move = position.move(from: selected, to: square) {
                applyUserMove(move, context: context)
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

    private func applyUserMove(_ move: Move, context: NSManagedObjectContext?) {
        guard let puzzle = currentPuzzle, moveIndex < puzzle.moves.count else { return }
        let expectedUCI = puzzle.moves[moveIndex]

        // Check if user move matches expected or delivers checkmate
        let newPos = position.make(move)
        let isCorrect = (move.uci == expectedUCI) || newPos.isCheckmate

        if isCorrect {
            position = newPos
            lastMove = move
            moveIndex += 1

            if moveIndex >= puzzle.moves.count || newPos.isCheckmate {
                // Puzzle solved!
                state = .solved
                statusMessage = "Richtig gelöst"
                if !assisted && !practice && !reviewingDue && !puzzle.isPersonal {
                    streak += 1
                    solvedCount += 1
                }
                failedIDs.remove(puzzle.id)
                updateRating(solved: true, context: context)
            } else {
                // Opponent counter move
                state = .opponentThinking
                statusMessage = "Gegner antwortet..."
                let oppUCI = puzzle.moves[moveIndex]
                opponentTask = Task {
                    do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
                    guard !Task.isCancelled, currentPuzzle?.id == puzzle.id, state == .opponentThinking else { return }
                    if let oppMove = parseUCI(oppUCI, in: position) {
                        position = position.make(oppMove)
                        lastMove = oppMove
                        moveIndex += 1
                        state = .waitingForUser
                        statusMessage = "Dein Zug!"
                    }
                }
            }
        } else {
            state = .failed
            statusMessage = "Nicht der Lösungszug. Sieh dir die Lösung an!"
            if !practice && !assisted && !reviewingDue && !puzzle.isPersonal { streak = 0 }
            updateRating(solved: false, context: context)
        }
    }

    func selectSource(_ value: PuzzleSource) {
        source = value
        attemptedIDs.removeAll()
        nextPuzzle()
    }

    func retryPuzzle() {
        guard let puzzle = currentPuzzle else { return }
        startPuzzle(puzzle)
        practice = true
        statusMessage = "Wiederholung · ohne Rating"
    }

    func repeatFailed() {
        guard let puzzle = eligiblePuzzles.first(where: { failedIDs.contains($0.id) }) else { return }
        startPuzzle(puzzle)
        practice = true
        statusMessage = "Fehler wiederholen · ohne Rating"
    }

    func showHint() {
        guard state == .waitingForUser, let puzzle = currentPuzzle,
              moveIndex < puzzle.moves.count,
              let move = parseUCI(puzzle.moves[moveIndex], in: position) else { return }
        assisted = true
        recordReview(solved: false)
        hintLevel = min(3, hintLevel + 1)
        switch hintLevel {
        case 1: statusMessage = "Idee: " + Self.themeAdvice(puzzle.themes.first ?? "")
        case 2:
            hintSquare = move.from
            statusMessage = "Figur: Prüfe die Figur auf \(move.from.name)."
        default:
            hintSquare = move.to
            statusMessage = "Zielfeld: \(move.to.name). Prüfe den Zug \(SAN.notation(for: move, in: position))."
        }
    }

    var solutionExplanation: String {
        guard let puzzle = currentPuzzle, var pos = try? Position(fen: puzzle.fen) else { return "" }
        var line: [String] = []
        for (index, uci) in puzzle.moves.enumerated() {
            guard let move = parseUCI(uci, in: pos) else { return "Lösung nicht verfügbar." }
            if index > 0 { line.append(SAN.notation(for: move, in: pos)) }
            pos = pos.make(move)
        }
        let outcome = pos.isCheckmate ? "Der König steht im Schach und hat keine legale Antwort: Matt." : "Die Lösungsfolge zeigt die geprüfte Fortsetzung."
        return (puzzle.explanation ?? Self.themeAdvice(puzzle.themes.first ?? "")) + "\n" + line.joined(separator: " → ") + "\n" + outcome + "\nSAN: x = schlägt, + = Schach, # = Matt; N = Springer, B = Läufer, R = Turm, Q = Dame."
    }

    func showSolution(context: NSManagedObjectContext? = nil) {
        guard state != .solved, state != .opponentThinking,
              let puzzle = currentPuzzle, moveIndex < puzzle.moves.count else { return }
        if !practice && !assisted && !reviewingDue && !puzzle.isPersonal { streak = 0 }
        for uci in puzzle.moves[moveIndex...] {
            guard let move = parseUCI(uci, in: position) else { break }
            position = position.make(move)
            lastMove = move
        }
        moveIndex = puzzle.moves.count
        state = .failed
        statusMessage = "Lösung ansehen · danach selbst wiederholen"
        updateRating(solved: false, context: context)
    }

    private func updateRating(solved: Bool, context: NSManagedObjectContext?) {
        guard !attemptRecorded else { return }
        attemptRecorded = true
        recordReview(solved: solved)
        if !solved, let id = currentPuzzle?.id { failedIDs.insert(id) }
        if practice || reviewingDue || assisted || currentPuzzle?.isPersonal == true {
            if let context {
                let result = PuzzleResult(context: context)
                result.puzzleID = currentPuzzle?.id ?? ""
                result.solved = solved
                result.ratingAfter = Int64(rating)
                do { try context.save() }
                catch { statusMessage += " Fortschritt konnte nicht gespeichert werden: \(error.localizedDescription)" }
            }
            return
        }
        let expectedScore = 1.0 / (1.0 + pow(10.0, Double((currentPuzzle?.rating ?? 1500) - rating) / 400.0))
        let actualScore = solved ? 1.0 : 0.0
        let kFactor: Double = 32.0
        let delta = Int(round(kFactor * (actualScore - expectedScore)))
        rating = max(100, rating + delta)

        if let ctx = context {
            let progress = PuzzleProgress.fetchOrCreate(context: ctx)
            progress.rating = Int64(rating)
            if solved {
                progress.solvedCount += 1
                progress.currentStreak += 1
                if progress.currentStreak > progress.bestStreak {
                    progress.bestStreak = progress.currentStreak
                }
                progress.lastSolvedAt = Date()
            } else {
                progress.failedCount += 1
                progress.currentStreak = 0
            }

            let result = PuzzleResult(context: ctx)
            result.id = UUID()
            result.puzzleID = currentPuzzle?.id ?? ""
            result.createdAt = Date()
            result.solved = solved
            result.ratingAfter = Int64(rating)

            do { try ctx.save() }
            catch { statusMessage += " Fortschritt konnte nicht gespeichert werden: \(error.localizedDescription)" }
        }
    }

    private func parseUCI(_ uci: String, in pos: Position) -> Move? {
        pos.legalMoves().first { $0.uci == uci }
    }
}

struct PuzzleView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var viewModel = PuzzleViewModel(reviewURL: PuzzleReviewStore.url)
    private let initialSource: PuzzleSource
    private let initialReview: Bool
    private let initialTheme: String

    init(initialSource: PuzzleSource = .all, initialReview: Bool = false, initialTheme: String = "") {
        self.initialSource = initialSource
        self.initialReview = initialReview
        self.initialTheme = initialTheme
    }
    @LocalState private var isLoaded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dein Taktiktraining").font(.largeTitle.bold())
                    Text("Kleine Aufgaben. Große Aha-Momente.").foregroundStyle(.secondary)
                }
                Spacer()
                Label("\(viewModel.solvedCount) gelöst", systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(.green)
            }.padding([.horizontal, .top], 24)
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(SwiftUI.Color.purple)
                    Text("Rating: \(viewModel.rating)")
                        .font(.headline)
                }

                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(SwiftUI.Color.orange)
                    Text("Serie: \(viewModel.streak)")
                        .font(.headline)
                }

                Spacer()

                if let puzzle = viewModel.currentPuzzle {
                    HStack(spacing: 6) {
                        ForEach(puzzle.themes, id: \.self) { theme in
                            Text(PuzzleViewModel.themeTitle(theme))
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(SwiftUI.Color.secondary.opacity(0.15)))
                        }
                        Text(puzzle.isPersonal ? "Eigene Partie · ohne Rating" : "Puzzle: \(puzzle.rating) Elo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()

            Divider()
            HStack {
                Picker("Training", selection: Binding(get: { viewModel.reviewingDue }, set: { viewModel.selectReview($0) })) {
                    Text("Freies Training").tag(false)
                    Text("Heute wiederholen · \(viewModel.dueCount) fällig").tag(true)
                }.pickerStyle(.segmented).frame(maxWidth: 490)
                Spacer()
                if viewModel.reviewingDue { Text("Ohne Rating").font(.caption).foregroundStyle(.secondary) }
            }.padding(.horizontal, 24).padding(.top, 12)
            if let error = viewModel.reviewError {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                    .padding(.horizontal, 24).padding(.top, 6)
            }

            HStack(spacing: 18) {
            Picker("Quelle", selection: Binding(get: { viewModel.source }, set: { viewModel.selectSource($0) })) {
                ForEach(PuzzleSource.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.frame(maxWidth: 200)
            Picker("Stärke", selection: Binding(get: { viewModel.difficulty }, set: { viewModel.selectDifficulty($0) })) {
                ForEach(PuzzleDifficulty.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.frame(maxWidth: 280)
            Picker("Thema", selection: Binding(
                get: { viewModel.selectedTheme },
                set: { viewModel.selectTheme($0) }
            )) {
                Text("Alle Themen").tag("")
                ForEach(viewModel.availableThemes, id: \.self) { theme in
                    Text(PuzzleViewModel.themeTitle(theme)).tag(theme)
                }
            }
            .frame(maxWidth: 360)
            Text("\(viewModel.eligiblePuzzles.count) Aufgaben").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            HStack {
                if viewModel.preparing {
                    ProgressView().controlSize(.small)
                    Button("Abbrechen") { viewModel.cancelPreparation() }
                } else {
                    Button("Eigene Aufgaben vorbereiten") { viewModel.preparePersonal(context: context) }
                }
                Text(viewModel.preparationMessage).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Fehler wiederholen") { viewModel.repeatFailed() }
                    .disabled(viewModel.failedIDs.isEmpty)
            }.padding(.horizontal, 24).padding(.top, 8)
            // Main Content: Board & Controls
            GeometryReader { geometry in
            let boardSize = max(180, min(720, geometry.size.height - 32, geometry.size.width - 374))
            HStack(spacing: 14) {
                VStack {
                    if viewModel.currentPuzzle != nil {
                    BoardView(
                        position: viewModel.position,
                        orientation: viewModel.orientation,
                        legalTargets: viewModel.legalTargets,
                        lastMove: viewModel.lastMove,
                        arrows: viewModel.hintSquare != nil ? [MoveArrow(from: viewModel.hintSquare!, to: viewModel.hintSquare!, color: SwiftUI.Color.yellow)] : [],
                        selected: viewModel.selectedSquare,
                        onSquareTap: { viewModel.squareTapped($0, context: context) }
                    )
                    .frame(width: boardSize, height: boardSize)
                    .padding()
                    } else {
                        ContentUnavailableView(viewModel.reviewingDue ? "Heute nichts fällig" : "Keine Puzzles", systemImage: "puzzlepiece",
                                               description: Text(viewModel.reviewingDue ? viewModel.statusMessage : "Wähle eine andere Stärke oder ein anderes Thema."))
                            .frame(width: boardSize, height: boardSize)
                            .padding()
                    }
                }

                ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status banner
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.statusMessage)
                            .font(.title3).bold()
                            .foregroundStyle(
                                viewModel.state == .solved ? SwiftUI.Color.green :
                                viewModel.state == .failed && viewModel.currentPuzzle != nil ? SwiftUI.Color.red : SwiftUI.Color.primary
                            )

                        if viewModel.currentPuzzle != nil {
                            Text(viewModel.orientation == .white ? "Weiß zieht" : "Schwarz zieht")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(SwiftUI.Color.secondary.opacity(0.08)))

                    if let puzzle = viewModel.currentPuzzle {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Dein Trainingsziel", systemImage: "scope").font(.headline)
                            Text(PuzzleViewModel.themeAdvice(puzzle.themes.first ?? ""))
                                .font(.callout).foregroundStyle(.secondary)
                            let total = max(1, puzzle.moves.count / 2)
                            let completed = min(total, viewModel.moveIndex / 2)
                            ProgressView(value: Double(completed), total: Double(total))
                                .tint(viewModel.state == .solved ? .green : .accentColor)
                            Text("\(completed) von \(total) Lösungszügen").font(.caption).foregroundStyle(.secondary)
                        }.padding().panel()
                    }
                    if viewModel.state == .solved || (viewModel.state == .failed && viewModel.moveIndex >= (viewModel.currentPuzzle?.moves.count ?? 0)) {
                        ScrollView { Text(viewModel.solutionExplanation).font(.callout).textSelection(.enabled) }.frame(maxHeight: 180)
                    }
                    VStack(spacing: 12) {
                        if viewModel.state == .solved || viewModel.state == .failed {
                            if viewModel.state == .failed {
                                Button("Lösung zeigen") { viewModel.showSolution(context: context) }
                                    .disabled(viewModel.moveIndex >= (viewModel.currentPuzzle?.moves.count ?? 0))
                            }
                            Button("Noch einmal üben · ohne Rating") { viewModel.retryPuzzle() }
                            Button(action: { viewModel.nextPuzzle() }) {
                                Label("Nächstes Puzzle", systemImage: "arrow.forward.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(viewModel.currentPuzzle == nil)
                        } else {
                            Button(action: { viewModel.showHint() }) {
                                Label("Hinweis", systemImage: "lightbulb.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button(action: { viewModel.showSolution(context: context) }) {
                                Label("Lösung zeigen", systemImage: "eye.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Spacer()
                }
                .padding()
                }
                .frame(width: 312)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Taktik-Puzzles")
        .onAppear { loadInitialData() }
        .onDisappear { viewModel.cancelPreparation() }
    }

    private func loadInitialData() {
        guard !isLoaded else { return }
        let progress = PuzzleProgress.fetchOrCreate(context: context)
        viewModel.rating = Int(progress.rating)
        viewModel.streak = Int(progress.currentStreak)
        viewModel.solvedCount = Int(progress.solvedCount)
        let results = (try? context.fetch(NSFetchRequest<PuzzleResult>(entityName: "PuzzleResult"))) ?? []
        for result in results.sorted(by: { $0.createdAt < $1.createdAt }) {
            if result.solved { viewModel.failedIDs.remove(result.puzzleID) }
            else { viewModel.failedIDs.insert(result.puzzleID) }
        }
        viewModel.source = initialSource
        viewModel.selectReview(initialReview)

        do {
            guard let url = ChessAppKitInfo.resourceBundle.url(forResource: "puzzles", withExtension: "json") else {
                viewModel.statusMessage = "Puzzle-Datei fehlt."
                return
            }
            let items = try JSONDecoder().decode([PuzzleItem].self, from: Data(contentsOf: url))
            viewModel.loadPuzzles(from: items + PersonalPuzzleStore.load())
            if viewModel.availableThemes.contains(initialTheme) { viewModel.selectTheme(initialTheme) }
        } catch {
            viewModel.statusMessage = "Puzzles konnten nicht geladen werden: \(error.localizedDescription)"
        }
        isLoaded = true
    }
}
