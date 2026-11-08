import Foundation
import AppKit
import Combine
import CoreData
import ChessAppKit

enum MoveSound: String, CaseIterable {
    case pop = "Pop", tink = "Tink", glass = "Glass", morse = "Morse"

    var title: String {
        switch self {
        case .pop: return "Klick"
        case .tink: return "Hell"
        case .glass: return "Glas"
        case .morse: return "Signal"
        }
    }

    static func selected(enabled: Bool, defaults: UserDefaults = .standard) -> MoveSound? {
        guard enabled else { return nil }
        return MoveSound(rawValue: defaults.string(forKey: "moveSound") ?? "") ?? .pop
    }

    func play() {
        NSSound(named: NSSound.Name(rawValue))?.play()
    }
}

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
    @Published var botID = BotLibrary.emil.id
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
    private var botRequestID = UUID()
    private var trainingPosition: Position?
    var isTraining: Bool { trainingPosition != nil }
    private var moves: [PGNMove] = []
    private(set) var activeBot = BotLibrary.emil
    private var activeTimeControl: TimeControl = .unlimited
    private(set) var activePlayerColor: PieceColor = .white
    var currentPosition: Position { positions.last! }
    var statusText: String {
        if result != "*" { return ending }
        if isThinking { return "\(activeBot.name) denkt …" }
        return "\(currentPosition.turn == .white ? "Weiß" : "Schwarz") am Zug"
    }

    var botMessage: String {
        let adventurous = ["milo", "finn", "anna", "bruno", "clara"].contains(activeBot.id)
        if result == "1/2-1/2" {
            return adventurous ? "Remis! Nächstes Mal suche ich wieder den Angriff. Noch eine Runde?" : "Remis! Ein guter Moment, unsere besten Ideen in Ruhe anzusehen."
        }
        if result != "*" {
            let won = result == (activePlayerColor == .white ? "1-0" : "0-1")
            if won {
                return adventurous ? "Du hast gewonnen! Ich komme mit neuen Ideen zurück. Revanche?" : "Du hast gewonnen – gut gespielt! Ich freue mich mit dir. Lust auf eine Revanche?"
            }
            return adventurous ? "Punkt für mich! Komm, wir schauen uns die entscheidende Stelle an. Dann greifst du wieder an." : "Diese Runde geht an mich. Kein Grund zur Eile – finden wir gemeinsam die Stelle, an der die Partie gekippt ist?"
        }
        if currentPosition.isInCheck(activePlayerColor) {
            return adventurous ? "Schach! Jetzt bist du dran: Wie bringst du deinen König in Sicherheit?" : "Schach! Schau in Ruhe, wie du deinen König schützen kannst."
        }
        if currentPosition.isInCheck(activePlayerColor == .white ? .black : .white) {
            return adventurous ? "Ein Schach gegen mich? Herausforderung angenommen!" : "Oh, Schach gegen mich! Da muss ich jetzt genau hinsehen."
        }
        if isThinking { return adventurous ? "Mal sehen, wo ich als Nächstes Druck machen kann …" : "Einen Moment, ich überlege ganz in Ruhe …" }
        if sans.count >= 16 {
            return adventurous ? "Neue Stellung, neue Chancen! Welche Drohung möchtest du aufstellen?" : "Schritt für Schritt. Welche deiner Figuren könnte noch besser stehen?"
        }
        if sans.count >= 4 {
            return adventurous ? "Jetzt wird es spannend. Dein Plan gegen meinen – los geht’s!" : "Ich bin gespannt auf deine Idee. Nimm dir Zeit und schau auch auf meine Drohungen."
        }
        switch activeBot.id {
        case "pippa": return "Ich beginne gerade mit Schach. Lass uns eine entspannte Partie spielen."
        case "lumi": return "Nur keine Eile. Wir haben Zeit für einen gemütlichen Zug."
        case "milo": return "Bereit? Ich probiere heute ein paar neue Ideen aus."
        case "ida": return "Ich versuche, meine Figuren gut aufzustellen. Was ist dein Plan?"
        case "emil": return "Schön, dass du da bist! Bei mir darfst du in Ruhe ausprobieren."
        case "olli": return "Eine neue Partie, ein neues Abenteuer. Ich bin dabei!"
        case "nelli": return "Ich übe, auf ungedeckte Figuren zu achten. Spielen wir los."
        case "anton": return "Lass uns ein paar Ideen aufs Brett bringen. Vielleicht entdecke ich einen Trick."
        case "finn": return "Mal sehen, wer heute die schlauere Idee hat."
        case "rudi": return "Ich habe schon eine Idee. Ob sie gut ist, finden wir gemeinsam heraus."
        case "anna": return "Augen auf! Ich halte nach einem Angriff Ausschau."
        case "viktor": return "Schritt für Schritt. Eine gute Stellung wächst mit jedem Zug."
        case "bruno": return "Ich bin startklar. Dein Zug – zeig mir deinen Plan!"
        case "clara": return "Willkommen am Brett. Heute achten wir auf die kleinen Details."
        default: return "Bereit für eine Herausforderung? Das Brett gehört deinen Ideen."
        }
    }

    func rematch(context: NSManagedObjectContext) {
        botID = activeBot.id
        playerColor = activePlayerColor
        timeControl = activeTimeControl
        skillLevel = activeBot.skillLevel
        if let trainingPosition {
            startTraining(position: trainingPosition, playerColor: activePlayerColor, botID: activeBot.id, context: context)
        } else { newGame(context: context) }
    }

    init() { reset() }

    private func reset() {
        positions = [trainingPosition ?? PGNGame().initialPosition]
        sans = []; moves = []; legalTargets = []
        selectedSquare = nil; lastMove = nil; pendingPromotion = nil
        result = "*"; ending = ""; errorMessage = nil; savedGame = nil
        gameID = UUID(); isThinking = false
        if botID == "stockfish_custom" {
            activeBot = Bot(id: botID, name: "Stockfish (Stufe \(skillLevel))", description: "", elo: 2500,
                            skillLevel: skillLevel, randomness: 0, movetimeMs: 1000)
        } else { activeBot = BotLibrary.bot(forId: botID) ?? BotLibrary.emil }
        activeTimeControl = timeControl; activePlayerColor = playerColor
        orientation = playerColor
        whiteTime = timeControl.initialSeconds; blackTime = timeControl.initialSeconds
        lastTick = nil
    }

    func newGame(context: NSManagedObjectContext) {
        stop()
        trainingPosition = nil
        reset()
        resume(context: context)
    }

    func startTraining(position: Position, playerColor: PieceColor, botID: String, context: NSManagedObjectContext) {
        stop()
        trainingPosition = position
        self.playerColor = playerColor
        self.botID = botID
        timeControl = .unlimited
        reset()
        resume(context: context)
    }

    func resume(context: NSManagedObjectContext) {
        guard result == "*", engine == nil else { return }
        checkOutcome(context: context)
        guard result == "*" else { return }
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
        botRequestID = UUID()
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
        guard result == "*", engine != nil, !isThinking, currentPosition.turn == activePlayerColor,
              let (from, to) = pendingPromotion else { return }
        pendingPromotion = nil
        tick(context: context)
        guard result == "*", let move = currentPosition.move(from: from, to: to, promotion: type) else { return }
        apply(move, context: context); requestBot(context: context)
    }

    func cancelPromotion() { pendingPromotion = nil }

    private func apply(_ move: Move, context: NSManagedObjectContext) {
        let position = currentPosition
        MoveSound.selected(enabled: AppSettings.fetchOrCreate(context: context).soundEnabled)?.play()
        let san = SAN.notation(for: move, in: position)
        moves.append(PGNMove(move: move, san: san)); sans.append(san)
        if position.turn == .white, let time = whiteTime { whiteTime = time + activeTimeControl.incrementSeconds }
        if position.turn == .black, let time = blackTime { blackTime = time + activeTimeControl.incrementSeconds }
        positions.append(position.make(move)); lastMove = move
        selectedSquare = nil; legalTargets = []
        checkOutcome(context: context)
    }

    private func checkOutcome(context: NSManagedObjectContext) {
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
        let requestID = UUID()
        botRequestID = requestID
        let bot = activeBot
        let fen = currentPosition.fen
        isThinking = true
        moveTask = Task {
            do {
                guard !Task.isCancelled, botRequestID == requestID else { return }
                try await engine.start()
                let uci = try await bot.chooseMove(fen: fen, engine: engine)
                guard !Task.isCancelled, gameID == expectedGame, botRequestID == requestID,
                      currentPosition.fen == fen, result == "*" else { return }
                tick(context: context)
                guard result == "*" else { return }
                guard let move = currentPosition.legalMoves().first(where: { $0.uci == uci }) else {
                    throw EngineError.unexpectedResponse(uci)
                }
                isThinking = false
                apply(move, context: context)
            } catch {
                guard !Task.isCancelled, gameID == expectedGame, botRequestID == requestID else { return }
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

    func exportPGN() -> String {
        PGN.export(PGNGame(headers: [
            "White": activePlayerColor == .white ? "Du" : activeBot.name,
            "Black": activePlayerColor == .black ? "Du" : activeBot.name,
            "Result": result, "Event": isTraining ? "Stellungstraining" : "Freundschaftspartie"
        ], moves: moves, result: result, initialPosition: positions[0]))
    }

    func save(context: NSManagedObjectContext) {
        guard !isTraining, result != "*", savedGame == nil else { return }
        let game = SavedGame(context: context)
        game.whitePlayer = activePlayerColor == .white ? "Du" : activeBot.name
        game.blackPlayer = activePlayerColor == .black ? "Du" : activeBot.name
        game.openingName = (try? OpeningBook())?.match(sanMoves: sans)?.name
        game.result = result; game.timeControl = activeTimeControl.rawValue
        game.pgn = exportPGN()
        do { try context.save(); savedGame = game }
        catch { context.delete(game); errorMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)" }
    }
}
