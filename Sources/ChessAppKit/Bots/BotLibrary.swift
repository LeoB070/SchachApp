import Foundation

/// Bibliothek vorkonfigurierter Bots mit unterschiedlichen Spielstilen und Fehlerraten.
public enum BotLibrary {

    /// Anfänger: macht häufig taktische Fehler, übersieht Angriffe.
    public static let anton = Bot(
        id: "anton",
        name: "Anfänger Anton",
        description: "Macht oft Fehler und übersieht taktische Schläge.",
        elo: 800,
        skillLevel: 1,
        randomness: 0.40,
        movetimeMs: 400
    )

    /// Hobbyspielerin: spielt angriffslustig, patzt jedoch gelegentlich.
    public static let anna = Bot(
        id: "anna",
        name: "Angriffslustige Anna",
        description: "Spielt forsch nach vorne, patzt aber ab und zu.",
        elo: 1200,
        skillLevel: 5,
        randomness: 0.25,
        movetimeMs: 600
    )

    /// Vorsichtiger Hobbyspieler: solider Aufbau, sichert vor allem Figuren ab.
    public static let viktor = Bot(
        id: "viktor",
        name: "Vorsichtiger Viktor",
        description: "Solider Hobbyspieler, der vor allem Material sichert.",
        elo: 1500,
        skillLevel: 9,
        randomness: 0.15,
        movetimeMs: 800
    )

    /// Schneller Blitzspieler: zieht rasch mit wenig Bedenkzeit.
    public static let bruno = Bot(
        id: "bruno",
        name: "Blitzer Bruno",
        description: "Zieht schnell und aggressiv mit wenig Bedenkzeit.",
        elo: 1700,
        skillLevel: 12,
        randomness: 0.10,
        movetimeMs: 300
    )

    /// Erfahrene Vereinsspielerin: präzise Züge, kaum taktische Schwächen.
    public static let clara = Bot(
        id: "clara",
        name: "Clubspieler Clara",
        description: "Erfahrene Vereinsspielerin mit sauberem Positionsspiel.",
        elo: 1900,
        skillLevel: 15,
        randomness: 0.05,
        movetimeMs: 1200
    )

    /// Maximale Stockfish-Stärke ohne Drosselung.
    public static let stockfishVoll = Bot(
        id: "stockfish_voll",
        name: "Stockfish Voll",
        description: "Maximale Spielstärke ohne Drosselung.",
        elo: 2500,
        skillLevel: 20,
        randomness: 0.0,
        movetimeMs: 2000
    )

    /// Liste aller verfügbaren Bots, sortiert nach Spielstärke.
    public static let allBots: [Bot] = [
        anton,
        anna,
        viktor,
        bruno,
        clara,
        stockfishVoll
    ]

    /// Sucht einen Bot anhand seiner eindeutigen ID.
    public static func bot(forId id: String) -> Bot? {
        allBots.first(where: { $0.id == id })
    }
}
