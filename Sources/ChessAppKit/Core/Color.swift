import Foundation

/// Farbe einer Seite (Weiß oder Schwarz).
public enum Color: String, CaseIterable, Sendable {
    case white = "w"
    case black = "b"

    /// Die jeweils andere Farbe.
    public var flipped: Color {
        self == .white ? .black : .white
    }
}

public typealias PieceColor = Color
