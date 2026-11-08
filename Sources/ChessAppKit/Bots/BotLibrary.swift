import Foundation

/// Bibliothek vorkonfigurierter Bots mit unterschiedlichen Spielstilen und Fehlerraten.
public enum BotLibrary {

    public static let pippa = Bot(id: "pippa", name: "Pippa", description: "Lernt die ersten Züge und probiert neugierig aus.",
                                 elo: 100, skillLevel: 0, randomness: 1.0, movetimeMs: 300)

    public static let lumi = Bot(id: "lumi", name: "Lumi", description: "Nimmt es gemütlich und übersieht so manchen Angriff.",
                                 elo: 200, skillLevel: 0, randomness: 0.93, movetimeMs: 300)

    public static let milo = Bot(id: "milo", name: "Milo", description: "Spielt mutig los und lässt oft eine Figur stehen.",
                                 elo: 300, skillLevel: 0, randomness: 0.86, movetimeMs: 300)

    public static let ida = Bot(id: "ida", name: "Ida", description: "Spielt vorsichtig und übersieht noch manche Pläne.",
                                 elo: 400, skillLevel: 0, randomness: 0.79, movetimeMs: 300)

    public static let olli = Bot(id: "olli", name: "Olli", description: "Probiert viel aus und vergisst dabei die Verteidigung.",
                                 elo: 600, skillLevel: 0, randomness: 0.65, movetimeMs: 300)

    public static let nelli = Bot(id: "nelli", name: "Nelli", description: "Nimmt gern Bauern und übersieht manchmal größere Gefahren.",
                                 elo: 700, skillLevel: 0, randomness: 0.58, movetimeMs: 300)

    public static let finn = Bot(id: "finn", name: "Finn", description: "Hat erste Tricks gelernt, aber noch nicht alle Fallen.",
                                 elo: 900, skillLevel: 0, randomness: 0.44, movetimeMs: 300)

    public static let rudi = Bot(id: "rudi", name: "Rudi", description: "Findet gute Ideen und greift trotzdem gelegentlich daneben.",
                                 elo: 1000, skillLevel: 0, randomness: 0.37, movetimeMs: 300)

    /// Sehr leichter Gegner für erste Partien.
    public static let emil = Bot(
        id: "emil",
        name: "Emil",
        description: "Ein besonders leichter Gegner für die ersten Partien.",
        elo: 500,
        skillLevel: 0,
        randomness: 0.72,
        movetimeMs: 300
    )

    /// Anfänger: macht häufig taktische Fehler, übersieht Angriffe.
    public static let anton = Bot(
        id: "anton",
        name: "Anton",
        description: "Macht oft Fehler und übersieht taktische Schläge.",
        elo: 800,
        skillLevel: 1,
        randomness: 0.51,
        movetimeMs: 400
    )

    /// Hobbyspielerin: spielt angriffslustig, patzt jedoch gelegentlich.
    public static let anna = Bot(
        id: "anna",
        name: "Anna",
        description: "Spielt forsch nach vorne, patzt aber ab und zu.",
        elo: 1200,
        skillLevel: 5,
        randomness: 0.25,
        movetimeMs: 600
    )

    /// Vorsichtiger Hobbyspieler: solider Aufbau, sichert vor allem Figuren ab.
    public static let viktor = Bot(
        id: "viktor",
        name: "Viktor",
        description: "Solider Hobbyspieler, der vor allem Material sichert.",
        elo: 1500,
        skillLevel: 9,
        randomness: 0.15,
        movetimeMs: 800
    )

    /// Schneller Blitzspieler: zieht rasch mit wenig Bedenkzeit.
    public static let bruno = Bot(
        id: "bruno",
        name: "Bruno",
        description: "Zieht schnell und aggressiv mit wenig Bedenkzeit.",
        elo: 1700,
        skillLevel: 12,
        randomness: 0.10,
        movetimeMs: 300
    )

    /// Erfahrene Vereinsspielerin: präzise Züge, kaum taktische Schwächen.
    public static let clara = Bot(
        id: "clara",
        name: "Clara",
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
        pippa, lumi, milo, ida, emil, olli, nelli, anton, finn, rudi,
        anna,
        viktor,
        bruno,
        clara,
        stockfishVoll
    ]

    /// Alte Archivnamen bleiben zuordenbar, ohne gespeicherte Partien umzuschreiben.
    public static func matchesSavedName(_ name: String, bot: Bot) -> Bool {
        let legacyNames = [
            "pippa": "Pippa Küken",
            "lumi": "Lumi Faultier",
            "milo": "Milo Hase",
            "ida": "Ida Igel",
            "olli": "Olli Otter",
            "nelli": "Nelli Eichhörnchen",
            "finn": "Finn Fuchs",
            "rudi": "Rudi Waschbär",
            "emil": "Emil Bär",
            "anton": "Anton Panda",
            "anna": "Anna Eule",
            "viktor": "Viktor Schildkröte",
            "bruno": "Bruno Gepard",
            "clara": "Clara Katze"
        ]
        return name == bot.name || name == legacyNames[bot.id]
    }

    /// Sucht einen Bot anhand seiner eindeutigen ID.
    public static func bot(forId id: String) -> Bot? {
        allBots.first(where: { $0.id == id })
    }
}
