import Foundation
import CoreData

@objc(AppSettings)
public class AppSettings: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var enginePath: String?
    @NSManaged public var threads: Int64
    @NSManaged public var hashMB: Int64
    @NSManaged public var skillLevel: Int64
    @NSManaged public var limitStrength: Bool
    @NSManaged public var uciElo: Int64
    @NSManaged public var analysisDepth: Int64
    @NSManaged public var boardTheme: String
    @NSManaged public var soundEnabled: Bool
    @NSManaged public var animationsEnabled: Bool

    public static func fetchOrCreate(context: NSManagedObjectContext) -> AppSettings {
        let request: NSFetchRequest<AppSettings> = NSFetchRequest(entityName: "AppSettings")
        request.predicate = NSPredicate(format: "key == %@", "app")
        if let existing = try? context.fetch(request).first {
            return existing
        }
        let settings = AppSettings(context: context)
        settings.key = "app"
        settings.threads = 4
        settings.hashMB = 256
        settings.skillLevel = 20
        settings.limitStrength = false
        settings.uciElo = 2500
        settings.analysisDepth = 18
        settings.boardTheme = "Grün"
        settings.soundEnabled = true
        settings.animationsEnabled = true
        try? context.save()
        return settings
    }
}

@objc(SavedGame)
public class SavedGame: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var createdAt: Date
    @NSManaged public var whitePlayer: String
    @NSManaged public var blackPlayer: String
    @NSManaged public var result: String
    @NSManaged public var timeControl: String
    @NSManaged public var openingName: String?
    @NSManaged public var pgn: String

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        whitePlayer = "Weiß"
        blackPlayer = "Schwarz"
        result = "*"
        timeControl = "-"
        pgn = ""
    }
}

@objc(GameAnalysisEntry)
public class GameAnalysisEntry: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var gameID: UUID?
    @NSManaged public var createdAt: Date
    @NSManaged public var accuracyWhite: Double
    @NSManaged public var accuracyBlack: Double
    @NSManaged public var openingECO: String?
    @NSManaged public var openingName: String?
    @NSManaged public var analysisJSON: Data

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        analysisJSON = Data()
    }
}

@objc(PuzzleProgress)
public class PuzzleProgress: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var rating: Int64
    @NSManaged public var solvedCount: Int64
    @NSManaged public var failedCount: Int64
    @NSManaged public var currentStreak: Int64
    @NSManaged public var bestStreak: Int64
    @NSManaged public var lastSolvedAt: Date?

    public static func fetchOrCreate(context: NSManagedObjectContext) -> PuzzleProgress {
        let request: NSFetchRequest<PuzzleProgress> = NSFetchRequest(entityName: "PuzzleProgress")
        request.predicate = NSPredicate(format: "key == %@", "app")
        if let existing = try? context.fetch(request).first {
            return existing
        }
        let progress = PuzzleProgress(context: context)
        progress.key = "app"
        progress.rating = 1500
        progress.solvedCount = 0
        progress.failedCount = 0
        progress.currentStreak = 0
        progress.bestStreak = 0
        try? context.save()
        return progress
    }
}

@objc(PuzzleResult)
public class PuzzleResult: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var puzzleID: String
    @NSManaged public var createdAt: Date
    @NSManaged public var solved: Bool
    @NSManaged public var ratingAfter: Int64

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        puzzleID = ""
        createdAt = Date()
        ratingAfter = 1500
    }
}

@objc(LessonProgress)
public class LessonProgress: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var completed: Bool
    @NSManaged public var updatedAt: Date

    public static func find(key: String, context: NSManagedObjectContext) -> LessonProgress? {
        let request: NSFetchRequest<LessonProgress> = NSFetchRequest(entityName: "LessonProgress")
        request.predicate = NSPredicate(format: "key == %@", key)
        return try? context.fetch(request).first
    }

    public static func setCompleted(key: String, completed: Bool, context: NSManagedObjectContext) {
        let item = find(key: key, context: context) ?? LessonProgress(context: context)
        item.key = key
        item.completed = completed
        item.updatedAt = Date()
        try? context.save()
    }
}
