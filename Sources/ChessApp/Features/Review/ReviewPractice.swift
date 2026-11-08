import Foundation
import ChessAppKit

/// A disposable practice position; never writes to the game or its report.
struct ReviewPractice {
    var moment: MoveAnalysis?
    var position: Position?
    var selected: Square?
    var pendingPromotion: (Square, Square)?
    var revealed = false
    var isCandidateChoice = false
    var feedback: String?

    static func moments(analyses: [MoveAnalysis], positions: [Position], ownSide: PieceColor?) -> [MoveAnalysis] {
        Array(analyses.filter { analysis in
            guard [.inaccuracy, .mistake, .miss, .blunder].contains(analysis.classification),
                  analysis.winPercentLoss.isFinite, analysis.winPercentLoss > 0,
                  analysis.ply > 0, analysis.ply < positions.count,
                  positions[analysis.ply - 1].fen == analysis.fenBefore,
                  positions[analysis.ply].fen == analysis.fenAfter,
                  let before = try? Position(fen: analysis.fenBefore),
                  ownSide == nil || before.turn == ownSide,
                  let best = before.legalMoves().first(where: { $0.uci == analysis.bestMove }),
                  before.make(best).fen != analysis.fenAfter else { return false }
            return true
        }.sorted {
            $0.winPercentLoss == $1.winPercentLoss ? $0.ply < $1.ply : $0.winPercentLoss > $1.winPercentLoss
        }.prefix(3))
    }

    mutating func start(_ moment: MoveAnalysis) {
        reset()
        self.moment = moment
        position = try? Position(fen: moment.fenBefore)
    }

    static func candidates(for moment: MoveAnalysis) -> [Move] {
        guard [.mistake, .miss, .blunder].contains(moment.classification),
              moment.winPercentLoss.isFinite, moment.winPercentLoss >= 10,
              moment.winPercentBefore.isFinite, moment.winPercentAfter.isFinite,
              (0...100).contains(moment.winPercentBefore), (0...100).contains(moment.winPercentAfter),
              moment.winPercentBefore - moment.winPercentAfter >= 10,
              let position = try? Position(fen: moment.fenBefore),
              let played = SAN.move(from: moment.san, in: position),
              position.make(played).fen == moment.fenAfter,
              let best = position.legalMoves().first(where: { $0.uci == moment.bestMove }),
              best != played else { return [] }
        return [played, best].sorted { $0.uci < $1.uci }
    }

    var candidates: [Move] { moment.map(Self.candidates(for:)) ?? [] }

    mutating func startCandidates(_ moment: MoveAnalysis) {
        reset()
        guard Self.candidates(for: moment).count == 2 else { return }
        start(moment)
        isCandidateChoice = true
    }

    mutating func reset() { self = ReviewPractice() }

    mutating func attempt(_ move: Move) {
        guard !revealed, let position, position.legalMoves().contains(move), let moment else { return }
        guard !isCandidateChoice || candidates.contains(move) else { return }
        selected = nil; pendingPromotion = nil
        if isCandidateChoice {
            revealed = true
            feedback = move.uci == moment.bestMove ? "Richtig – die gespeicherte Engine-Empfehlung." : "Das war der fehlerhafte Partiezug. Vergleiche ihn mit der gespeicherten Empfehlung."
            return
        }
        if move.uci == moment.bestMove {
            revealed = true
            feedback = "Gefunden – das ist die Empfehlung der Analyse."
        } else {
            feedback = "Legal, aber nicht die gespeicherte Engine-Empfehlung. Versuche es noch einmal."
        }
    }

    mutating func tap(_ square: Square) {
        guard !revealed, !isCandidateChoice, let position else { return }
        if let selected, let move = position.move(from: selected, to: square) {
            if move.promotion != nil { pendingPromotion = (selected, square) }
            else { attempt(move) }
        } else {
            selected = position.board[square.index]?.color == position.turn ? square : nil
        }
    }

    mutating func promote(_ type: PieceType) {
        guard let position, let (from, to) = pendingPromotion,
              let move = position.move(from: from, to: to, promotion: type) else { return }
        attempt(move)
    }

    var solution: Move? { position?.legalMoves().first { $0.uci == moment?.bestMove } }

    static func moveFacts(_ move: Move, in position: Position) -> String {
        guard position.legalMoves().contains(move) else { return "" }
        let after = position.make(move)
        var facts: [String] = []
        let names: [PieceType: String] = [.pawn: "einen Bauern", .knight: "einen Springer", .bishop: "einen Läufer", .rook: "einen Turm", .queen: "eine Dame", .king: "einen König"]
        if move.flags.contains(.enPassant) { facts.append("Der Zug schlägt einen Bauern en passant.") }
        else if let captured = position.board[move.to.index] { facts.append("Der Zug schlägt \(names[captured.type] ?? "einen Stein").") }
        if let promotion = move.promotion { facts.append("Der Bauer wandelt sich in \(names[promotion] ?? "eine Figur") um.") }
        if after.isCheckmate { facts.append("Matt: Der gegnerische König steht im Schach und hat keinen legalen Antwortzug.") }
        else if after.isStalemate { facts.append("Danach ist Patt: kein legaler Zug, aber auch kein Schach.") }
        else if after.isInCheck(after.turn) { facts.append("Der Zug gibt Schach.") }
        if move.flags.contains(.castleKing) || move.flags.contains(.castleQueen) { facts.append("König und Turm rochieren.") }
        return facts.joined(separator: " ")
    }

    var explanation: String? {
        guard let moment, let position, let solution else { return nil }
        let side = position.turn == .white ? "Weiß" : "Schwarz"
        return "\(side) spielte \(moment.san). Die Analyse empfiehlt \(SAN.notation(for: solution, in: position)). Der Partiezug verlor laut Analyse \(String(format: "%.1f", moment.winPercentLoss)) Prozentpunkte Gewinnchance. " + Self.moveFacts(solution, in: position)
    }
}
