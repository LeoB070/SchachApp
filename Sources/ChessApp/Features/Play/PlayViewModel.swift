import Foundation
import AppKit
import Combine
import CoreData
import ChessAppKit

@MainActor
final class PlayViewModel: ObservableObject {
    @Published var positions: [Position] = []
    @Published var sans: [String] = []
    @Published var selectedSquare: Square?
    @Published var legalTargets: Set<Square> = []
    @Published var lastMove: Move?
    @Published var orientation: PieceColor = .white
    @Published var pendingPromotion: (from: Square, to: Square)?
    @Published var playerColor: PieceColor = .white
    @Published var botID = BotLibrary.anton.id
    @Published var skillLevel = 10
    @Published var timeControl: TimeControl = .unlimited
    @Published var whiteTime: TimeInterval?
    @Published var blackTime: TimeInterval?
    @Published var result = "*"
    @Published var ending = ""
    @Published var errorMessage: String?
    @Published var savedGame: SavedGame?
    @Published var isThinking = false
    private var engine: UCIEngine?
    private var moveTask: Task<Void, Never>?
    private var lastTick: Date?
    private var gameID = UUID()
    private var moves: [PGNMove] = []
    private var activeBot = BotLibrary.anton
    private var activeTimeControl: TimeControl = .unlimited
    private var activePlayerColor: PieceColor = .white
    var currentPosition: Position { positions.last! }
    var statusText: String {
        if result != "*" { return ending }
        if isThinking { return "\(activeBot.name) denkt …" }
        return "\(currentPosition.turn == .white ? "Weiß" : "Schwarz") am Zug"
    }

    init() { reset() }

    private func reset() {
        positions = [PGNGame().initialPosition]
        sans = []; moves = []; legalTargets = []
        selectedSquare = nil; lastMove = nil; pendingPromotion = nil
        result = "*"; ending = ""; errorMessage = nil; savedGame = nil
        gameID = UUID(); isThinking = false
        if botID == "stockfish_custom" {
            activeBot = Bot(id: botID, name: "Stockfish (Stufe \(skillLevel))", description: "", elo: 2500,
                            skillLevel: skillLevel, randomness: 0, movetimeMs: 1000)
        } else { activeBot = BotLibrary.bot(forId: botID) ?? BotLibrary.anton }
        activeTimeControl = timeControl; activePlayerColor = playerColor
        orientation = playerColor
        whiteTime = timeControl.initialSeconds; blackTime = timeControl.initialSeconds
        lastTick = nil
    }

    func newGame(context: NSManagedObjectContext) {
        stop()
        reset()
        resume(context: context)
    }

    func resume(context: NSManagedObjectContext) {
        guard result == "*", engine == nil else { return }
        let settings = AppSettings.fetchOrCreate(context: context)
        do {
            guard let path = locateEngine(customPath: settings.enginePath) else {
                throw EngineError.binaryNotFound("Stockfish fehlt. Installiere es mit brew install stockfish oder wähle den Pfad in Einstellungen.")
            }
            engine = try UCIEngine(executablePath: path, settings: EngineSettings(appSettings: settings))
            lastTick = Date()
            requestBot(context: context)
        } catch { errorMessage = error.localizedDescription }
    }

    func stop() {
        moveTask?.cancel(); moveTask = nil
        if let engine { Task { await engine.stop() } }
        engine = nil; lastTick = nil; isThinking = false
    }

    func flipBoard() { orientation = orientation == .white ? .black : .white }

    func tick(context: NSManagedObjectContext, now: Date = Date()) {
        guard result == "*", let previous = lastTick else { return }
        lastTick = now
        let elapsed = max(0, now.timeIntervalSince(previous))
        if currentPosition.turn == .white, let time = whiteTime { whiteTime = max(0, time - elapsed) }
        if currentPosition.turn == .black, let time = blackTime { blackTime = max(0, time - elapsed) }
        if whiteTime == 0 { finish("0-1", reason: "Zeit abgelaufen – Schwarz gewinnt", context: context) }
        else if blackTime == 0 { finish("1-0", reason: "Zeit abgelaufen – Weiß gewinnt", context: context) }
    }

    func squareTapped(_ square: Square, context: NSManagedObjectContext) {
        guard result == "*", engine != nil, !isThinking,
              currentPosition.turn == activePlayerColor, pendingPromotion == nil else { return }
        tick(context: context)
        guard result == "*" else { return }
        if selectedSquare == square { selectedSquare = nil; legalTargets = []; return }
        if let piece = currentPosition.board[square.index], piece.color == currentPosition.turn {
            selectedSquare = square
            legalTargets = Set(currentPosition.legalMoves().filter { $0.from == square }.map(\.to))
        } else if let selected = selectedSquare, legalTargets.contains(square), let move = currentPosition.move(from: selected, to: square) {
            if move.promotion != nil { pendingPromotion = (selected, square) }
            else { apply(move, context: context); requestBot(context: context) }
        }
    }

    func promote(to type: PieceType, context: NSManagedObjectContext) {
        guard let (from, to) = pendingPromotion else { return }
        pendingPromotion = nil
        tick(context: context)
        guard result == "*", let move = currentPosition.move(from: from, to: to, promotion: type) else { return }
        apply(move, context: context); requestBot(context: context)
    }

    func cancelPromotion() { pendingPromotion = nil }

    private func apply(_ move: Move, context: NSManagedObjectContext) {
        let position = currentPosition
        if AppSettings.fetchOrCreate(context: context).soundEnabled { NSSound.beep() }
        let san = SAN.notation(for: move, in: position)
        moves.append(PGNMove(move: move, san: san)); sans.append(san)
        if position.turn == .white, let time = whiteTime { whiteTime = time + activeTimeControl.incrementSeconds }
        if position.turn == .black, let time = blackTime { blackTime = time + activeTimeControl.incrementSeconds }
        positions.append(position.make(move)); lastMove = move
        selectedSquare = nil; legalTargets = []
        let count = positions.filter { $0.repetitionKey == currentPosition.repetitionKey }.count
        switch GameOutcome.evaluate(position: currentPosition, repetitionCount: count) {
        case .ongoing: break
        case .checkmate(let winner): finish(winner == .white ? "1-0" : "0-1", reason: "Matt – \(winner == .white ? "Weiß" : "Schwarz") gewinnt", context: context)
        case .stalemate: finish("1/2-1/2", reason: "Patt – Remis", context: context)
        case .threefold: finish("1/2-1/2", reason: "Dreifache Wiederholung – Remis", context: context)
        case .fiftyMove: finish("1/2-1/2", reason: "50-Züge-Regel – Remis", context: context)
        case .insufficientMaterial: finish("1/2-1/2", reason: "Ungenügendes Material – Remis", context: context)
        }
    }

    private func requestBot(context: NSManagedObjectContext) {
        guard result == "*", currentPosition.turn != activePlayerColor, let engine else { return }
        let expectedGame = gameID
        let fen = currentPosition.fen
        isThinking = true
        moveTask = Task {
            do {
                try await engine.start()
                let uci = try await activeBot.chooseMove(fen: fen, engine: engine)
                guard !Task.isCancelled, gameID == expectedGame, result == "*" else { return }
                tick(context: context)
                guard result == "*" else { return }
                guard let move = currentPosition.legalMoves().first(where: { $0.uci == uci }) else {
                    throw EngineError.unexpectedResponse(uci)
                }
                isThinking = false
                apply(move, context: context)
            } catch {
                guard !Task.isCancelled, gameID == expectedGame else { return }
                errorMessage = error.localizedDescription
                stop()
            }
        }
    }

    func resign(context: NSManagedObjectContext) {
        guard result == "*" else { return }
        finish(activePlayerColor == .white ? "0-1" : "1-0", reason: "Aufgegeben – \(activePlayerColor == .white ? "Schwarz" : "Weiß") gewinnt", context: context)
    }

    private func finish(_ value: String, reason: String, context: NSManagedObjectContext) {
        result = value; ending = reason; pendingPromotion = nil
        stop()
        save(context: context)
    }

    func save(context: NSManagedObjectContext) {
        guard result != "*", savedGame == nil else { return }
        let game = SavedGame(context: context)
        game.whitePlayer = activePlayerColor == .white ? "Du" : activeBot.name
        game.blackPlayer = activePlayerColor == .black ? "Du" : activeBot.name
        game.openingName = (try? OpeningBook())?.match(sanMoves: sans)?.name
        game.result = result; game.timeControl = activeTimeControl.rawValue
        game.pgn = PGN.export(PGNGame(headers: ["White": game.whitePlayer, "Black": game.blackPlayer, "Result": result], moves: moves, result: result))
        do { try context.save(); savedGame = game }
        catch { context.delete(game); errorMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)" }
    }
}
