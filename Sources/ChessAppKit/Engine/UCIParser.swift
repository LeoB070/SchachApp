import Foundation

/// Rohdaten einer ungefilterten `info`-Zeile der UCI-Engine.
public struct RawEngineInfo: Sendable, Equatable {
    public var depth: Int?
    public var seldepth: Int?
    public var multiPV: Int?
    public var cp: Int?
    public var mate: Int?
    public var isLowerbound: Bool = false
    public var isUpperbound: Bool = false
    public var nps: Int?
    public var nodes: Int?
    public var timeMs: Int?
    public var pv: [String] = []

    public init(
        depth: Int? = nil,
        seldepth: Int? = nil,
        multiPV: Int? = nil,
        cp: Int? = nil,
        mate: Int? = nil,
        isLowerbound: Bool = false,
        isUpperbound: Bool = false,
        nps: Int? = nil,
        nodes: Int? = nil,
        timeMs: Int? = nil,
        pv: [String] = []
    ) {
        self.depth = depth
        self.seldepth = seldepth
        self.multiPV = multiPV
        self.cp = cp
        self.mate = mate
        self.isLowerbound = isLowerbound
        self.isUpperbound = isUpperbound
        self.nps = nps
        self.nodes = nodes
        self.timeMs = timeMs
        self.pv = pv
    }
}

/// Geparste Antworttypen einer UCI-Engine.
public enum UCIResponse: Sendable, Equatable {
    case info(RawEngineInfo)
    case bestMove(move: String, ponder: String?)
    case uciOk
    case readyOk
    case other(String)
}

/// Parser für Textausgaben einer UCI-Schach-Engine (Stockfish).
public enum UCIParser {

    /// Bestimmt die Farbe des am Zug befindlichen Spielers direkt aus einem FEN-String.
    /// Startstellung ("... w ...") -> .white, nach 1. e4 ("... b ...") -> .black.
    public static func sideToMove(fromFEN fen: String) -> Color {
        let parts = fen.split(separator: " ")
        if parts.count >= 2 && parts[1] == "b" {
            return .black
        }
        return .white
    }

    /// Parst eine beliebige UCI-Zeile in eine strukturierte `UCIResponse`.
    public static func parseLine(_ line: String) -> UCIResponse {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "uciok" {
            return .uciOk
        }
        if trimmed == "readyok" {
            return .readyOk
        }
        if trimmed.hasPrefix("bestmove") {
            if let bm = parseBestMoveLine(trimmed) {
                return .bestMove(move: bm.move, ponder: bm.ponder)
            }
        }
        if trimmed.hasPrefix("info") {
            if let info = parseInfoLine(trimmed) {
                return .info(info)
            }
        }
        return .other(trimmed)
    }

    /// Parst eine `bestmove`-Zeile, z. B.:
    /// `bestmove e2e4` oder `bestmove e2e4 ponder e7e5` oder `bestmove (none)`.
    public static func parseBestMoveLine(_ line: String) -> (move: String, ponder: String?)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("bestmove") else { return nil }
        let tokens = trimmed.split(separator: " ").map(String.init)
        guard tokens.count >= 2 else { return nil }

        let move = tokens[1]
        var ponder: String? = nil
        if tokens.count >= 4 && tokens[2] == "ponder" {
            ponder = tokens[3]
        }
        return (move: move, ponder: ponder)
    }

    /// Parst eine `info`-Zeile der Engine in `RawEngineInfo`.
    public static func parseInfoLine(_ line: String) -> RawEngineInfo? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("info") else { return nil }

        let tokens = trimmed.split(separator: " ").map(String.init)
        var info = RawEngineInfo()
        var i = 1

        while i < tokens.count {
            let token = tokens[i]
            switch token {
            case "depth":
                if i + 1 < tokens.count, let val = Int(tokens[i + 1]) {
                    info.depth = val
                    i += 1
                }
            case "seldepth":
                if i + 1 < tokens.count, let val = Int(tokens[i + 1]) {
                    info.seldepth = val
                    i += 1
                }
            case "multipv":
                if i + 1 < tokens.count, let val = Int(tokens[i + 1]) {
                    info.multiPV = val
                    i += 1
                }
            case "score":
                // Format: score cp <v> [lowerbound|upperbound] oder score mate <v>
                var j = i + 1
                while j < tokens.count {
                    let sub = tokens[j]
                    if sub == "cp" && j + 1 < tokens.count, let val = Int(tokens[j + 1]) {
                        info.cp = val
                        j += 1
                    } else if sub == "mate" && j + 1 < tokens.count, let val = Int(tokens[j + 1]) {
                        info.mate = val
                        j += 1
                    } else if sub == "lowerbound" {
                        info.isLowerbound = true
                    } else if sub == "upperbound" {
                        info.isUpperbound = true
                    } else {
                        break
                    }
                    j += 1
                }
                i = j - 1
            case "lowerbound":
                info.isLowerbound = true
            case "upperbound":
                info.isUpperbound = true
            case "nps":
                if i + 1 < tokens.count, let val = Int(tokens[i + 1]) {
                    info.nps = val
                    i += 1
                }
            case "nodes":
                if i + 1 < tokens.count, let val = Int(tokens[i + 1]) {
                    info.nodes = val
                    i += 1
                }
            case "time":
                if i + 1 < tokens.count, let val = Int(tokens[i + 1]) {
                    info.timeMs = val
                    i += 1
                }
            case "pv":
                if i + 1 < tokens.count {
                    info.pv = Array(tokens[(i + 1)...])
                }
                i = tokens.count // PV geht bis zum Ende der Zeile
            default:
                break
            }
            i += 1
        }

        return info
    }

    /// Normalisiert Roh-Bewertungen aus Sicht von Weiß.
    ///
    /// WICHTIG: UCI liefert cp und mate immer aus Sicht des Spielers AM ZUG!
    /// Ist Schwarz am Zug, werden cp und mate negiert:
    /// - `cp`: +50 für Schwarz am Zug bedeutet -50 für Weiß.
    /// - `mate`: +2 für Schwarz am Zug bedeutet Matt für Schwarz in 2 Zügen -> -2 für Weiß.
    /// - Positives `mate`: Weiß setzt matt.
    /// - Negatives `mate`: Schwarz setzt matt.
    public static func normalizeInfo(_ raw: RawEngineInfo, sideToMove: Color) -> EngineInfo? {
        guard let depth = raw.depth else { return nil }

        let normalizedCp: Int?
        let normalizedMate: Int?

        if sideToMove == .black {
            normalizedCp = raw.cp.map { -$0 }
            normalizedMate = raw.mate.map { -$0 }
        } else {
            normalizedCp = raw.cp
            normalizedMate = raw.mate
        }

        return EngineInfo(
            depth: depth,
            multiPV: raw.multiPV ?? 1,
            cp: normalizedCp,
            mate: normalizedMate,
            pv: raw.pv,
            nps: raw.nps
        )
    }

    /// Parst eine `info`-Zeile direkt und normalisiert die Werte aus Sicht von Weiß.
    public static func parseEngineInfo(line: String, sideToMove: Color) -> EngineInfo? {
        guard let raw = parseInfoLine(line) else { return nil }
        return normalizeInfo(raw, sideToMove: sideToMove)
    }
}
