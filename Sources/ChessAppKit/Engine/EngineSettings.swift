import Foundation

/// Konfiguration für die Schach-Engine (UCI-Parameter und Analysetiefe).
public struct EngineSettings: Sendable, Equatable, Codable {
    /// Anzahl der CPU-Threads für die Engine (mindestens 1, Standard: 4).
    public var threads: Int

    /// Größe der Transpositionstabelle in Megabyte (mindestens 1 MB, Standard: 256 MB).
    public var hashMB: Int

    /// Spielstärkestufe der Engine von 0 bis 20 (Standard: 20 = maximale Stärke).
    public var skillLevel: Int

    /// Ob die Spielstärke künstlich limitiert wird (`UCI_LimitStrength`).
    public var limitStrength: Bool

    /// Elo-Zahl bei limitierter Stärke (Bereich üblicherweise 1320...3190, Standard: 2500).
    public var uciElo: Int

    /// Standardtiefe für automatische Partienanalysen (Halbzüge, Standard: 18).
    public var analysisDepth: Int

    public init(
        threads: Int = 4,
        hashMB: Int = 256,
        skillLevel: Int = 20,
        limitStrength: Bool = false,
        uciElo: Int = 2500,
        analysisDepth: Int = 18
    ) {
        self.threads = max(1, threads)
        self.hashMB = max(1, hashMB)
        self.skillLevel = min(20, max(0, skillLevel))
        self.limitStrength = limitStrength
        self.uciElo = min(3190, max(1320, uciElo))
        self.analysisDepth = max(1, analysisDepth)
    }

    /// Erzeugt ein Dictionary aller UCI-Optionskommandos.
    public var uciOptions: [String: String] {
        var options: [String: String] = [
            "Threads": "\(threads)",
            "Hash": "\(hashMB)",
            "Skill Level": "\(skillLevel)",
            "UCI_LimitStrength": limitStrength ? "true" : "false"
        ]
        if limitStrength {
            options["UCI_Elo"] = "\(uciElo)"
        }
        return options
    }
}

extension EngineSettings {
    /// Initialisiert die Engine-Einstellungen aus den persistenten AppSettings.
    public init(appSettings: AppSettings) {
        self.init(
            threads: Int(appSettings.threads),
            hashMB: Int(appSettings.hashMB),
            skillLevel: Int(appSettings.skillLevel),
            limitStrength: appSettings.limitStrength,
            uciElo: Int(appSettings.uciElo),
            analysisDepth: Int(appSettings.analysisDepth)
        )
    }
}
