import Foundation
import CoreData
import ChessAppKit

enum PersonalPuzzleStore {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChessApp/personal-puzzles.json")
    }
    static func load() -> [PuzzleItem] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([PuzzleItem].self, from: data)) ?? []
    }
    static func save(_ items: [PuzzleItem]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(items).write(to: url, options: .atomic)
    }
}

extension PuzzleViewModel {
    func cancelPreparation() {
        preparationID = UUID()
        preparationTask?.cancel()
        preparationTask = nil
        let engine = personalEngine
        personalEngine = nil
        if let engine { Task { await engine.stop() } }
        if preparing { preparationMessage = "Vorbereitung abgebrochen. Vorhandene Aufgaben bleiben erhalten." }
        preparing = false
    }

    func preparePersonal(context: NSManagedObjectContext) {
        guard !preparing else { return }
        preparing = true
        preparationMessage = "Eigene Fehler werden mit Stockfish geprüft …"
        let runID = UUID()
        preparationID = runID
        preparationTask = Task { @MainActor in
            do {
                let games = try context.fetch(NSFetchRequest<SavedGame>(entityName: "SavedGame"))
                let reports = try context.fetch(NSFetchRequest<GameAnalysisEntry>(entityName: "GameAnalysisEntry"))
                let settings = AppSettings.fetchOrCreate(context: context)
                let engine = try UCIEngine(executablePath: EngineLocator.locateEngine(customPath: settings.enginePath), settings: EngineSettings(threads: 1, hashMB: 64))
                personalEngine = engine
                try await engine.start()
                var generated: [PuzzleItem] = []
                var seen = Set<String>()
                var reviewedGames = Set<UUID>()
                for report in reports.sorted(by: { $0.createdAt > $1.createdAt }) {
                    try Task.checkCancellation()
                    guard let game = games.first(where: { $0.id == report.gameID }),
                          reviewedGames.insert(game.id).inserted,
                          (game.whitePlayer == "Du") != (game.blackPlayer == "Du"),
                          let analysis = try? JSONDecoder().decode(GameAnalysis.self, from: report.analysisJSON) else { continue }
                    let own: PieceColor = game.whitePlayer == "Du" ? .white : .black
                    for (index, mistake) in analysis.moves.enumerated() where index > 0 {
                        try Task.checkCancellation()
                        guard generated.count < 24 else { break }
                        guard [.mistake, .miss, .blunder].contains(mistake.classification),
                              mistake.winPercentLoss.isFinite, mistake.winPercentLoss >= 8,
                              let pos = try? Position(fen: mistake.fenBefore), pos.turn == own,
                              pos.legalMoves().count > 1, seen.insert(mistake.fenBefore).inserted else { continue }
                        let previous = analysis.moves[index - 1]
                        guard previous.fenAfter == mistake.fenBefore,
                              let before = try? Position(fen: previous.fenBefore),
                              let setup = SAN.move(from: previous.san, in: before),
                              before.make(setup).fen == mistake.fenBefore else { continue }
                        var info: [Int: EngineInfo] = [:]
                        for await update in engine.analyze(fen: pos.fen, depth: 16, multiPV: 2) {
                            try Task.checkCancellation()
                            info[update.multiPV] = update
                        }
                        guard let best = info[1], let other = info[2], best.depth >= 16, other.depth >= 16,
                              let first = best.pv.first,
                              let played = SAN.move(from: mistake.san, in: pos), first != played.uci,
                              Self.isClearTacticalChoice(best, other, side: own) else { continue }
                        // shortcut: retain one verified decision; extend only when every later user move is also unique.
                        guard let move = pos.legalMoves().first(where: { $0.uci == first }),
                              move.promotion == nil || move.promotion == .queen else { continue }
                        // shortcut: the puzzle board promotes to queen; support a picker before admitting underpromotions.
                        let source = "\(game.whitePlayer) – \(game.blackPlayer), Zug \((mistake.ply + 1) / 2)"
                        var item = PuzzleItem(id: "own-\(game.id.uuidString)-\(mistake.ply)", fen: previous.fenBefore,
                                              moves: [setup.uci, move.uci], rating: 0, themes: ["ownMistake"])
                        item.sourceGame = source
                        item.explanation = "Aus deiner Partie: \(source). Gespielt wurde \(mistake.san). Stockfish findet mit \(SAN.notation(for: move, in: pos)) eine klar bessere Möglichkeit. " + (best.mate != nil ? "Dieser Zug erzwingt Matt." : "Dieser Zug sichert einen deutlichen Vorteil; die zweitbeste Möglichkeit verliert mindestens 1,8 Bauerneinheiten.")
                        generated.append(item)
                    }
                }
                try Task.checkCancellation()
                guard preparationID == runID else { await engine.stop(); return }
                if generated.isEmpty {
                    let validIDs = Set(games.map { $0.id.uuidString })
                    generated = PersonalPuzzleStore.load().filter { item in validIDs.contains(where: { item.id.hasPrefix("own-" + $0 + "-") }) }
                }
                try PersonalPuzzleStore.save(generated)
                puzzles = puzzles.filter { !$0.isPersonal } + generated
                await engine.stop()
                guard preparationID == runID else { return }
                personalEngine = nil
                preparing = false
                preparationMessage = generated.isEmpty ? "Keine eindeutige taktische Aufgabe gefunden. Analysiere weitere eigene Partien mit Spielername Du." : "\(generated.count) eigene Aufgaben vorbereitet · ohne Rating."
                if source == .personal { nextPuzzle() }
            } catch {
                guard preparationID == runID else { return }
                let engine = personalEngine
                personalEngine = nil
                if let engine { await engine.stop() }
                guard preparationID == runID else { return }
                if !Task.isCancelled { preparationMessage = "Vorbereitung fehlgeschlagen: \(error.localizedDescription)" }
                preparing = false
            }
        }
    }

    static func isClearTacticalChoice(_ best: EngineInfo, _ other: EngineInfo, side: PieceColor) -> Bool {
        let sign = side == .white ? 1 : -1
        if let mate = best.mate, mate * sign > 0 {
            return other.mate == nil && (other.cp.map { $0 * sign < 150 } ?? false)
        }
        guard let first = best.cp, let second = other.cp, best.mate == nil, other.mate == nil else { return false }
        return first * sign >= 150 && (first - second) * sign >= 180
    }
}
