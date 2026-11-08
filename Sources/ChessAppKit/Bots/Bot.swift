import Foundation

/// Datenmodell für einen virtuellen Schach-Bot mit individuellem Spiel- und Fehlerprofil.
public struct Bot: Identifiable, Sendable, Equatable {
    /// Eindeutige Kennung des Bots (z. B. "anton").
    public let id: String
    /// Anzeigename des Bots.
    public let name: String
    /// Kurzbeschreibung des Spielstils.
    public let description: String
    /// Ungefähre Spielstärke nach Elo.
    public let elo: Int
    /// UCI-Skill-Level von 0 bis 20.
    public let skillLevel: Int
    /// Fehlerwahrscheinlichkeit: bis 1000 Elo zufälliger legaler Zug, darüber MultiPV-Nebenvariante.
    public let randomness: Double
    /// Basis-Bedenkzeit pro Zug in Millisekunden.
    public let movetimeMs: Int

    public init(
        id: String,
        name: String,
        description: String,
        elo: Int,
        skillLevel: Int,
        randomness: Double,
        movetimeMs: Int
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.elo = elo
        self.skillLevel = min(20, max(0, skillLevel))
        self.randomness = min(1.0, max(0.0, randomness))
        self.movetimeMs = max(50, movetimeMs)
    }

    /// Berechnet die Bedenkzeit für den aktuellen Zug mit einer natürlichen Variation von ±20 %.
    public func randomizedMovetime() -> Int {
        let factor = Double.random(in: 0.8...1.2)
        return max(50, Int(Double(movetimeMs) * factor))
    }

    /// Wählt für die gegebene FEN-Stellung einen Zug aus.
    ///
    /// Konfiguriert die Engine auf die Bot-spezifische Spielstärke.
    /// Mit Wahrscheinlichkeit `randomness` wählt der Bot statt des optimalen Zuges
    /// eine der Nebenvarianten (MultiPV 2-4). Schwache Bots machen so plausible,
    /// menschlich wirkende Patzer statt illegaler oder völlig absurder Züge.
    public func chooseMove(fen: String, engine: ChessEngine) async throws -> String {
        try Task.checkCancellation()
        let position = try Position(fen: fen)
        let legalMoves = position.legalMoves()
        guard !legalMoves.isEmpty else { return "0000" }
        let targetTimeMs = randomizedMovetime()
        // shortcut: Elo below 1000 is estimated, calibrate against rated games before claiming measured ratings.
        if elo <= 1000 && Double.random(in: 0..<1) < randomness {
            try await Task.sleep(nanoseconds: UInt64(targetTimeMs) * 1_000_000)
            return legalMoves.randomElement()!.uci
        }
        let startTimestamp = Date()

        // 1. Engine konfigurieren
        try await engine.setOption(name: "Skill Level", value: "\(skillLevel)")
        if elo < 2500 {
            try await engine.setOption(name: "UCI_LimitStrength", value: "true")
            try await engine.setOption(name: "UCI_Elo", value: "\(min(3190, max(1320, elo)))")
        } else {
            try await engine.setOption(name: "UCI_LimitStrength", value: "false")
        }

        // 2. Patzer-Entscheidung treffen
        let willBlunder = (randomness > 0.0) && (Double.random(in: 0.0..<1.0) < randomness)
        var selectedMove: String?

        if willBlunder {
            // Analysiere mit MultiPV 4, um menschliche Ungenauigkeiten/Patzer aus den Rängen 2-4 zu fischen
            selectedMove = await chooseBlunderMove(fen: fen, engine: engine)
        }

        // Falls kein Patzer gewählt wurde oder die Analyse fehlschlug, regulären Bestzug anfordern
        if selectedMove == nil || selectedMove?.isEmpty == true {
            selectedMove = try await engine.bestMove(fen: fen, movetimeMs: targetTimeMs)
        }

        try Task.checkCancellation()
        let chosen = selectedMove ?? "0000"

        // 3. Natürliche Bedenkzeit einhalten, falls die Engine schneller fertig war
        let elapsedMs = Int(Date().timeIntervalSince(startTimestamp) * 1000)
        if elapsedMs < targetTimeMs {
            let sleepMs = targetTimeMs - elapsedMs
            try await Task.sleep(nanoseconds: UInt64(sleepMs) * 1_000_000)
        }

        return chosen
    }

    private func chooseBlunderMove(fen: String, engine: ChessEngine) async -> String? {
        let stream = engine.analyze(fen: fen, depth: 10, multiPV: 4)

        // TODO(CLAUDE): Menschliche Fehlerprofile und zeitbegrenzte MultiPV-Suche kalibrieren.
        // shortcut: depth 10 finishes before choosing, use a timed engine request for tighter move budgets.
        var movesByRank: [Int: String] = [:]
        for await info in stream {
            if Task.isCancelled { return nil }
            if let firstMove = info.pv.first {
                movesByRank[info.multiPV] = firstMove
            }
        }

        // Suche Züge auf MultiPV 2, 3 oder 4
        let blunderCandidates = movesByRank
            .filter { $0.key >= 2 && !$0.value.isEmpty }
            .sorted { $0.key < $1.key }
            .map(\.value)

        if let blunder = blunderCandidates.randomElement() {
            return blunder
        }

        // Fallback auf MultiPV 1
        return movesByRank[1]
    }
}

