import Foundation

/// Figurenart.
public enum PieceType: String, CaseIterable {
    case pawn, knight, bishop, rook, queen, king

    /// FEN-Buchstabe für Weiß (Großbuchstabe); Schwarz nutzt denselben in Kleinbuchstaben.
    public var fenChar: Character {
        let letter: Character
        switch self {
        case .pawn: letter = "P"
        case .knight: letter = "N"
        case .bishop: letter = "B"
        case .rook: letter = "R"
        case .queen: letter = "Q"
        case .king: letter = "K"
        }
        return letter
    }

    /// Ein-Buchstaben-Code wie in UCI-Zügen und SAN ("n", "b", "r", "q" – Springer ist "n"/"N").
    public var uciLetter: Character {
        let letter: Character
        switch self {
        case .pawn: letter = "p"
        case .knight: letter = "n"
        case .bishop: letter = "b"
        case .rook: letter = "r"
        case .queen: letter = "q"
        case .king: letter = "k"
        }
        return letter
    }

    /// Aus FEN-Buchstaben-Form ohne Farbzuordnung.
    public init?(fenLetter: Character) {
        switch Character(String(fenLetter).lowercased()) {
        case "p": self = .pawn
        case "n": self = .knight
        case "b": self = .bishop
        case "r": self = .rook
        case "q": self = .queen
        case "k": self = .king
        default: return nil
        }
    }
}

/// Figur mit Farbe.
public struct Piece: Equatable {
    public let color: Color
    public let type: PieceType

    public init(color: Color, type: PieceType) {
        self.color = color
        self.type = type
    }

    /// FEN-Buchstabe mit Farbzuordnung ("P" weiß, "p" schwarz).
    public var fenChar: Character {
        color == .white ? type.fenChar : Character(String(type.fenChar).lowercased())
    }

    /// Aus FEN-Buchstaben-Form ("P" bis "k").
    public init?(fenChar: Character) {
        guard let type = PieceType(fenLetter: fenChar) else { return nil }
        self.init(color: fenChar.isUppercase ? .white : .black, type: type)
    }
}
