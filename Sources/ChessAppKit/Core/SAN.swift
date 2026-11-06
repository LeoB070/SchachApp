import Foundation

/// SAN-Notation (Standard-Chess-Notation mit "+" / "#").
public enum SAN {
    /// Notation eines Zuges in der Stellung, inklusive Rochade, Bauernregeln,
    /// Umwandlung, Eindeutig-Machung (Datei → Reihe → beides) und Schach/Matt-Zeichen.
    public static func notation(for move: Move, in position: Position) -> String {
        var text: String
        if move.flags.contains(.castleKing) {
            text = "O-O"
        } else if move.flags.contains(.castleQueen) {
            text = "O-O-O"
        } else {
            guard let piece = position.board[move.from.index] else { return "???" }
            let isCapture = move.flags.contains(.capture)
            if piece.type == .pawn {
                text = isCapture ? String(move.from.name.first!) + "x" + move.to.name : move.to.name
                if let promotion = move.promotion {
                    text += "=" + String(promotion.uciLetter).uppercased()
                }
            } else {
                let letter = String(piece.type.uciLetter).uppercased()   // Springer = "N"
                text = letter + disambiguation(for: move, piece: piece, in: position)
                    + (isCapture ? "x" : "") + move.to.name
            }
        }
        // Schach/Matt aus der Folgestellung ermitteln (dort ist die Gegenseite am Zug).
        let after = position.make(move)
        if after.isCheckmate {
            text += "#"
        } else if after.isInCheck(after.turn) {
            text += "+"
        }
        return text
    }

    /// Figur vorher eindeutig machen, wenn dieselbe Art denselben Zielfeld-Zug noch kann.
    private static func disambiguation(for move: Move, piece: Piece, in position: Position) -> String {
        let rivals = position.legalMoves().filter { candidate in
            candidate.to == move.to && candidate.from != move.from
                && position.board[candidate.from.index] == Piece(color: piece.color, type: piece.type)
        }
        guard !rivals.isEmpty else { return "" }
        let fileCollides = rivals.contains { $0.from.file == move.from.file }
        let rankCollides = rivals.contains { $0.from.rank == move.from.rank }
        if !fileCollides { return String(move.from.name.first!) }   // Buchstabe genügt
        if !rankCollides { return String(move.from.rank + 1) }      // Zahl genügt
        return move.from.name                                       // beides nötig
    }

    /// Zug aus SAN: kompakte SAN aller legalen Züge mit der bereinigten Eingabe vergleichen.
    public static func move(from san: String, in position: Position) -> Move? {
        var cleaned = san.trimmingCharacters(in: .whitespaces)
        cleaned.removeAll { "+#!?".contains($0) }
        // 0-0-Varianten der Rochade normieren.
        if cleaned.hasPrefix("0-0-0") {
            cleaned = "O-O-O"
        } else if cleaned.hasPrefix("0-0") {
            cleaned = "O-O"
        }
        for candidate in position.legalMoves() {
            let compact = notation(for: candidate, in: position).filter { !"+#!?".contains($0) }
            if compact == cleaned {
                return candidate
            }
        }
        return nil
    }
}
