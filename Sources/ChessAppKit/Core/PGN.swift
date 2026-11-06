import Foundation

/// Ein einzelner Zug in einer PGN-Partie inklusive SAN-Text, optionalem Kommentar und NAGs.
public struct PGNMove: Equatable {
    public var move: Move
    public var san: String
    public var comment: String?
    public var nags: [String]

    public init(move: Move, san: String, comment: String? = nil, nags: [String] = []) {
        self.move = move
        self.san = san
        self.comment = comment
        self.nags = nags
    }
}

/// Eine vollständig geparste PGN-Partie mit Kopfdaten (Tags), Zügen und Ergebnis.
public struct PGNGame: Equatable {
    public var headers: [String: String]
    public var moves: [PGNMove]
    public var result: String
    public var initialPosition: Position

    public init(
        headers: [String: String] = [:],
        moves: [PGNMove] = [],
        result: String = "*",
        initialPosition: Position = (try? Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"))!
    ) {
        self.headers = headers
        self.moves = moves
        self.result = result
        self.initialPosition = initialPosition
    }

    /// Case-insensitiver Zugriff auf Header-Tags.
    public func tag(_ name: String) -> String? {
        if let val = headers[name] { return val }
        let lower = name.lowercased()
        for (k, v) in headers {
            if k.lowercased() == lower { return v }
        }
        return nil
    }

    /// Liste aller Züge als `Move`.
    public var moveList: [Move] {
        moves.map(\.move)
    }

    /// Liste aller Züge als SAN-Strings.
    public var sanList: [String] {
        moves.map(\.san)
    }

    /// Berechnet alle Stellungen der Partie von der Startstellung bis zum Endstand.
    public var positions: [Position] {
        var result = [initialPosition]
        var current = initialPosition
        for m in moves {
            current = current.make(m.move)
            result.append(current)
        }
        return result
    }
}

/// Fehler beim Parsen einer PGN-Partie.
public enum PGNError: Error, Equatable {
    case invalidFEN(String)
    case unreadableMove(String, fen: String)
    case emptyInput
}

/// PGN-Import/Export für die Hauptvariante.
// TODO(CLAUDE): Seltene PGN-Dialekte und mehrere headerlose Partien unterstützen.
public enum PGN {
    private static let standardFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    // MARK: - Parsing API

    /// Parst die erste Partie aus einem PGN-String.
    public static func parse(_ text: String) throws -> PGNGame {
        let games = try parseMany(text)
        guard let first = games.first else {
            throw PGNError.emptyInput
        }
        return first
    }

    /// Parst alle Partien aus einem PGN-String.
    public static func parseMany(_ text: String) throws -> [PGNGame] {
        try splitGames(text).map { try parseSingleGame($0) }
    }

    /// Gibt nur vollständig lesbare Partien zurück; kaputte Partien werden ausgelassen.
    public static func parseTolerant(_ text: String) -> [PGNGame] {
        splitGames(text).compactMap { try? parseSingleGame($0) }
    }

    // MARK: - Export API

    /// Exportiert eine Partie in saubere PGN-Notation mit optionalem Zeilenumbruch (Standard 80 Zeichen).
    public static func export(_ game: PGNGame, wrapWidth: Int? = 80) -> String {
        var lines: [String] = []

        // 1. Seven Tag Roster nach PGN-Standard
        let roster = ["Event", "Site", "Date", "Round", "White", "Black", "Result"]
        var writtenTags = Set<String>()

        for key in roster {
            let val = game.tag(key) ?? (key == "Result" ? game.result : "?")
            lines.append("[\(key) \"\(escapeHeader(val))\"]")
            writtenTags.insert(key.lowercased())
        }

        // FEN und SetUp falls nicht die Standard-Startstellung
        if let fen = game.tag("FEN"), !fen.isEmpty {
            if !writtenTags.contains("setup") {
                lines.append("[SetUp \"1\"]")
                writtenTags.insert("setup")
            }
            lines.append("[FEN \"\(escapeHeader(fen))\"]")
            writtenTags.insert("fen")
        } else if game.initialPosition.fen != standardFEN {
            if !writtenTags.contains("setup") {
                lines.append("[SetUp \"1\"]")
                writtenTags.insert("setup")
            }
            lines.append("[FEN \"\(escapeHeader(game.initialPosition.fen))\"]")
            writtenTags.insert("fen")
        }

        // Weitere Header alphabetisch sortiert
        let remainingKeys = game.headers.keys
            .filter { !writtenTags.contains($0.lowercased()) }
            .sorted()
        for key in remainingKeys {
            if let val = game.headers[key] {
                lines.append("[\(key) \"\(escapeHeader(val))\"]")
            }
        }

        lines.append("") // Leerzeile zwischen Header und Zügen

        // 2. Zugliste formatieren
        var moveTokens: [String] = []
        var pos = game.initialPosition
        var nextMoveNumber = pos.fullmoveNumber
        var isWhiteTurn = (pos.turn == .white)

        if !isWhiteTurn && !game.moves.isEmpty {
            // Wenn Schwarz beginnt (aus benutzerdefiniertem FEN)
            let firstMove = game.moves[0]
            var token = "\(nextMoveNumber)...\(firstMove.san)"
            if let comment = firstMove.comment, !comment.isEmpty {
                token += " {\(comment)}"
            }
            moveTokens.append(token)
            pos = pos.make(firstMove.move)
            nextMoveNumber += 1
            isWhiteTurn = true

            for m in game.moves.dropFirst() {
                appendMove(m, pos: &pos, nextMoveNumber: &nextMoveNumber, isWhiteTurn: &isWhiteTurn, into: &moveTokens)
            }
        } else {
            for m in game.moves {
                appendMove(m, pos: &pos, nextMoveNumber: &nextMoveNumber, isWhiteTurn: &isWhiteTurn, into: &moveTokens)
            }
        }

        // Ergebnis am Ende anhängen
        moveTokens.append(game.result.isEmpty ? "*" : game.result)

        // 3. Zeilenumbruch (optional bei wrapWidth)
        let formattedMoves: String
        if let limit = wrapWidth, limit > 0 {
            var currentLine = ""
            var moveLines: [String] = []
            for token in moveTokens {
                if currentLine.isEmpty {
                    currentLine = token
                } else if currentLine.count + 1 + token.count <= limit {
                    currentLine += " " + token
                } else {
                    moveLines.append(currentLine)
                    currentLine = token
                }
            }
            if !currentLine.isEmpty {
                moveLines.append(currentLine)
            }
            formattedMoves = moveLines.joined(separator: "\n")
        } else {
            formattedMoves = moveTokens.joined(separator: " ")
        }

        lines.append(formattedMoves)
        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// Exportiert mehrere Partien hintereinander.
    public static func exportMany(_ games: [PGNGame], wrapWidth: Int? = 80) -> String {
        games.map { export($0, wrapWidth: wrapWidth) }.joined(separator: "\n")
    }

    // MARK: - Private Parser Hilfsfunktionen

    private static func escapeHeader(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func appendMove(
        _ pgnMove: PGNMove,
        pos: inout Position,
        nextMoveNumber: inout Int,
        isWhiteTurn: inout Bool,
        into tokens: inout [String]
    ) {
        var token = ""
        if isWhiteTurn {
            token = "\(nextMoveNumber). \(pgnMove.san)"
            isWhiteTurn = false
        } else {
            token = pgnMove.san
            isWhiteTurn = true
            nextMoveNumber += 1
        }
        for nag in pgnMove.nags {
            token += " " + nag
        }
        if let comment = pgnMove.comment, !comment.isEmpty {
            token += " {\(comment)}"
        }
        tokens.append(token)
        pos = pos.make(pgnMove.move)
    }

    /// Teilt einen Text mit mehreren PGN-Partien in einzelne Partietexte auf.
    private static func splitGames(_ text: String) -> [String] {
        var games: [String] = []
        let lines = text.components(separatedBy: .newlines)
        var currentChunk: [String] = []
        var inHeaders = false
        var hasSeenMoves = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isHeader = trimmed.hasPrefix("[") && trimmed.hasSuffix("]")

            if isHeader {
                // Wenn wir zuvor schon Züge gesehen haben, beginnt hier eine neue Partie
                if hasSeenMoves {
                    let chunk = currentChunk.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !chunk.isEmpty {
                        games.append(chunk)
                    }
                    currentChunk = []
                    hasSeenMoves = false
                }
                inHeaders = true
                currentChunk.append(line)
            } else {
                if !trimmed.isEmpty {
                    if inHeaders {
                        inHeaders = false
                    }
                    hasSeenMoves = true
                }
                currentChunk.append(line)
            }
        }

        let chunk = currentChunk.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !chunk.isEmpty {
            games.append(chunk)
        }

        return games
    }

    /// Parst eine einzelne Partie (Headers + Movetext).
    private static func parseSingleGame(_ text: String) throws -> PGNGame {
        var headers: [String: String] = [:]
        var moveText = ""

        // Header vs. Movetext trennen
        let lines = text.components(separatedBy: .newlines)
        var readingHeaders = true

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if readingHeaders {
                if trimmed.hasPrefix("[") && trimmed.contains("\"") {
                    if let (key, value) = parseHeaderLine(trimmed) {
                        headers[key] = value
                    }
                } else if trimmed.isEmpty {
                    // Leere Zeile nach Headern beendet den Header-Bereich
                    if !headers.isEmpty {
                        readingHeaders = false
                    }
                } else {
                    // Erste Nicht-Header-Zeile
                    readingHeaders = false
                    moveText.append("\n" + line)
                }
            } else {
                moveText.append("\n" + line)
            }
        }

        // Startstellung ermitteln
        var initialPos: Position
        if let fenTag = headers["FEN"] ?? headers["fen"], !fenTag.isEmpty {
            if let customPos = try? Position(fen: fenTag) {
                initialPos = customPos
            } else {
                throw PGNError.invalidFEN(fenTag)
            }
        } else {
            initialPos = (try? Position(fen: standardFEN))!
        }

        // Züge parsen
        let (parsedMoves, detectedResult) = try parseMoveText(moveText, startPosition: initialPos)

        let finalResult = headers["Result"] ?? detectedResult ?? "*"

        return PGNGame(
            headers: headers,
            moves: parsedMoves,
            result: finalResult,
            initialPosition: initialPos
        )
    }

    /// Parst eine Tag-Zeile wie `[Event "World Championship"]`.
    private static func parseHeaderLine(_ line: String) -> (String, String)? {
        guard line.hasPrefix("[") && line.hasSuffix("]") else { return nil }
        let inner = line.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
        guard let quoteStart = inner.firstIndex(of: "\""),
              let quoteEnd = inner.lastIndex(of: "\""),
              quoteStart != quoteEnd else { return nil }

        let key = String(inner[..<quoteStart]).trimmingCharacters(in: .whitespaces)
        let rawVal = String(inner[inner.index(after: quoteStart)..<quoteEnd])
        let value = rawVal.replacingOccurrences(of: "\\\"", with: "\"")
                          .replacingOccurrences(of: "\\\\", with: "\\")
        guard !key.isEmpty else { return nil }
        return (key, value)
    }

    /// Parst den gesamten Movetext unter Beachtung von Kommentaren, Varianten, NAGs und Zugnummern.
    private static func parseMoveText(_ rawText: String, startPosition: Position) throws -> ([PGNMove], String?) {
        var moves: [PGNMove] = []
        var currentPosition = startPosition
        var detectedResult: String?

        // 1. Zeichenweise Tokenisierung mit Kommentar- und Variantenfilterung
        let tokens = tokenizeMoveText(rawText)

        var pendingComment: String?
        var pendingNAGs: [String] = []

        for token in tokens {
            // Ist es ein Ergebnis?
            if isGameTermination(token) {
                detectedResult = token
                break
            }

            // Ist es ein Kommentar?
            if token.hasPrefix("{") && token.hasSuffix("}") {
                let commentContent = String(token.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                if !moves.isEmpty {
                    // Dem letzten Zug zuordnen
                    let lastIdx = moves.count - 1
                    if let existing = moves[lastIdx].comment {
                        moves[lastIdx].comment = existing + " " + commentContent
                    } else {
                        moves[lastIdx].comment = commentContent
                    }
                } else {
                    pendingComment = commentContent
                }
                continue
            }

            // Ist es ein NAG? ($1, $2, etc.)
            if token.hasPrefix("$") && token.count > 1 && token.dropFirst().allSatisfy(\.isNumber) {
                if !moves.isEmpty {
                    moves[moves.count - 1].nags.append(token)
                } else {
                    pendingNAGs.append(token)
                }
                continue
            }

            // Zugnummern entfernen: z. B. "1.", "1...", "12.", "12..."
            var sanCandidate = cleanMoveNumber(token)
            guard !sanCandidate.isEmpty else { continue }

            // Angehängte NAG-Symbole (!, ?, !?, ?!, etc.) abtrennen
            var attachedNAGs: [String] = []
            while sanCandidate.hasSuffix("!") || sanCandidate.hasSuffix("?") {
                let lastChar = sanCandidate.removeLast()
                attachedNAGs.insert(String(lastChar), at: 0)
            }
            if !attachedNAGs.isEmpty {
                let nagString = attachedNAGs.joined()
                pendingNAGs.append(nagString)
            }

            guard !sanCandidate.isEmpty, sanCandidate != "e.p." else { continue }

            // Versuche den Zug in currentPosition aufzulösen
            if let legalMove = resolveSAN(sanCandidate, in: currentPosition) {
                let pgnMove = PGNMove(
                    move: legalMove,
                    san: SAN.notation(for: legalMove, in: currentPosition),
                    comment: pendingComment,
                    nags: pendingNAGs
                )
                moves.append(pgnMove)
                currentPosition = currentPosition.make(legalMove)
                pendingComment = nil
                pendingNAGs = []
            } else {
                throw PGNError.unreadableMove(sanCandidate, fen: currentPosition.fen)
            }
        }

        return (moves, detectedResult)
    }

    /// Zerlegt den Movetext in Tokens; überspringt `;...`-Zeilenkommentare und `(...)`-Varianten.
    private static func tokenizeMoveText(_ text: String) -> [String] {
        var tokens: [String] = []
        var index = text.startIndex
        var variationDepth = 0

        while index < text.endIndex {
            let c = text[index]

            // Semicolon-Kommentar: bis zum Zeilenende überspringen
            if c == "}" { // Ungepaarte schließende Klammer: kein gültiges Zugtoken.
                index = text.index(after: index)
                continue
            }
            if c == ";" {
                while index < text.endIndex && text[index] != "\n" && text[index] != "\r" {
                    index = text.index(after: index)
                }
                continue
            }

            // Klammer-Variante
            if c == "(" {
                variationDepth += 1
                index = text.index(after: index)
                continue
            }
            if c == ")" {
                if variationDepth > 0 { variationDepth -= 1 }
                index = text.index(after: index)
                continue
            }

            // Wenn wir uns innerhalb einer Variante befinden, alles überspringen
            if variationDepth > 0 {
                // Aber Brace-Kommentare in Varianten beachten, damit Klammern darin nicht stören
                if c == "{" {
                    while index < text.endIndex && text[index] != "}" {
                        index = text.index(after: index)
                    }
                    if index < text.endIndex { index = text.index(after: index) }
                    continue
                }
                index = text.index(after: index)
                continue
            }

            // Whitespace überspringen
            if c.isWhitespace {
                index = text.index(after: index)
                continue
            }

            // Brace-Kommentar: `{ ... }` als eigenes Token
            if c == "{" {
                let start = index
                while index < text.endIndex && text[index] != "}" {
                    index = text.index(after: index)
                }
                if index < text.endIndex {
                    index = text.index(after: index)
                }
                let commentToken = String(text[start..<index])
                tokens.append(commentToken)
                continue
            }

            // Normales Wort/Token lesen
            let start = index
            while index < text.endIndex {
                let ch = text[index]
                if ch.isWhitespace || ch == "{" || ch == "(" || ch == ")" || ch == ";" {
                    break
                }
                index = text.index(after: index)
            }
            let word = String(text[start..<index])
            if !word.isEmpty {
                // Kann z. B. "1.e4" sein -> aufteilen in "1." und "e4"
                if let dotRange = word.range(of: ".") {
                    let prefix = String(word[...dotRange.lowerBound])
                    let suffix = String(word[word.index(after: dotRange.lowerBound)...]).trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    if !prefix.isEmpty && prefix.dropLast().allSatisfy(\.isNumber) {
                        tokens.append(prefix)
                        if !suffix.isEmpty {
                            tokens.append(suffix)
                        }
                    } else {
                        tokens.append(word)
                    }
                } else {
                    tokens.append(word)
                }
            }
        }

        return tokens
    }

    /// Entfernt führende Zugnummern wie "1.", "1...", "2."
    private static func cleanMoveNumber(_ token: String) -> String {
        var str = token
        // Wenn Token nur aus Ziffern und Punkten besteht (z. B. "1." oder "12..."):
        if str.allSatisfy({ $0.isNumber || $0 == "." }) {
            return ""
        }
        guard str.contains(".") else { return str }
        // Wenn führende Ziffern + Punkte vorhanden sind: "1.e4" -> "e4"
        while let first = str.first, first.isNumber {
            str.removeFirst()
        }
        while let first = str.first, first == "." {
            str.removeFirst()
        }
        return str
    }

    /// Prüft ob ein Token ein Spielende markiert.
    private static func isGameTermination(_ token: String) -> Bool {
        token == "1-0" || token == "0-1" || token == "1/2-1/2" || token == "*"
    }

    /// Robuste SAN-Auflösung mit Fallbacks für verschiedene Notationsdialekte.
    private static func resolveSAN(_ san: String, in position: Position) -> Move? {
        // Direkter Versuch über SAN.move
        if let move = SAN.move(from: san, in: position) {
            return move
        }

        var cleaned = san.trimmingCharacters(in: .whitespaces)
        cleaned.removeAll { "+#!?".contains($0) }

        // Rochade normalisieren
        if cleaned == "0-0" || cleaned == "o-o" || cleaned == "O-O" {
            cleaned = "O-O"
        } else if cleaned == "0-0-0" || cleaned == "o-o-o" || cleaned == "O-O-O" {
            cleaned = "O-O-O"
        }

        // Falls Umwandlung ohne "=" notiert ist, z. B. "e8Q" statt "e8=Q"
        if cleaned.count >= 3 && !cleaned.contains("=") {
            let lastChar = cleaned.last!
            if "QRBNqrbn".contains(lastChar) {
                var withEquals = cleaned
                withEquals.insert("=", at: withEquals.index(before: withEquals.endIndex))
                if let m = SAN.move(from: withEquals, in: position) {
                    return m
                }
            }
        }

        // Versuch mit UCI-Code (falls Züge in PGN als UCI stehen, z. B. "e2e4")
        if cleaned.count >= 4 {
            let legalMoves = position.legalMoves()
            if let direct = legalMoves.first(where: { $0.uci.lowercased() == cleaned.lowercased() }) {
                return direct
            }
        }

        // Fallback: Bauernschlag ohne "x", z. B. "ed4" -> "exd4"
        if cleaned.count == 3 {
            let first = cleaned.first!
            let second = cleaned[cleaned.index(after: cleaned.startIndex)]
            let third = cleaned.last!
            if ("a"..."h").contains(first) && ("a"..."h").contains(second) && ("1"..."8").contains(third) {
                let withX = "\(first)x\(second)\(third)"
                if let m = SAN.move(from: withX, in: position) {
                    return m
                }
            }
        }

        return nil
    }
}
