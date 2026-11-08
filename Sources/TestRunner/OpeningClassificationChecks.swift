import Foundation
import ChessAppKit

func openingClassificationChecks() async throws {
    let book = OpeningBook(openings: [
        .init(eco: "B20", name: "Sizilianisch", moves: ["e4", "c5"])
    ])
    check(book.contains(sanMoves: ["e4"]), "Book erkennt Präfix vor benannter Eröffnung")
    check(book.contains(sanMoves: ["e4", "c5"]), "Book erkennt letzten gespeicherten Buchzug")
    check(!book.contains(sanMoves: []), "Leere Zugfolge ist kein Buchzug")
    check(!book.contains(sanMoves: ["e4", "e5"]), "Abweichung ist kein Buchzug")
    check(!book.contains(sanMoves: ["e4", "c5", "Nf3"]), "Nach Buchende kein weiteres Book-Label")
    checkEqual(MoveClassifier.classify(context: .init(winPercentBefore: 50, winPercentAfter: 50, isBook: true)),
               .book, "Verlässlicher Buchkontext hat Vorrang vor Best")

    let start = try Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    func review(from initial: Position, sans: [String], book: OpeningBook?) async throws -> GameAnalysis? {
        var positions = [initial]
        var moves: [Move] = []
        for san in sans {
            guard let move = SAN.move(from: san, in: positions.last!) else {
                throw EngineError.unexpectedResponse("Ungültiger Testzug: \(san)")
            }
            moves.append(move)
            positions.append(positions.last!.make(move))
        }
        var result: GameAnalysis?
        for try await progress in GameReviewService(engine: OpeningCheckEngine(), openingBook: book)
            .review(positions: positions, moves: moves) {
            result = progress.analysis
        }
        return result
    }

    let report = try await review(from: start, sans: ["e4", "c5", "Nf3", "d6"], book: book)
    checkEqual(report?.moves.map(\.classification), [.book, .book, .best, .best],
               "Review markiert nur gespeicherte Buchzüge, nicht die spätere Partie")
    checkEqual(report?.eco, "B20", "Eröffnungsname bleibt nach Verlassen des Buchs erhalten")
    let prefix = try await review(from: start, sans: ["e4"], book: book)
    checkEqual(prefix?.moves.first?.classification, .book, "Review verbindet Buchpräfix mit Klassifikation")
    check(prefix?.eco == nil, "Eröffnungsname wird vor dem Endpunkt nicht vorweggenommen")
    var customStart = start
    customStart.board[Square(string: "b1")!.index] = nil
    let custom = try await review(from: customStart, sans: ["e4", "c5"], book: book)
    checkEqual(custom?.moves.map(\.classification), [.best, .best], "Eigene FEN-Startstellung erhält keine Buchlabels")
    check(custom?.eco == nil, "Eigene FEN-Startstellung erhält keine falsche Eröffnung")
    var laterStart = start
    laterStart.fullmoveNumber = 7
    let later = try await review(from: laterStart, sans: ["e4", "c5"], book: book)
    checkEqual(later?.moves.map(\.classification), [.best, .best], "Startähnliche FEN mit späterer Zugnummer erhält keine Buchlabels")
    check(later?.eco == nil, "Spätere FEN-Zugnummer erhält keine falsche Eröffnung")
    let withoutBook = try await review(from: start, sans: ["e4"], book: nil)
    checkEqual(withoutBook?.moves.first?.classification, .best, "Fehlendes Buch erhält Engine-Klassifikation")
}

private struct OpeningCheckEngine: ChessEngine {
    func start() async throws {}
    func stop() async {}
    func setOption(name: String, value: String) async throws {}
    func bestMove(fen: String, movetimeMs: Int) async throws -> String { "" }
    func analyze(fen: String, depth: Int, multiPV: Int) -> AsyncStream<EngineInfo> {
        AsyncStream { continuation in
            continuation.yield(EngineInfo(depth: depth, cp: 0))
            continuation.finish()
        }
    }
}
