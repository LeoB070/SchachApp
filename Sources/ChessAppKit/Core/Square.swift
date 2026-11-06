import Foundation

/// Ein Brett-Feld: index = rank*8+file, also a1 = 0 und h8 = 63.
/// file/rank je 0–7, rank 0 = Reihe "1".
public struct Square: Hashable {
    public let index: Int

    public init(index: Int) {
        self.index = index
    }

    public init(file: Int, rank: Int) {
        self.init(index: rank * 8 + file)
    }

    /// Aus Standardnotation wie "e4"; nil bei ungültiger Eingabe.
    public init?(string: String) {
        let chars = Array(string.lowercased())
        guard chars.count == 2,
              let fileLetter = chars[0].asciiValue, (97...104).contains(fileLetter),
              let rankDigit = chars[1].asciiValue, (49...56).contains(rankDigit)
        else { return nil }
        self.init(file: Int(fileLetter - 97), rank: Int(rankDigit - 49))
    }

    public var file: Int { index % 8 }
    public var rank: Int { index / 8 }

    /// Standardnotation, z. B. "e4".
    public var name: String {
        let fileLetters = ["a", "b", "c", "d", "e", "f", "g", "h"]
        return fileLetters[file] + String(rank + 1)
    }

    /// Feldfarbe (false = dunkel wie a1, true = hell wie h1).
    public var isLight: Bool {
        (file + rank) % 2 == 1
    }
}
