import Foundation
import SwiftData

/// Einstellungs-Raster (ein Datensatz, key = "app").
@Model
final class AppSettings {
    @Attribute(.unique) var key: String = "app"
    var enginePath: String? = nil
    var threads: Int = 4
    var hashMB: Int = 256
    var skillLevel: Int = 20
    var limitStrength: Bool = false
    var uciElo: Int = 2500
    var analysisDepth: Int = 18
    var boardTheme: String = "Grün"
    var soundEnabled: Bool = true
    var animationsEnabled: Bool = true

    init() {}

    static func fetchOrCreate(context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>(predicate: #Predicate { $0.key == "app" })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        try? context.save()
        return settings
    }
}

/// Gespeicherte Partie (Archiv).
@Model
final class SavedGame {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var whitePlayer: String = "Weiß"
    var blackPlayer: String = "Schwarz"
    var result: String = "*"
    var timeControl: String = "-"
    var openingName: String? = nil
    var pgn: String = ""

    init() {}
}

/// Gespeicherte Analyse einer Partie.
@Model
final class GameAnalysisEntry {
    var id: UUID = UUID()
    var gameID: UUID? = nil
    var createdAt: Date = Date()
    var accuracyWhite: Double = 0
    var accuracyBlack: Double = 0
    var openingECO: String? = nil
    var openingName: String? = nil
    var analysisJSON: Data = Data()

    init() {}
}

/// Puzzle-Fortschritt (ein Datensatz, key = "app").
@Model
final class PuzzleProgress {
    @Attribute(.unique) var key: String = "app"
    var rating: Int = 1500
    var solvedCount: Int = 0
    var failedCount: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var lastSolvedAt: Date? = nil

    init() {}
}

/// Einzelnes Puzzle-Ergebnis (Rating-Verlauf).
@Model
final class PuzzleResult {
    var id: UUID = UUID()
    var puzzleID: String = ""
    var createdAt: Date = Date()
    var solved: Bool = false
    var ratingAfter: Int = 1500

    init() {}
}

/// Lektions-Fortschritt (key = "Kurs|Lektion").
@Model
final class LessonProgress {
    @Attribute(.unique) var key: String = "app"
    var completed: Bool = false
    var updatedAt: Date = Date()

    init() {}
}
