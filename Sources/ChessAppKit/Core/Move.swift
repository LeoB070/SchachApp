import Foundation

/// Ein Zug von Feld zu Feld, optional mit Umwandlung und Flags.
public struct Move: Equatable {
    /// Zusätzliche Zugart-Markierungen.
    public struct Flags: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let capture = Flags(rawValue: 1 << 0)
        public static let enPassant = Flags(rawValue: 1 << 1)
        public static let castleKing = Flags(rawValue: 1 << 2)
        public static let castleQueen = Flags(rawValue: 1 << 3)
        public static let doublePush = Flags(rawValue: 1 << 4)
    }

    public let from: Square
    public let to: Square
    public let promotion: PieceType?
    public let flags: Flags

    public init(from: Square, to: Square, promotion: PieceType? = nil, flags: Flags = []) {
        self.from = from
        self.to = to
        self.promotion = promotion
        self.flags = flags
    }

    /// UCI-Code wie "e2e4", "e7e8q" (Springer-Umwandlung = "n"), Passantenschlag = Ziel des Einzugs.
    public var uci: String {
        var code = from.name + to.name
        if let promotion {
            code.append(promotion.uciLetter)
        }
        return code
    }
}
