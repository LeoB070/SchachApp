import Foundation

/// Einheiten einer Stellungsbewertung der Engine, immer normalisiert aus der Sicht von Weiß.
public struct EngineInfo: Sendable, Equatable {
    /// Suchtiefe in Halbzügen / Plies.
    public let depth: Int
    /// Index der Variante bei MultiPV (1 = Hauptvariante).
    public let multiPV: Int
    /// Zentibauern-Bewertung aus Sicht von Weiß (+100 = Weiß steht einen Bauern besser).
    public let cp: Int?
    /// Züge bis zum Matt aus Sicht von Weiß (positiv = Weiß setzt matt, negativ = Schwarz setzt matt).
    public let mate: Int?
    /// Zugfolge (Hauptvariante) in UCI-Notation (z. B. ["e2e4", "e7e5"]).
    public let pv: [String]
    /// Berechnete Knoten pro Sekunde.
    public let nps: Int?

    public init(
        depth: Int,
        multiPV: Int = 1,
        cp: Int? = nil,
        mate: Int? = nil,
        pv: [String] = [],
        nps: Int? = nil
    ) {
        self.depth = depth
        self.multiPV = multiPV
        self.cp = cp
        self.mate = mate
        self.pv = pv
        self.nps = nps
    }
}

/// Fehler, die bei der Interaktion mit der Schach-Engine auftreten können.
public enum EngineError: LocalizedError, Sendable, Equatable {
    case notRunning
    case binaryNotFound(String)
    case failedToStart(String)
    case timeout
    case cancelled
    case processTerminated
    case unexpectedResponse(String)

    public var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Die Schach-Engine läuft nicht."
        case .binaryNotFound(let path):
            return "Das Engine-Binary wurde nicht gefunden: \(path)"
        case .failedToStart(let reason):
            return "Die Engine konnte nicht gestartet werden: \(reason)"
        case .timeout:
            return "Zeitüberschreitung beim Warten auf die Antwort der Engine."
        case .cancelled:
            return "Die Engine-Berechnung wurde abgebrochen."
        case .processTerminated:
            return "Der Engine-Prozess wurde unerwartet beendet."
        case .unexpectedResponse(let details):
            return "Unerwartete Antwort der Engine: \(details)"
        }
    }
}

/// Einheitliches Protokoll für Schach-Engines (z. B. Stockfish über UCI).
public protocol ChessEngine: Sendable {
    /// Startet die Engine und stellt die UCI-Bereitschaft her.
    func start() async throws

    /// Hält laufende Berechnungen an und beendet den Prozess sauber.
    func stop() async

    /// Setzt eine UCI-Option (z. B. "Threads", "Hash", "Skill Level").
    func setOption(name: String, value: String) async throws

    /// Analysiert eine Stellung asynchron bis zur angegebenen Tiefe und liefert Zwischenstände.
    func analyze(fen: String, depth: Int, multiPV: Int) -> AsyncStream<EngineInfo>

    /// Berechnet den besten Zug für die gegebene Bedenkzeit in Millisekunden.
    func bestMove(fen: String, movetimeMs: Int) async throws -> String
}
