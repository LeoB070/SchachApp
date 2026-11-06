import Foundation

/// Zugzeugung und Feldangriff als interne Hilfsfunktionen der Stellung.
enum MoveGenerator {
    private static let knightOffsets = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
    private static let rookDirections = [(0, 1), (0, -1), (1, 0), (-1, 0)]
    private static let bishopDirections = [(1, 1), (1, -1), (-1, 1), (-1, -1)]

    /// Pseudo-legale Züge: alle plausiblen Züge der SeitenamZug, ohne Selbstschach-Filter.
    static func moves(for position: Position) -> [Move] {
        var generated = [Move]()
        for index in 0..<64 {
            guard let piece = position.board[index], piece.color == position.turn else { continue }
            let from = Square(index: index)
            switch piece.type {
            case .pawn:
                appendPawnMoves(from: from, piece: piece, position: position, into: &generated)
            case .knight:
                appendSteps(from: from, offsets: knightOffsets, piece: piece, position: position, into: &generated)
            case .bishop:
                appendRays(from: from, directions: bishopDirections, piece: piece, position: position, into: &generated)
            case .rook:
                appendRays(from: from, directions: rookDirections, piece: piece, position: position, into: &generated)
            case .queen:
                appendRays(from: from, directions: rookDirections + bishopDirections, piece: piece, position: position, into: &generated)
            case .king:
                appendSteps(from: from, offsets: rookDirections + bishopDirections, piece: piece, position: position, into: &generated)
                appendCastlingMoves(from: from, piece: piece, position: position, into: &generated)
            }
        }
        return generated
    }

    /// Ist das Feld durch `attacker` angegriffen (Bauer, Springer, König, Turm, Läufer, Dame)?
    static func isAttacked(_ square: Square, by attacker: Color, in position: Position) -> Bool {
        let board = position.board

        // Bauer: ein weißer Bauer steht eine Reihe darunter, ein schwarzer eine über dem Feld.
        let pawnRank = square.rank + (attacker == .white ? -1 : 1)
        if (0...7).contains(pawnRank) {
            for fileOffset in [-1, 1] {
                let pawnFile = square.file + fileOffset
                guard (0...7).contains(pawnFile) else { continue }
                if board[Square(file: pawnFile, rank: pawnRank).index] == Piece(color: attacker, type: .pawn) {
                    return true
                }
            }
        }

        // Springer.
        for (fileOffset, rankOffset) in knightOffsets {
            let file = square.file + fileOffset
            let rank = square.rank + rankOffset
            guard (0...7).contains(file), (0...7).contains(rank) else { continue }
            if board[Square(file: file, rank: rank).index] == Piece(color: attacker, type: .knight) {
                return true
            }
        }

        // König (direkt benachbart).
        for (fileOffset, rankOffset) in rookDirections + bishopDirections {
            let file = square.file + fileOffset
            let rank = square.rank + rankOffset
            guard (0...7).contains(file), (0...7).contains(rank) else { continue }
            if board[Square(file: file, rank: rank).index] == Piece(color: attacker, type: .king) {
                return true
            }
        }

        // Turm-/Dame-Linien und Läufer-/Dame-Linien; der erste Figuren-Blick entscheidet.
        for (directions, matchingTypes) in [
            (rookDirections, [PieceType.rook, PieceType.queen]),
            (bishopDirections, [PieceType.bishop, PieceType.queen]),
        ] {
            for (fileOffset, rankOffset) in directions {
                var file = square.file + fileOffset
                var rank = square.rank + rankOffset
                while (0...7).contains(file), (0...7).contains(rank) {
                    let occupant = board[Square(file: file, rank: rank).index]
                    if let occupant {
                        if occupant.color == attacker && matchingTypes.contains(occupant.type) {
                            return true
                        }
                        break   // Linie ist blockiert
                    }
                    file += fileOffset
                    rank += rankOffset
                }
            }
        }
        return false
    }

    // MARK: - Einzelne Figuren

    private static func appendPawnMoves(
        from: Square, piece: Piece, position: Position, into moves: inout [Move]
    ) {
        let step = piece.color == .white ? 1 : -1
        let startRank = piece.color == .white ? 1 : 6
        let promotionRank = piece.color == .white ? 7 : 0
        let nextRank = from.rank + step
        guard (0...7).contains(nextRank) else { return }

        // Vorwärts: ein Feld frei; von der Startreihe auch doppelt.
        let oneAhead = Square(file: from.file, rank: nextRank)
        if position.board[oneAhead.index] == nil {
            appendPawnMove(from: from, to: oneAhead, promotionRank: promotionRank, capture: false, into: &moves)
            if from.rank == startRank {
                let twoAhead = Square(file: from.file, rank: nextRank + step)
                if position.board[twoAhead.index] == nil {
                    moves.append(Move(from: from, to: twoAhead, flags: [.doublePush]))
                }
            }
        }

        // Schrägwärts: eigene Figur nein, Gegner ja oder En-passant-Feld (das ist leer).
        for fileOffset in [-1, 1] {
            let targetFile = from.file + fileOffset
            let targetRank = from.rank + step
            guard (0...7).contains(targetFile), (0...7).contains(targetRank) else { continue }
            let target = Square(file: targetFile, rank: targetRank)
            if let occupant = position.board[target.index], occupant.color != piece.color {
                appendPawnMove(from: from, to: target, promotionRank: promotionRank, capture: true, into: &moves)
            } else if position.board[target.index] == nil, position.enPassant == target {
                moves.append(Move(from: from, to: target, flags: [.capture, .enPassant]))
            }
        }
    }

    /// Umwandlungen mit einbauen: auf der Umwandlungsreihe gibt es vier Ziel-Versionen.
    private static func appendPawnMove(
        from: Square, to: Square, promotionRank: Int, capture: Bool, into moves: inout [Move]
    ) {
        let baseFlags: Move.Flags = capture ? [.capture] : []
        if to.rank == promotionRank {
            for promotion in [PieceType.queen, .rook, .bishop, .knight] {
                moves.append(Move(from: from, to: to, promotion: promotion, flags: baseFlags))
            }
        } else {
            moves.append(Move(from: from, to: to, flags: baseFlags))
        }
    }

    /// Springer und König: Ein-Schritt-Muster mit Zielfeld-Freiheit/Schlag.
    private static func appendSteps(
        from: Square, offsets: [(Int, Int)], piece: Piece, position: Position, into moves: inout [Move]
    ) {
        for (fileOffset, rankOffset) in offsets {
            let file = from.file + fileOffset
            let rank = from.rank + rankOffset
            guard (0...7).contains(file), (0...7).contains(rank) else { continue }
            let target = Square(file: file, rank: rank)
            let occupant = position.board[target.index]
            if occupant == nil {
                moves.append(Move(from: from, to: target))
            } else if occupant!.color != piece.color {
                moves.append(Move(from: from, to: target, flags: [.capture]))
            }
        }
    }

    /// Linienfigur: läuft Richtung für Richtung bis zur ersten Blockade.
    private static func appendRays(
        from: Square, directions: [(Int, Int)], piece: Piece, position: Position, into moves: inout [Move]
    ) {
        for (fileOffset, rankOffset) in directions {
            var file = from.file + fileOffset
            var rank = from.rank + rankOffset
            while (0...7).contains(file), (0...7).contains(rank) {
                let target = Square(file: file, rank: rank)
                let occupant = position.board[target.index]
                if let occupant {
                    if occupant.color != piece.color {
                        moves.append(Move(from: from, to: target, flags: [.capture]))
                    }
                    break
                }
                moves.append(Move(from: from, to: target))
                file += fileOffset
                rank += rankOffset
            }
        }
    }

    /// Rochade: Rechte vorhanden, Felder frei, König-Übergangsfelder nicht angegriffen.
    private static func appendCastlingMoves(
        from: Square, piece: Piece, position: Position, into moves: inout [Move]
    ) {
        let homeRank = piece.color == .white ? 0 : 7
        guard from.rank == homeRank, from.file == 4 else { return }   // König steht auf e-Reihe

        let enemy = piece.color.flipped
        if piece.color == .white {
            if position.castling.contains(.whiteKing),
               position.board[Square(file: 5, rank: homeRank).index] == nil,
               position.board[Square(file: 6, rank: homeRank).index] == nil,
               position.board[Square(file: 7, rank: homeRank).index] == Piece(color: .white, type: .rook),
               !isAttacked(Square(file: 4, rank: homeRank), by: enemy, in: position),
               !isAttacked(Square(file: 5, rank: homeRank), by: enemy, in: position),
               !isAttacked(Square(file: 6, rank: homeRank), by: enemy, in: position) {
                moves.append(Move(from: from, to: Square(file: 6, rank: homeRank), flags: .castleKing))
            }
            if position.castling.contains(.whiteQueen),
               position.board[Square(file: 3, rank: homeRank).index] == nil,
               position.board[Square(file: 2, rank: homeRank).index] == nil,
               position.board[Square(file: 1, rank: homeRank).index] == nil,
               position.board[Square(file: 0, rank: homeRank).index] == Piece(color: .white, type: .rook),
               !isAttacked(Square(file: 4, rank: homeRank), by: enemy, in: position),
               !isAttacked(Square(file: 3, rank: homeRank), by: enemy, in: position),
               !isAttacked(Square(file: 2, rank: homeRank), by: enemy, in: position) {
                moves.append(Move(from: from, to: Square(file: 2, rank: homeRank), flags: .castleQueen))
            }
        } else {
            if position.castling.contains(.blackKing),
               position.board[Square(file: 5, rank: homeRank).index] == nil,
               position.board[Square(file: 6, rank: homeRank).index] == nil,
               position.board[Square(file: 7, rank: homeRank).index] == Piece(color: .black, type: .rook),
               !isAttacked(Square(file: 4, rank: homeRank), by: enemy, in: position),
               !isAttacked(Square(file: 5, rank: homeRank), by: enemy, in: position),
               !isAttacked(Square(file: 6, rank: homeRank), by: enemy, in: position) {
                moves.append(Move(from: from, to: Square(file: 6, rank: homeRank), flags: .castleKing))
            }
            if position.castling.contains(.blackQueen),
               position.board[Square(file: 3, rank: homeRank).index] == nil,
               position.board[Square(file: 2, rank: homeRank).index] == nil,
               position.board[Square(file: 1, rank: homeRank).index] == nil,
               position.board[Square(file: 0, rank: homeRank).index] == Piece(color: .black, type: .rook),
               !isAttacked(Square(file: 4, rank: homeRank), by: enemy, in: position),
               !isAttacked(Square(file: 3, rank: homeRank), by: enemy, in: position),
               !isAttacked(Square(file: 2, rank: homeRank), by: enemy, in: position) {
                moves.append(Move(from: from, to: Square(file: 2, rank: homeRank), flags: .castleQueen))
            }
        }
    }
}
