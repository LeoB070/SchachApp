import Foundation
import ChessAppKit

struct OpeningLine: Codable, Identifiable {
    let id: UUID
    let name: String
    let pgn: String
    let colorName: String
    var dueAt: Date
    var stage: Int

    var color: PieceColor { colorName == "black" ? .black : .white }
    var signature: String {
        guard let game = try? PGN.parse(pgn) else { return "" }
        return colorName + "|" + game.initialPosition.repetitionKey + "|" + game.moveList.map(\.uci).joined(separator: " ")
    }

    init(name: String, pgn: String, color: PieceColor, now: Date = Date()) throws {
        let games = try PGN.parseMany(pgn)
        guard games.count == 1, let game = games.first,
              game.positions.dropLast().contains(where: { $0.turn == color }) else {
            throw OpeningTrainingError.message("Bitte genau eine PGN-Hauptvariante mit mindestens einem eigenen Zug eingeben.")
        }
        self.id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Meine Variante" : name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.pgn = PGN.export(game)
        self.colorName = color == .white ? "white" : "black"
        self.dueAt = now
        self.stage = 0
    }

    mutating func record(success: Bool, now: Date = Date()) {
        guard !success || dueAt <= now else { return }
        let days = [1, 3, 7, 14, 30]
        stage = success ? min(stage + 1, days.count) : 0
        dueAt = now.addingTimeInterval(Double(days[max(0, stage - 1)]) * 86400)
    }
}

enum OpeningTrainingError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}

struct OpeningRepertoireStore {
    var url: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ChessApp/opening-repertoire.json")

    func load() throws -> [OpeningLine] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let lines = try JSONDecoder().decode([OpeningLine].self, from: Data(contentsOf: url))
        guard Set(lines.map(\.id)).count == lines.count else { throw OpeningTrainingError.message("Die gespeicherten Varianten enthalten doppelte Kennungen.") }
        for line in lines {
            guard ["white", "black"].contains(line.colorName), (0...5).contains(line.stage), line.dueAt.timeIntervalSince1970.isFinite else {
                throw OpeningTrainingError.message("Die gespeicherten Trainingsdaten sind ungültig.")
            }
            _ = try OpeningPractice(line: line)
        }
        return lines
    }

    func save(_ lines: [OpeningLine]) throws {
        // A damaged existing file must stay recoverable instead of being replaced by an empty session.
        _ = try load()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(lines).write(to: url, options: .atomic)
    }
}

struct OpeningPractice {
    let lineID: UUID
    let color: PieceColor
    let game: PGNGame
    private(set) var position: Position
    private(set) var ply = 0
    private(set) var hadError = false
    private(set) var usedHint = false
    private(set) var feedback = "Finde deinen Repertoirezug."
    private(set) var lastMove: Move?
    var complete: Bool { ply == game.moves.count }
    var expected: Move? { complete ? nil : game.moves[ply].move }

    init(line: OpeningLine) throws {
        let parsed = try PGN.parse(line.pgn)
        guard parsed.positions.dropLast().contains(where: { $0.turn == line.color }) else {
            throw OpeningTrainingError.message("Diese Variante enthält keinen Zug für deine Trainingsfarbe.")
        }
        lineID = line.id; color = line.color; game = parsed; position = parsed.initialPosition
        advanceOpponent()
    }

    @discardableResult mutating func attempt(_ move: Move) -> Bool {
        guard !complete, position.turn == color, position.legalMoves().contains(move) else { return false }
        guard move == expected else {
            hadError = true
            feedback = "Legal, aber nicht dein gespeicherter Repertoirezug. Versuche es erneut."
            return false
        }
        position = position.make(move); lastMove = move; ply += 1
        advanceOpponent()
        feedback = complete ? "Variante geschafft. Deine Wiederholung wird eingeplant." : "Richtig. Finde deinen nächsten Repertoirezug."
        return true
    }

    mutating func hint() {
        guard let expected else { return }
        usedHint = true
        feedback = "Dein gespeicherter Zug: " + SAN.notation(for: expected, in: position)
    }

    private mutating func advanceOpponent() {
        while !complete && position.turn != color {
            let move = game.moves[ply].move
            position = position.make(move); lastMove = move; ply += 1
        }
    }
}

struct OpeningGameRecord {
    let id: UUID
    let white: String
    let black: String
    let result: String
    let pgn: String
    var ownColor: PieceColor? {
        guard (white == "Du") != (black == "Du") else { return nil }
        return white == "Du" ? .white : .black
    }
}

struct OpeningExplorerRow: Identifiable {
    let id: String
    let san: String
    let move: Move
    var wins = 0
    var draws = 0
    var losses = 0
    var unfinished = 0
    var examples: [OpeningGameRecord] = []
    var count: Int { wins + draws + losses + unfinished }
}

enum OpeningExplorer {
    static func positionKey(_ position: Position) -> String {
        var parts = position.fen.split(separator: " ").prefix(4).map(String.init)
        if position.enPassant != nil && !position.legalMoves().contains(where: { $0.flags.contains(.enPassant) }) { parts[3] = "-" }
        return parts.joined(separator: " ")
    }

    static func rows(records: [OpeningGameRecord], at position: Position, ownColor: PieceColor) -> [OpeningExplorerRow] {
        var rows: [String: OpeningExplorerRow] = [:]
        let targetKey = positionKey(position)
        for record in records where record.ownColor == ownColor {
            guard let game = try? PGN.parse(record.pgn) else { continue }
            var current = game.initialPosition
            var counted = Set<String>()
            for item in game.moves {
                if positionKey(current) == targetKey && counted.insert(item.move.uci).inserted {
                    var row = rows[item.move.uci] ?? OpeningExplorerRow(id: item.move.uci, san: item.san, move: item.move)
                    if record.result == (ownColor == .white ? "1-0" : "0-1") { row.wins += 1 }
                    else if record.result == "1/2-1/2" { row.draws += 1 }
                    else if ["1-0", "0-1"].contains(record.result) { row.losses += 1 }
                    else { row.unfinished += 1 }
                    row.examples.append(record)
                    rows[item.move.uci] = row
                }
                current = current.make(item.move)
            }
        }
        return rows.values.sorted { $0.count == $1.count ? $0.san < $1.san : $0.count > $1.count }
    }
}
