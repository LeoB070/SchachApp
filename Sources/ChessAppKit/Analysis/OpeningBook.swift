import Foundation

public struct OpeningBook: Sendable {
    public struct Opening: Codable, Sendable, Equatable {
        public let eco: String
        public let name: String
        public let moves: [String]

        public init(eco: String, name: String, moves: [String]) {
            self.eco = eco
            self.name = name
            self.moves = moves
        }
    }

    public let openings: [Opening]

    public init(openings: [Opening]) { self.openings = openings }

    public init(bundle: Bundle = ChessAppKitInfo.resourceBundle) throws {
        guard let url = bundle.url(forResource: "openings", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        struct Record: Decodable {
            let eco: String
            let name: String
            let moves: [String]?
            let pgn: String?
        }
        let records = try JSONDecoder().decode([Record].self, from: Data(contentsOf: url))
        self.openings = records.map { record in
            let moves = record.moves ?? (record.pgn ?? "").split(whereSeparator: \.isWhitespace)
                .map(String.init).filter { !$0.contains(".") }
            return Opening(eco: record.eco, name: record.name, moves: moves)
        }
    }

    /// Nur tatsächlich gespeicherte Buchzüge, einschließlich Präfixen vor dem benannten Endpunkt.
    public func contains(sanMoves: [String]) -> Bool {
        !sanMoves.isEmpty && openings.contains { $0.moves.starts(with: sanMoves) }
    }

    // Named sequences are complete for A00–E99; transpositions need position-aware matching.
    public func match(sanMoves: [String]) -> Opening? {
        openings.filter { !$0.moves.isEmpty && sanMoves.starts(with: $0.moves) }
            .max { $0.moves.count < $1.moves.count }
    }
}
