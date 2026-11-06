import Foundation

/// Fehler beim Einlesen einer FEN-Zeile.
public enum FenError: Error {
    case invalid
}

extension Position {
    /// Aus FEN-Zeile. Wirft FenError.invalid bei strukturell kaputtem Format.
    public init(fen: String) throws {
        let fields = fen.split(separator: " ", omittingEmptySubsequences: true)
        guard fields.count >= 2 else { throw FenError.invalid }

        // Feld 1: Stellung. Reihe "8" zuerst; Zahlen = nacheinander Leerfelder.
        let rows = fields[0].split(separator: "/")
        guard rows.count == 8 else { throw FenError.invalid }
        var board = Array<Piece?>(repeating: nil, count: 64)
        for (rowIndex, row) in rows.enumerated() {
            var file = 0
            for character in row {
                if let emptyCount = character.wholeNumberValue {
                    guard emptyCount > 0, file + emptyCount <= 8 else { throw FenError.invalid }
                    file += emptyCount
                } else {
                    guard let piece = Piece(fenChar: character), file < 8 else { throw FenError.invalid }
                    board[(7 - rowIndex) * 8 + file] = piece
                    file += 1
                }
            }
            guard file == 8 else { throw FenError.invalid }
        }
        self.board = board

        // Feld 2: Seitenam Zug.
        guard fields[1] == "w" || fields[1] == "b" else { throw FenError.invalid }
        self.turn = fields[1] == "w" ? .white : .black

        // Feld 3: Rochaderechte ("-" oder Teilmenge aus KQkq).
        var rights = Set<CastlingRight>()
        if fields.count > 2, fields[2] != "-" {
            for character in fields[2] {
                guard let right = CastlingRight(rawValue: String(character)) else { throw FenError.invalid }
                rights.insert(right)
            }
        }
        self.castling = rights

        // Feld 4: En-passant-Feld (auch wenn kein Spieler damit schlagen kann, wird es übernommen).
        self.enPassant = nil
        if fields.count > 3, fields[3] != "-" {
            guard let square = Square(string: String(fields[3])) else { throw FenError.invalid }
            self.enPassant = square
        }

        // Felder 5/6: Halbzüge ohne Schlagen/Bauernzug; Zugnummer.
        guard let halfmoves = fields.count > 4 ? Int(fields[4]) : 0,
              let fullmoves = fields.count > 5 ? Int(fields[5]) : 1,
              (0...1_000_000).contains(halfmoves), (1...1_000_000).contains(fullmoves)
        else { throw FenError.invalid }
        // Begrenzt importierte Zähler vor der Weitergabe an Engine und Zugarithmetik.
        self.halfmoveClock = halfmoves
        self.fullmoveNumber = fullmoves
    }

    /// Stellung als FEN-Zeile.
    public var fen: String {
        var rows: [String] = []
        for rank in stride(from: 7, through: 0, by: -1) {
            var row = ""
            var empties = 0
            for file in 0..<8 {
                if let piece = board[rank * 8 + file] {
                    if empties > 0 {
                        row += String(empties)
                        empties = 0
                    }
                    row.append(piece.fenChar)
                } else {
                    empties += 1
                }
            }
            if empties > 0 {
                row += String(empties)
            }
            rows.append(row)
        }
        let side = turn == .white ? "w" : "b"
        let rights = CastlingRight.allCases
            .filter { castling.contains($0) }
            .map(\.rawValue)
            .joined()
        return "\(rows.joined(separator: "/")) \(side) \(rights.isEmpty ? "-" : rights) \(enPassant?.name ?? "-") \(halfmoveClock) \(fullmoveNumber)"
    }
}
