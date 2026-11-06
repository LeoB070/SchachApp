import SwiftUI
import ChessAppKit
import CoreData
import Combine

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published var positions: [Position] = []
    @Published var sans: [String] = []
    @Published var currentPly: Int = 0
    @Published var moveAnalyses: [MoveAnalysis] = []
    @Published var accuracyWhite: Double = 0
    @Published var accuracyBlack: Double = 0
    @Published var openingName: String? = nil
    @Published var openingECO: String? = nil
    @Published var isAnalyzing: Bool = false
    @Published var analysisProgress: Double = 0

    @Published var errorMessage: String?
    @Published var showBestAlternative = false
    private var analysisTask: Task<Void, Never>?
    private var engine: UCIEngine?
    private var game: SavedGame?
    private var moves: [Move] = []

    var displayedPosition: Position {
        if showBestAlternative, currentPly > 0 { return positions[currentPly - 1] }
        return currentPosition
    }

    var currentPosition: Position {
        guard currentPly >= 0 && currentPly < positions.count else {
            return positions.first ?? (try! Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"))
        }
        return positions[currentPly]
    }

    var currentMoveAnalysis: MoveAnalysis? {
        guard currentPly > 0 && currentPly - 1 < moveAnalyses.count else { return nil }
        return moveAnalyses[currentPly - 1]
    }

    var currentEvalText: String {
        guard let analysis = currentMoveAnalysis else { return "0.0" }
        if let cp = showBestAlternative ? analysis.evalBefore : analysis.evalAfter {
            let val = Double(cp) / 100.0
            return val >= 0 ? String(format: "+%.1f", val) : String(format: "%.1f", val)
        }
        return winPercentWhite == 0 || winPercentWhite == 100 ? "Matt" : "–"
    }

    var winPercentWhite: Double {
        guard let analysis = currentMoveAnalysis else { return 50.0 }
        let percent = showBestAlternative ? analysis.winPercentBefore : analysis.winPercentAfter
        return positions[currentPly - 1].turn == .white ? percent : 100 - percent
    }

    var arrows: [MoveArrow] {
        var result: [MoveArrow] = []
        guard let analysis = currentMoveAnalysis else { return result }

        if showBestAlternative {
            if let best = parseUCIMove(analysis.bestMove) {
                result.append(MoveArrow(from: best.from, to: best.to, color: .green))
            }
        } else if let last = currentMove {
            result.append(MoveArrow(from: last.from, to: last.to, color: classificationColor(analysis.classification)))
        }

        return result
    }

    var currentMove: Move? {
        guard currentPly > 0 && currentPly < positions.count else { return nil }
        // Determine move between positions[currentPly - 1] and positions[currentPly]
        let prev = positions[currentPly - 1]
        let curr = positions[currentPly]
        for m in prev.legalMoves() {
            if prev.make(m).fen == curr.fen {
                return m
            }
        }
        return nil
    }

    init() {
        let start = try! Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        positions = [start]
    }

    func loadGame(positions: [Position], sans: [String], analyses: [MoveAnalysis] = [], whiteAcc: Double = 0, blackAcc: Double = 0, opening: String? = nil, eco: String? = nil) {
        self.positions = positions.isEmpty ? [try! Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")] : positions
        self.sans = sans
        self.moveAnalyses = analyses
        self.accuracyWhite = whiteAcc
        self.accuracyBlack = blackAcc
        self.openingName = opening
        self.openingECO = eco
        self.currentPly = 0
        self.showBestAlternative = false
    }

    func nextPly() {
        if currentPly < positions.count - 1 {
            currentPly += 1
        }
    }

    func prevPly() {
        if currentPly > 0 {
            currentPly -= 1
        }
    }

    func firstPly() {
        currentPly = 0
    }

    func lastPly() {
        currentPly = max(0, positions.count - 1)
    }

    func selectPly(_ ply: Int) {
        if ply >= 0 && ply < positions.count {
            currentPly = ply
        }
    }

    func load(_ savedGame: SavedGame?, context: NSManagedObjectContext) {
        guard let savedGame else { return }
        game = savedGame
        do {
            let parsed = try PGN.parse(savedGame.pgn)
            moves = parsed.moveList
            loadGame(positions: parsed.positions, sans: parsed.sanList, opening: savedGame.openingName)
            let request = NSFetchRequest<GameAnalysisEntry>(entityName: "GameAnalysisEntry")
            request.predicate = NSPredicate(format: "gameID == %@", savedGame.id as NSUUID)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            if let entry = try context.fetch(request).first {
                let report = try JSONDecoder().decode(GameAnalysis.self, from: entry.analysisJSON)
                apply(report)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func openPGN() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let parsed = try PGN.parse(String(contentsOf: url, encoding: .utf8))
            game = nil; moves = parsed.moveList
            loadGame(positions: parsed.positions, sans: parsed.sanList)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private func apply(_ report: GameAnalysis) {
        moveAnalyses = report.moves
        accuracyWhite = report.accuracyWhite; accuracyBlack = report.accuracyBlack
        openingName = report.openingName; openingECO = report.eco
    }

    func analyze(context: NSManagedObjectContext) {
        guard !isAnalyzing, !moves.isEmpty else { return }
        errorMessage = nil
        let settings = AppSettings.fetchOrCreate(context: context)
        do {
            guard let path = locateEngine(customPath: settings.enginePath) else {
                throw EngineError.binaryNotFound("Installiere Stockfish mit brew install stockfish oder wähle den Engine-Pfad in Einstellungen.")
            }
            let engine = try UCIEngine(executablePath: path, settings: EngineSettings(appSettings: settings))
            self.engine = engine
            let service = GameReviewService(engine: engine)
            isAnalyzing = true; analysisProgress = 0
            analysisTask = Task {
                do {
                    for try await progress in service.review(positions: positions, moves: moves, depth: Int(settings.analysisDepth)) {
                        try Task.checkCancellation()
                        apply(progress.analysis)
                        analysisProgress = Double(progress.completedPlies) / Double(max(1, progress.totalPlies))
                    }
                    try Task.checkCancellation()
                    if let game {
                        let report = GameAnalysis(moves: moveAnalyses, accuracyWhite: accuracyWhite, accuracyBlack: accuracyBlack, eco: openingECO, openingName: openingName)
                        let data = try JSONEncoder().encode(report)
                        let entry = GameAnalysisEntry(context: context)
                        entry.gameID = game.id; entry.analysisJSON = data
                        entry.accuracyWhite = accuracyWhite; entry.accuracyBlack = accuracyBlack
                        entry.openingName = openingName; entry.openingECO = openingECO
                        game.openingName = openingName
                        do { try context.save() }
                        catch { context.delete(entry); throw error }
                    }
                } catch {
                    if !Task.isCancelled { errorMessage = error.localizedDescription }
                }
                await engine.stop()
                self.engine = nil; isAnalyzing = false
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func cancelAnalysis() {
        analysisTask?.cancel()
        if let engine { Task { await engine.stop() } }
    }

    private func parseUCIMove(_ uci: String) -> (from: Square, to: Square)? {
        guard uci.count >= 4 else { return nil }
        let fromStr = String(uci.prefix(2))
        let toStr = String(uci.dropFirst(2).prefix(2))
        guard let f = Square(string: fromStr), let t = Square(string: toStr) else { return nil }
        return (from: f, to: t)
    }

    func classificationColor(_ c: MoveClassification) -> SwiftUI.Color {
        switch c {
        case .brilliant: return SwiftUI.Color.cyan
        case .great: return SwiftUI.Color.blue
        case .best: return SwiftUI.Color.green
        case .excellent: return SwiftUI.Color.mint
        case .good: return SwiftUI.Color.teal
        case .book: return SwiftUI.Color.brown
        case .inaccuracy: return SwiftUI.Color.yellow
        case .mistake: return SwiftUI.Color.orange
        case .miss: return SwiftUI.Color.red.opacity(0.8)
        case .blunder: return SwiftUI.Color.red
        }
    }
}

struct EvalBarView: View {
    let winPercentWhite: Double
    let evalText: String

    var body: some View {
        VStack(spacing: 0) {
            // Black portion
            Rectangle()
                .fill(SwiftUI.Color.black.opacity(0.85))
                .frame(maxHeight: .infinity)

            // White portion
            Rectangle()
                .fill(SwiftUI.Color.white)
                .frame(height: max(4, min(360, CGFloat(winPercentWhite / 100.0) * 360)))
        }
        .frame(width: 26, height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(SwiftUI.Color.secondary.opacity(0.4), lineWidth: 1)
        )
        .overlay(alignment: winPercentWhite > 50 ? .bottom : .top) {
            Text(evalText)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(winPercentWhite > 50 ? .black : .white)
                .padding(2)
        }
    }
}

struct ReviewView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var viewModel = ReviewViewModel()
    var game: SavedGame? = nil

    var body: some View {
        HStack(spacing: 20) {
            // Left: Eval Bar + Board
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    EvalBarView(winPercentWhite: viewModel.winPercentWhite, evalText: viewModel.currentEvalText)

                    BoardView(
                        position: viewModel.displayedPosition,
                        orientation: .white,
                        legalTargets: [],
                        lastMove: viewModel.showBestAlternative ? nil : viewModel.currentMove,
                        arrows: viewModel.arrows,
                        selected: nil,
                        onSquareTap: { _ in }
                    )
                    .frame(width: 440, height: 440)
                }

                // Playback Controls
                HStack(spacing: 16) {
                    Button(action: { viewModel.firstPly() }) {
                        Image(systemName: "backward.end.fill")
                    }
                    .keyboardShortcut(.upArrow, modifiers: [])

                    Button(action: { viewModel.prevPly() }) {
                        Image(systemName: "chevron.left")
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [])

                    Text("Zug \(viewModel.currentPly) / \(max(0, viewModel.positions.count - 1))")
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 120)

                    Button(action: { viewModel.nextPly() }) {
                        Image(systemName: "chevron.right")
                    }
                    .keyboardShortcut(.rightArrow, modifiers: [])

                    Button(action: { viewModel.lastPly() }) {
                        Image(systemName: "forward.end.fill")
                    }
                    .keyboardShortcut(.downArrow, modifiers: [])
                }
                .buttonStyle(.bordered)
            }
            .padding()

            // Right: Analysis Details & Moves
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button("PGN öffnen …") { viewModel.openPGN() }.disabled(viewModel.isAnalyzing)
                    if viewModel.isAnalyzing {
                        Button("Abbrechen") { viewModel.cancelAnalysis() }
                    } else {
                        Button("Analysieren") { viewModel.analyze(context: context) }.disabled(viewModel.sans.isEmpty)
                    }
                }
                if viewModel.isAnalyzing { ProgressView(value: viewModel.analysisProgress) }
                if let error = viewModel.errorMessage { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                if viewModel.sans.isEmpty { Text("Öffne eine PGN-Datei oder wähle eine Partie im Archiv.").foregroundStyle(.secondary) }
                // Header & Accuracies
                VStack(alignment: .leading, spacing: 6) {
                    if let opening = viewModel.openingName {
                        HStack {
                            if let eco = viewModel.openingECO {
                                Text(eco)
                                    .font(.caption).bold()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(SwiftUI.Color.accentColor.opacity(0.2)))
                            }
                            Text(opening).font(.headline)
                        }
                    }

                    HStack(spacing: 12) {
                        accuracyBadge(title: "Genauigkeit Weiß", value: viewModel.accuracyWhite, color: .white)
                        accuracyBadge(title: "Genauigkeit Schwarz", value: viewModel.accuracyBlack, color: .black)
                    }
                }

                // Eval Graph
                EvalGraphView(
                    points: viewModel.moveAnalyses.enumerated().map { idx, m in
                        EvalGraphPoint(
                            id: idx + 1,
                            ply: m.ply,
                            winPercentWhite: (try? Position(fen: m.fenBefore))?.turn == .black ? 100 - m.winPercentAfter : m.winPercentAfter,
                            evalText: String(format: "%.1f", Double(m.evalAfter ?? 0) / 100.0)
                        )
                    },
                    currentPly: viewModel.currentPly,
                    onSelectPly: { viewModel.selectPly($0) }
                )

                // Current Move Feedback
                if let analysis = viewModel.currentMoveAnalysis {
                    HStack(spacing: 10) {
                        classificationBadge(analysis.classification)
                        VStack(alignment: .leading, spacing: 2) {
                            Toggle("Beste Alternative zeigen", isOn: $viewModel.showBestAlternative)
                                .toggleStyle(.checkbox)
                            Text(analysis.classification.title)
                                .font(.headline)
                            if analysis.classification == .blunder || analysis.classification == .mistake || analysis.classification == .inaccuracy || analysis.classification == .miss {
                                Text("Bester Zug: \(analysis.bestMove)")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                        Spacer()
                        Text(String(format: "%.1f%%", analysis.accuracy))
                            .font(.system(.title3, design: .monospaced).bold())
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(viewModel.classificationColor(analysis.classification).opacity(0.15)))
                }

                if !viewModel.moveAnalyses.isEmpty {
                    Text(MoveClassification.allCases.compactMap { type in
                        let count = viewModel.moveAnalyses.filter { $0.classification == type }.count
                        return count > 0 ? "\(type.symbol) \(count)" : nil
                    }.joined(separator: "   ")).font(.caption)
                }
                // Moves List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(stride(from: 0, to: viewModel.sans.count, by: 2)), id: \.self) { i in
                                HStack(spacing: 8) {
                                    Text("\(i / 2 + 1).")
                                        .frame(width: 32, alignment: .leading)
                                        .foregroundStyle(.secondary)

                                    moveButton(ply: i + 1, text: viewModel.sans[i])
                                    if i + 1 < viewModel.sans.count {
                                        moveButton(ply: i + 2, text: viewModel.sans[i + 1])
                                    }
                                }
                                .font(.system(.body, design: .monospaced))
                                .id(i + 1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(width: 360)
            .padding()
        }
        .navigationTitle("Partie-Analyse")
        .onAppear { viewModel.load(game, context: context) }
        .onDisappear { viewModel.cancelAnalysis() }
    }

    private func accuracyBadge(title: String, value: Double, color: PieceColor) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(String(format: "%.1f%%", value))
                .font(.title3).bold()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(SwiftUI.Color.secondary.opacity(0.1)))
    }

    private func classificationBadge(_ c: MoveClassification) -> some View {
        Text(c.symbol)
            .font(.headline).bold()
            .padding(6)
            .background(Circle().fill(viewModel.classificationColor(c).opacity(0.3)))
    }

    private func moveButton(ply: Int, text: String) -> some View {
        let isSelected = viewModel.currentPly == ply
        let classification = (ply <= viewModel.moveAnalyses.count) ? viewModel.moveAnalyses[ply - 1].classification : nil

        return Button(action: { viewModel.selectPly(ply) }) {
            HStack(spacing: 4) {
                Text(text)
                if let c = classification {
                    Text(c.symbol)
                        .font(.caption2).bold()
                        .foregroundStyle(viewModel.classificationColor(c))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? SwiftUI.Color.accentColor.opacity(0.25) : SwiftUI.Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
