// UI-Zugsuche: BoardView-Klick (from/to, optional Umwandlung) gibt den
// passenden legalen Zug mit vollstaendigen Flags zurueck (enPassant, capture,
// Rochade, promotion vorausgewaehlt).
extension Position {
    public func move(from origin: Square, to destination: Square, promotion: PieceType? = nil) -> Move? {
        let candidates = legalMoves().filter { $0.from == origin && $0.to == destination }
        if let promotion {
            return candidates.first { $0.promotion == promotion }
        }
        return candidates.first { $0.promotion == nil } ?? candidates.first
    }
}
