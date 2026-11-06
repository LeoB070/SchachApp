import Foundation

/// Farbe einer Seite.
public enum Color {
    case white, black

    /// Die jeweils andere Farbe.
    public var flipped: Color {
        self == .white ? .black : .white
    }
}
