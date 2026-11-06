import Foundation

/// Rochaderechte; rawValue = FEN-Buchstabe.
public enum CastlingRight: String, CaseIterable {
    case whiteKing = "K"
    case whiteQueen = "Q"
    case blackKing = "k"
    case blackQueen = "q"
}

/// Eine Schachstellung. Brett als 64 Einträge, index = rank*8+file (a1 = 0, h8 = 63).
public struct Position: Equatable {
    public var board: [Piece?]
    public var turn: Color
    public var castling: Set<CastlingRight>
    public var enPassant: Square?
    public var halfmoveClock: Int
    public var fullmoveNumber: Int

    public init(board: [Piece?], turn: Color, castling: Set<CastlingRight>,
                enPassant: Square? = nil, halfmoveClock: Int = 0, fullmoveNumber: Int = 1) {
        self.board = board
        self.turn = turn
        self.castling = castling
        self.enPassant = enPassant
        self.halfmoveClock = halfmoveClock
        self.fullmoveNumber = fullmoveNumber
    }

    /// Zug anwenden; die Stellung selbst bleibt unverändert, zurück kommt die Folgestellung.
    public func make(_ move: Move) -> Position {
        var next = self
        guard let piece = board[move.from.index] else { return next }

        // Zug wegnehmen, EP-Feld der alten Stellung wird hinfällig.
        next.enPassant = nil
        next.board[move.from.index] = nil

        // Passantenschlag: geschlagener Bauer steht hinter dem Zielfeld.
        if move.flags.contains(.enPassant) {
            let capturedRank = move.to.rank + (piece.color == .white ? -1 : 1)
            next.board[Square(file: move.to.file, rank: capturedRank).index] = nil
        }

        // Zielfeld setzen (evtl. mit Umwandlung).
        if let promotion = move.promotion {
            next.board[move.to.index] = Piece(color: piece.color, type: promotion)
        } else {
            next.board[move.to.index] = piece
        }

        // Rochade: Turm bewegen (Damenflügel a→d, Königsflügel h→f).
        if move.flags.contains(.castleQueen) {
            let rookFrom = Square(file: move.to.file - 2, rank: move.to.rank)
            let rookTo = Square(file: move.to.file + 1, rank: move.to.rank)
            next.board[rookTo.index] = next.board[rookFrom.index]
            next.board[rookFrom.index] = nil
        }
        if move.flags.contains(.castleKing) {
            let rookFrom = Square(file: move.to.file + 1, rank: move.to.rank)
            let rookTo = Square(file: move.to.file - 1, rank: move.to.rank)
            next.board[rookTo.index] = next.board[rookFrom.index]
            next.board[rookFrom.index] = nil
        }

        // Doppelzug: En-passant-Feld hinter dem Bauern.
        if move.flags.contains(.doublePush) {
            next.enPassant = Square(file: move.from.file, rank: (move.from.rank + move.to.rank) / 2)
        }

        // Rochaderechte pflegen: König zieht → beide Rechte seiner Farbe weg;
        // Zug von oder auf eine Turmecke → die dort hängende Sicherheit Recht weg.
        if piece.type == .king {
            next.castling.subtract(piece.color == .white ? [.whiteKing, .whiteQueen] : [.blackKing, .blackQueen])
        }
        next.castling.subtract(Position.castlingRights(connectedTo: move.from))
        next.castling.subtract(Position.castlingRights(connectedTo: move.to))

        // Zähler und Seitenwechsel; Zugnummer hochstellen, wenn Schwarz gezogen hat.
        if next.turn == .black {
            next.fullmoveNumber += 1
        }
        next.turn = next.turn.flipped
        next.halfmoveClock = (piece.type == .pawn || move.flags.contains(.capture))
            ? 0 : next.halfmoveClock + 1
        return next
    }

    /// Rochaderechte, die an einer Turmecke hängen (Zug von/dort == Rechte weg).
    private static func castlingRights(connectedTo square: Square) -> Set<CastlingRight> {
        switch (square.file, square.rank) {
        case (0, 0): return [.whiteQueen]
        case (7, 0): return [.whiteKing]
        case (0, 7): return [.blackQueen]
        case (7, 7): return [.blackKing]
        default: return []
        }
    }

    /// Alle legalen Züge: pseudo-legale Züge, bei denen der eigene König danach nicht im Schach steht.
    public func legalMoves() -> [Move] {
        MoveGenerator.moves(for: self).filter { !self.make($0).isInCheck(turn) }
    }

    /// Steht die angegebene Farbe im Schach?
    public func isInCheck(_ color: Color) -> Bool {
        guard let kingIndex = board.firstIndex(where: { $0 == Piece(color: color, type: .king) }) else {
            return false
        }
        return MoveGenerator.isAttacked(Square(index: kingIndex), by: color.flipped, in: self)
    }

    /// Matt: eigene Farbe steht im Schach und hat keinen legalen Zug.
    public var isCheckmate: Bool {
        isInCheck(turn) && legalMoves().isEmpty
    }

    /// Patt: kein legaler Zug, aber kein Schach.
    public var isStalemate: Bool {
        !isInCheck(turn) && legalMoves().isEmpty
    }

    /// Offizielle Materialregeln: K–K; K + genau eine Kleinefigur – K;
    /// oder beidseits nur Läufer (keine Springer), alle auf der gleichen Feldfarbe.
    public func hasInsufficientMaterial() -> Bool {
        var whiteMinors: [PieceType] = []
        var blackMinors: [PieceType] = []
        for index in board.indices {
            guard let piece = board[index], piece.type != .king else { continue }
            switch piece.type {
            case .bishop, .knight:
                if piece.color == .white { whiteMinors.append(piece.type) } else { blackMinors.append(piece.type) }
            default:
                return false   // Bauer, Turm oder Dame = genug Material für Gewinnversuche
            }
        }
        let total = whiteMinors.count + blackMinors.count
        if total == 0 || total == 1 { return true }
        // Nur-Läufer-Endspiel: alle Läufer auf gleicher Feldfarbe ⇒ alles ungenügend.
        let onlyBishops = whiteMinors.allSatisfy { $0 == .bishop } && blackMinors.allSatisfy { $0 == .bishop }
        guard onlyBishops else { return false }
        var observedColor: Bool? = nil
        for index in board.indices {
            guard let piece = board[index], piece.type == .bishop else { continue }
            let isLight = Square(index: index).isLight
            if let knownColor = observedColor {
                if knownColor != isLight { return false }
            } else {
                observedColor = isLight
            }
        }
        return true
    }

    /// Wiederholungs-Schlüssel: die ersten vier FEN-Felder (Stellung, SeitenamZug, Rechte, EP-Feld).
    public var repetitionKey: String {
        fen.split(separator: " ").prefix(4).joined(separator: " ")
    }
}
