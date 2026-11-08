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
    @Published var practice = ReviewPractice()
    private var analysisGeneration = UUID()
    private var ownSide: PieceColor?

    var hasOwnSide: Bool { ownSide != nil }

    func configuredBot(for player: PieceColor) -> Bot? {
        guard let ownSide, player != ownSide, let game else { return nil }
        let name = player == .white ? game.whitePlayer : game.blackPlayer
        return BotLibrary.allBots.first { BotLibrary.matchesSavedName(name, bot: $0) }
    }

    func performanceText(for player: PieceColor, phase: GamePhase? = nil) -> String {
        let selected = moveAnalyses.filter { phase == nil || $0.phase == phase }
        let report = GameAnalysis(moves: selected,
            accuracyWhite: phase == nil ? accuracyWhite : AccuracyCalculator.gameAccuracy(for: .white, moves: selected),
            accuracyBlack: phase == nil ? accuracyBlack : AccuracyCalculator.gameAccuracy(for: .black, moves: selected))
        let opponent: PieceColor = player == .white ? .black : .white
        // A bot's configured strength is a reference, not a measured performance rating.
        let reference = configuredBot(for: opponent)?.elo ?? configuredBot(for: player)?.elo
        return report.estimatedElo(for: player, opponentElo: reference).map { "≈ \($0)" } ?? "–"
    }

    var keyMoments: [MoveAnalysis] {
        ReviewPractice.moments(analyses: moveAnalyses, positions: positions, ownSide: ownSide)
    }

    var practiceTargets: Set<Square> {
        guard !practice.revealed, let position = practice.position, let selected = practice.selected else { return [] }
        return Set(position.legalMoves().filter { $0.from == selected }.map(\.to))
    }

    func startPractice(_ moment: MoveAnalysis) {
        showBestAlternative = false
        currentPly = moment.ply
        practice.start(moment)
    }

    var candidateMoments: [MoveAnalysis] {
        guard hasOwnSide else { return [] }
        return keyMoments.filter { ReviewPractice.candidates(for: $0).count == 2 }
    }

    func startCandidatePractice(_ moment: MoveAnalysis) {
        guard candidateMoments.contains(where: { $0.id == moment.id }) else { return }
        showBestAlternative = false
        currentPly = moment.ply
        practice.startCandidates(moment)
    }

    func nextMoment() {
        let candidates = practice.isCandidateChoice
        let moments = candidates ? candidateMoments : keyMoments
        guard let id = practice.moment?.id, let index = moments.firstIndex(where: { $0.id == id }),
              index + 1 < moments.count else { practice.reset(); return }
        if candidates { startCandidatePractice(moments[index + 1]) }
        else { startPractice(moments[index + 1]) }
    }

    private var analysisTask: Task<Void, Never>?
    private var engine: UCIEngine?
    private var game: SavedGame?
    private var moves: [Move] = []

    var displayedPosition: Position {
        if let position = practice.position { return position }
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
        if practice.isCandidateChoice && !practice.revealed { return "?" }
        guard let analysis = practice.moment ?? currentMoveAnalysis else { return "0.0" }
        if let cp = (showBestAlternative || practice.moment != nil) ? analysis.evalBefore : analysis.evalAfter {
            let val = Double(cp) / 100.0
            return val >= 0 ? String(format: "+%.1f", val) : String(format: "%.1f", val)
        }
        return winPercentWhite == 0 || winPercentWhite == 100 ? "Matt" : "–"
    }

    var winPercentWhite: Double {
        if practice.isCandidateChoice && !practice.revealed { return 50 }
        guard let analysis = practice.moment ?? currentMoveAnalysis else { return 50.0 }
        let percent = (showBestAlternative || practice.moment != nil) ? analysis.winPercentBefore : analysis.winPercentAfter
        return positions[currentPly - 1].turn == .white ? percent : 100 - percent
    }

    var arrows: [MoveArrow] {
        if practice.moment != nil {
            if practice.revealed, let move = practice.solution {
                return [MoveArrow(from: move.from, to: move.to, color: .green)]
            }
            return []
        }
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

    /// Engine-Bestzug der Stellung vor dem aktuellen Zug in SAN.
    var bestMoveSAN: String? {
        guard let analysis = currentMoveAnalysis, currentPly > 0 else { return nil }
        let before = positions[currentPly - 1]
        guard let move = before.legalMoves().first(where: { $0.uci == analysis.bestMove }) else { return nil }
        return SAN.notation(for: move, in: before)
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
        practice.reset()
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
        practice.reset()
        if currentPly < positions.count - 1 {
            currentPly += 1
        }
    }

    func prevPly() {
        practice.reset()
        if currentPly > 0 {
            currentPly -= 1
        }
    }

    func firstPly() {
        practice.reset()
        currentPly = 0
    }

    func lastPly() {
        practice.reset()
        currentPly = max(0, positions.count - 1)
    }

    func selectPly(_ ply: Int) {
        practice.reset()
        if ply >= 0 && ply < positions.count {
            currentPly = ply
        }
    }

    func load(_ savedGame: SavedGame?, context: NSManagedObjectContext) {
        guard let savedGame else { return }
        cancelAnalysis()
        game = savedGame
        ownSide = savedGame.whitePlayer == "Du" && savedGame.blackPlayer != "Du" ? .white :
            (savedGame.blackPlayer == "Du" && savedGame.whitePlayer != "Du" ? .black : nil)
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
            cancelAnalysis()
            ownSide = nil
            game = nil; moves = parsed.moveList
            loadGame(positions: parsed.positions, sans: parsed.sanList)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private func apply(_ report: GameAnalysis) {
        practice.reset()
        moveAnalyses = report.moves
        accuracyWhite = report.accuracyWhite; accuracyBlack = report.accuracyBlack
        openingName = report.openingName; openingECO = report.eco
    }

    func analyze(context: NSManagedObjectContext) {
        guard !isAnalyzing, !moves.isEmpty else { return }
        practice.reset()
        let generation = UUID()
        analysisGeneration = generation
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
                        guard analysisGeneration == generation else { return }
                        apply(progress.analysis)
                        analysisProgress = Double(progress.completedPlies) / Double(max(1, progress.totalPlies))
                    }
                    try Task.checkCancellation()
                    guard analysisGeneration == generation else { return }
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
                    if !Task.isCancelled && analysisGeneration == generation { errorMessage = error.localizedDescription }
                }
                await engine.stop()
                if analysisGeneration == generation { self.engine = nil; isAnalyzing = false }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func cancelAnalysis() {
        practice.reset()
        analysisGeneration = UUID()
        analysisTask?.cancel()
        isAnalyzing = false
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
        case .excellent: return SwiftUI.Color(red: 0.90, green: 0.68, blue: 0.18)
        case .good: return SwiftUI.Color(red: 0.55, green: 0.68, blue: 0.35)
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
    @LocalState private var phaseShowsElo = true
    @LocalState private var trainingPosition: Position? = nil
    @LocalState private var showPositionTraining = false

    var body: some View {
        HStack(spacing: 20) {
            // Left: Eval Bar + Board
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    EvalBarView(winPercentWhite: viewModel.winPercentWhite, evalText: viewModel.currentEvalText)

                    BoardView(
                        position: viewModel.displayedPosition,
                        orientation: viewModel.practice.position?.turn ?? .white,
                        legalTargets: viewModel.practiceTargets,
                        lastMove: viewModel.practice.moment != nil || viewModel.showBestAlternative ? nil : viewModel.currentMove,
                        arrows: viewModel.arrows,
                        selected: viewModel.practice.selected,
                        onSquareTap: { viewModel.practice.tap($0) }
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
                Button("Ab hier gegen Bot") {
                    trainingPosition = viewModel.displayedPosition
                    showPositionTraining = true
                }
                .disabled(viewModel.positions.isEmpty || viewModel.isAnalyzing || (viewModel.practice.isCandidateChoice && !viewModel.practice.revealed))
            }
            .padding()

            // Right: Analysis Details & Moves
            ScrollView {
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
                // Opening
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

                guidedReviewCard

                if viewModel.practice.moment == nil { currentMoveCard }

                if !viewModel.practice.isCandidateChoice || viewModel.practice.revealed {
                if !viewModel.moveAnalyses.isEmpty {
                    reviewSummary
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

                if !viewModel.moveAnalyses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deine Partie nach Phasen").font(.headline)
                        Picker("Phasenwerte", selection: $phaseShowsElo) {
                            Text("Partie-Elo ≈").tag(true)
                            Text("Genauigkeit %").tag(false)
                        }.pickerStyle(.segmented)
                        HStack {
                            Text("Phase").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Weiß").frame(width: 65, alignment: .trailing)
                            Text("Schwarz").frame(width: 65, alignment: .trailing)
                        }.font(.caption).foregroundStyle(.secondary)
                        ForEach(GamePhase.allCases, id: \.self) { phase in
                            HStack {
                                Text(phase.rawValue).frame(maxWidth: .infinity, alignment: .leading)
                                Text(phaseShowsElo ? viewModel.performanceText(for: .white, phase: phase) : phaseAccuracy(phase, .white)).frame(width: 65, alignment: .trailing)
                                Text(phaseShowsElo ? viewModel.performanceText(for: .black, phase: phase) : phaseAccuracy(phase, .black)).frame(width: 65, alignment: .trailing)
                            }.font(.system(.caption, design: .monospaced))
                        }
                        Text(phaseShowsElo ? "Grobe Orientierung, ab 10 Zügen je Seite und Phase. – bedeutet: zu wenige Züge." : "Genauigkeit der Züge je Phase. Hohe Werte bedeuten nicht automatisch hohe Elo.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(SwiftUI.Color.secondary.opacity(0.08)))
                }
                // Moves List
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
              .padding()
            }
            .frame(width: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .tint(AppTheme.accent)
        .navigationTitle("Partie-Analyse")
        .onAppear { viewModel.load(game, context: context) }
        .onDisappear { viewModel.cancelAnalysis() }
        .sheet(isPresented: $showPositionTraining) {
            if let trainingPosition { PositionTrainingView(position: trainingPosition) }
        }
        .overlay {
            if let position = viewModel.practice.position, viewModel.practice.pendingPromotion != nil {
                PromotionPicker(color: position.turn,
                    onSelect: { viewModel.practice.promote($0) },
                    onCancel: { viewModel.practice.pendingPromotion = nil; viewModel.practice.selected = nil })
            }
        }
    }

    private var guidedReviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(viewModel.hasOwnSide ? "Deine Schlüsselmomente" : "Schlüsselmomente beider Seiten", systemImage: "lightbulb").font(.headline)
            if let moment = viewModel.practice.moment, let position = viewModel.practice.position {
                let moments = viewModel.practice.isCandidateChoice ? viewModel.candidateMoments : viewModel.keyMoments
                let index = moments.firstIndex { $0.id == moment.id } ?? 0
                Text("Moment \(index + 1) von \(moments.count) · \(position.turn == .white ? "Weiß" : "Schwarz") am Zug")
                    .font(.subheadline)
                if viewModel.practice.revealed {
                    if let explanation = viewModel.practice.explanation { Text(explanation) }
                } else {
                    if viewModel.practice.isCandidateChoice {
                        Text("Welcher Zug vermeidet den Fehler? Wähle eine der beiden Möglichkeiten.")
                        ForEach(viewModel.practice.candidates, id: \.uci) { move in
                            Button(SAN.notation(for: move, in: position)) { viewModel.practice.attempt(move) }
                                .buttonStyle(.bordered)
                        }
                    } else { Text("Finde eine bessere Fortsetzung. Wähle einen Zug auf dem Brett.") }
                }
                if let feedback = viewModel.practice.feedback {
                    Text(feedback).font(.callout).accessibilityAddTraits(.updatesFrequently)
                }
                HStack {
                    if viewModel.practice.revealed {
                        Button(index + 1 < moments.count ? "Nächster Moment" : "Abschließen") { viewModel.nextMoment() }
                    } else {
                        Button("Lösung zeigen") {
                            viewModel.practice.revealed = true
                            viewModel.practice.selected = nil
                            viewModel.practice.pendingPromotion = nil
                        }
                    }
                    Button("Zur Partie") { viewModel.practice.reset() }
                }
            } else if let first = viewModel.keyMoments.first, !viewModel.isAnalyzing {
                Text("Bis zu drei wichtige Fehler noch einmal selbst lösen. Die Partie und ihre Genauigkeit bleiben erhalten.")
                    .font(.subheadline)
                Button("Gemeinsam durchgehen") { viewModel.startPractice(first) }.buttonStyle(.borderedProminent)
                if let candidate = viewModel.candidateMoments.first {
                    Button("Zwei Züge vergleichen") { viewModel.startCandidatePractice(candidate) }
                        .buttonStyle(.bordered)
                    Text("Eigener Fehlzug oder gespeicherte Engine-Empfehlung? Mindestens 10 Prozentpunkte Unterschied laut Partieanalyse.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(viewModel.keyMoments) { moment in
                    Button {
                        viewModel.selectPly(moment.ply)
                    } label: {
                        HStack {
                            Text("\((moment.ply + 1) / 2)\(moment.ply.isMultiple(of: 2) ? "…" : ".") \(moment.san)").bold()
                            Spacer()
                            Text(String(format: "−%.1f Gewinnchance", moment.winPercentLoss) + " %")
                        }.font(.caption)
                    }.buttonStyle(.bordered)
                }
            } else {
                Text(viewModel.isAnalyzing ? "Die Analyse sucht nach Schlüsselmomenten …" :
                    "Noch keine passenden Schlüsselmomente. Analysiere eine Partie, um hier zu üben.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .panel()
    }

    private var reviewSummary: some View {
        VStack(spacing: 8) {
            Text("Partieübersicht").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text("Genauigkeit").frame(maxWidth: .infinity, alignment: .leading)
                Text(String(format: "%.1f%%", viewModel.accuracyWhite))
                    .foregroundStyle(.black)
                    .frame(width: 72).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 5).fill(.white))
                Text(String(format: "%.1f%%", viewModel.accuracyBlack))
                    .foregroundStyle(.white)
                    .frame(width: 72).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 5).fill(SwiftUI.Color.black.opacity(0.75)))
            }
            HStack {
                Text("Partie-Elo ≈").frame(maxWidth: .infinity, alignment: .leading)
                Text(viewModel.performanceText(for: .white)).frame(width: 72)
                Text(viewModel.performanceText(for: .black)).frame(width: 72)
            }.font(.subheadline)
            if let bot = viewModel.configuredBot(for: .white) ?? viewModel.configuredBot(for: .black) {
                Text("\(bot.name): eingestellte Bot-Stärke \(bot.elo) Elo")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Unkalibrierte Orientierung ab 10 Zügen je Seite. Bot-Stärke dient als Bezug; einzelne Partien belegen kein Rating.")
                .font(.caption2).foregroundStyle(.secondary)
            Divider()
            HStack {
                Text("Zugqualität").frame(maxWidth: .infinity, alignment: .leading)
                Text("Weiß").frame(width: 44)
                Text("").frame(width: 30)
                Text("Schwarz").frame(width: 52)
            }.font(.caption).foregroundStyle(.secondary)
            ForEach(MoveClassification.allCases, id: \.self) { type in
                let color = viewModel.classificationColor(type)
                HStack(spacing: 6) {
                    Text(type.title).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(classificationCount(type, .white))").frame(width: 44)
                    symbolText(type)
                        .font(.caption).bold()
                        .foregroundStyle(type == .inaccuracy || type == .excellent ? .black : .white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(color))
                    Text("\(classificationCount(type, .black))").frame(width: 52)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(12)
        .panel()
    }

    private func classificationCount(_ type: MoveClassification, _ player: PieceColor) -> Int {
        viewModel.moveAnalyses.filter {
            $0.classification == type && (try? Position(fen: $0.fenBefore).turn) == player
        }.count
    }

    private func phaseAccuracy(_ phase: GamePhase, _ player: PieceColor) -> String {
        let moves = viewModel.moveAnalyses.filter { $0.phase == phase }
        guard moves.contains(where: {
            ((try? Position(fen: $0.fenBefore).turn) ?? ($0.ply.isMultiple(of: 2) ? .black : .white)) == player
        }) else { return "–" }
        return String(format: "%.0f%%", AccuracyCalculator.gameAccuracy(for: player, moves: moves))
    }

    private func classificationBadge(_ c: MoveClassification) -> some View {
        symbolText(c)
            .font(.headline).bold()
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Circle().fill(viewModel.classificationColor(c)))
    }

    private func symbolText(_ c: MoveClassification) -> Text {
        c == .book ? Text(Image(systemName: "book.fill")) : Text(c.symbol)
    }

    /// Erklärt den aktuell gewählten Zug: Qualität, Bewertung und besseren Engine-Zug.
    @ViewBuilder private var currentMoveCard: some View {
        if let analysis = viewModel.currentMoveAnalysis {
            let c = analysis.classification
            let moveNumber = "\((analysis.ply + 1) / 2)\(analysis.ply % 2 == 1 ? "." : "…")"
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    classificationBadge(c)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(moveNumber) \(analysis.san) ist \(c.title)")
                            .font(.headline)
                            .foregroundStyle(viewModel.classificationColor(c))
                        Text("Bewertung \(viewModel.currentEvalText) · Zug-Genauigkeit \(String(format: "%.0f%%", analysis.accuracy))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let position = try? Position(fen: analysis.fenBefore),
                   let played = SAN.move(from: analysis.san, in: position),
                   position.make(played).fen == analysis.fenAfter {
                    let facts = ReviewPractice.moveFacts(played, in: position)
                    if !facts.isEmpty { Text(facts).font(.callout) }
                }
                if c == .book {
                    Text("Ein bekannter Eröffnungszug.").font(.subheadline)
                } else if let best = viewModel.bestMoveSAN, best != analysis.san {
                    Text("Bester Zug war **\(best)** – Gewinnchance −\(String(format: "%.1f", analysis.winPercentLoss)) %.")
                        .font(.subheadline)
                    Toggle("Besten Zug auf dem Brett zeigen", isOn: $viewModel.showBestAlternative)
                        .toggleStyle(.switch).controlSize(.small)
                } else {
                    Text("Das war der beste Zug der Engine.").font(.subheadline)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(viewModel.classificationColor(c).opacity(0.12)))
        } else if viewModel.currentPly > 0, !viewModel.moveAnalyses.isEmpty || viewModel.isAnalyzing {
            Text("Dieser Zug wurde noch nicht analysiert.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func moveButton(ply: Int, text: String) -> some View {
        let isSelected = viewModel.currentPly == ply
        let classification = (ply <= viewModel.moveAnalyses.count) ? viewModel.moveAnalyses[ply - 1].classification : nil

        return Button(action: { viewModel.selectPly(ply) }) {
            HStack(spacing: 4) {
                Text(text)
                if let c = classification {
                    symbolText(c)
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
