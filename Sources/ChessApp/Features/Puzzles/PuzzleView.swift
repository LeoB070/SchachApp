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

    public init(id: String, fen: String, moves: [String], rating: Int, themes: [String]) {
        self.id = id
        self.fen = fen
        self.moves = moves
        self.rating = rating
        self.themes = themes
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
    private var opponentTask: Task<Void, Never>?
    @Published var puzzles: [PuzzleItem] = []
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

    init() {
        let start = try! Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        self.position = start
    }

    func loadPuzzles(from items: [PuzzleItem]) {
        self.puzzles = items
        nextPuzzle()
    }

    func nextPuzzle() {
        guard !puzzles.isEmpty else { return }
        // TODO(CLAUDE): Puzzle-Auswahl nach Thema, Puzzles aus eigenen Fehlern erzeugen.
        if attemptedIDs.count >= puzzles.count { attemptedIDs.removeAll() }
        let remaining = puzzles.filter { !attemptedIDs.contains($0.id) }
        guard let candidate = remaining.min(by: { abs($0.rating - rating) < abs($1.rating - rating) }) else { return }
        attemptedIDs.insert(candidate.id)
        startPuzzle(candidate)
    }

    func startPuzzle(_ puzzle: PuzzleItem) {
        opponentTask?.cancel()
        attemptRecorded = false
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
            self.statusMessage = "Finde den besten Zug!"

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
                statusMessage = "Richtig gelöst! 🎉"
                streak += 1
                solvedCount += 1
                updateRating(solved: true, context: context)
            } else {
                // Opponent counter move
                state = .opponentThinking
                statusMessage = "Gegner antwortet..."
                let oppUCI = puzzle.moves[moveIndex]
                opponentTask = Task {
                    do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
                    guard !Task.isCancelled else { return }
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
            streak = 0
            updateRating(solved: false, context: context)
        }
    }

    func showHint() {
        guard let puzzle = currentPuzzle, moveIndex < puzzle.moves.count else { return }
        let expectedUCI = puzzle.moves[moveIndex]
        if let move = parseUCI(expectedUCI, in: position) {
            hintSquare = move.from
            statusMessage = "Hinweis: Figur auf \(move.from.name) ziehen!"
        }
    }

    func showSolution(context: NSManagedObjectContext? = nil) {
        guard state != .solved, state != .opponentThinking,
              let puzzle = currentPuzzle, moveIndex < puzzle.moves.count else { return }
        streak = 0
        let solution = puzzle.moves[moveIndex...].joined(separator: " ")
        for uci in puzzle.moves[moveIndex...] {
            guard let move = parseUCI(uci, in: position) else { break }
            position = position.make(move)
            lastMove = move
        }
        moveIndex = puzzle.moves.count
        state = .failed
        statusMessage = "Lösung: \(solution)"
        updateRating(solved: false, context: context)
    }

    private func updateRating(solved: Bool, context: NSManagedObjectContext?) {
        guard !attemptRecorded else { return }
        attemptRecorded = true
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
    @StateObject private var viewModel = PuzzleViewModel()
    @LocalState private var isLoaded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header: Rating & Streak
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
                    Text("Serie: \(viewModel.streak) 🔥")
                        .font(.headline)
                }

                Spacer()

                if let puzzle = viewModel.currentPuzzle {
                    HStack(spacing: 6) {
                        ForEach(puzzle.themes, id: \.self) { theme in
                            Text(theme)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(SwiftUI.Color.secondary.opacity(0.15)))
                        }
                        Text("Puzzle: \(puzzle.rating) Elo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()

            Divider()

            // Main Content: Board & Controls
            HStack(spacing: 30) {
                VStack {
                    BoardView(
                        position: viewModel.position,
                        orientation: viewModel.orientation,
                        legalTargets: viewModel.legalTargets,
                        lastMove: viewModel.lastMove,
                        arrows: viewModel.hintSquare != nil ? [MoveArrow(from: viewModel.hintSquare!, to: viewModel.hintSquare!, color: SwiftUI.Color.yellow)] : [],
                        selected: viewModel.selectedSquare,
                        onSquareTap: { viewModel.squareTapped($0, context: context) }
                    )
                    .frame(width: 440, height: 440)
                    .padding()
                }

                VStack(alignment: .leading, spacing: 20) {
                    // Status banner
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.statusMessage)
                            .font(.title3).bold()
                            .foregroundStyle(
                                viewModel.state == .solved ? SwiftUI.Color.green :
                                viewModel.state == .failed ? SwiftUI.Color.red : SwiftUI.Color.primary
                            )

                        Text(viewModel.orientation == .white ? "Weiß zieht" : "Schwarz zieht")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(SwiftUI.Color.secondary.opacity(0.08)))

                    // Action buttons
                    VStack(spacing: 12) {
                        if viewModel.state == .solved || viewModel.state == .failed {
                            if viewModel.state == .failed {
                                Button("Lösung zeigen") { viewModel.showSolution(context: context) }
                                    .disabled(viewModel.moveIndex >= (viewModel.currentPuzzle?.moves.count ?? 0))
                            }
                            Button(action: { viewModel.nextPuzzle() }) {
                                Label("Nächstes Puzzle", systemImage: "arrow.forward.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
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
                .frame(width: 280)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Taktik-Puzzles")
        .onAppear { loadInitialData() }
    }

    private func loadInitialData() {
        guard !isLoaded else { return }
        let progress = PuzzleProgress.fetchOrCreate(context: context)
        viewModel.rating = Int(progress.rating)
        viewModel.streak = Int(progress.currentStreak)
        viewModel.solvedCount = Int(progress.solvedCount)

        do {
            guard let url = ChessAppKitInfo.resourceBundle.url(forResource: "puzzles", withExtension: "json") else {
                viewModel.statusMessage = "Puzzle-Datei fehlt."
                return
            }
            let items = try JSONDecoder().decode([PuzzleItem].self, from: Data(contentsOf: url))
            viewModel.loadPuzzles(from: items)
        } catch {
            viewModel.statusMessage = "Puzzles konnten nicht geladen werden: \(error.localizedDescription)"
        }
        isLoaded = true
    }
}
