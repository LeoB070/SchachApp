import Foundation
import CoreData

// Programmatisches Core-Data-Modell (warum: siehe Models.swift - CLT kann
// SwiftData-@Model-Makros nicht laden). Namen und Felder wie geplant.

enum ChessDataModel {
    static func make() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            makeAppSettings(), makeSavedGame(), makeGameAnalysisEntry(),
            makePuzzleProgress(), makePuzzleResult(), makeLessonProgress(),
        ]
        return model
    }

    private static func entity(_ name: String, for type: NSManagedObject.Type,
                               uniqueKeys: [String] = [],
                               attributes: [NSAttributeDescription]) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = NSStringFromClass(type)
        entity.properties = attributes
        if !uniqueKeys.isEmpty { entity.uniquenessConstraints = [uniqueKeys] }
        return entity
    }

    private static func attribute(_ name: String, _ type: NSAttributeType,
                                  optional: Bool = false, def value: Any? = nil) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = value
        return attribute
    }

    private static func makeAppSettings() -> NSEntityDescription {
        entity("AppSettings", for: AppSettings.self, uniqueKeys: ["key"], attributes: [
            attribute("key", .stringAttributeType, def: "app"),
            attribute("enginePath", .stringAttributeType, optional: true),
            attribute("threads", .integer64AttributeType, def: 4),
            attribute("hashMB", .integer64AttributeType, def: 256),
            attribute("skillLevel", .integer64AttributeType, def: 20),
            attribute("limitStrength", .booleanAttributeType, def: false),
            attribute("uciElo", .integer64AttributeType, def: 2500),
            attribute("analysisDepth", .integer64AttributeType, def: 18),
            attribute("boardTheme", .stringAttributeType, def: "Grün"),
            attribute("soundEnabled", .booleanAttributeType, def: true),
            attribute("animationsEnabled", .booleanAttributeType, def: true),
        ])
    }

    private static func makeSavedGame() -> NSEntityDescription {
        entity("SavedGame", for: SavedGame.self, attributes: [
            attribute("id", .UUIDAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("whitePlayer", .stringAttributeType, def: "Weiß"),
            attribute("blackPlayer", .stringAttributeType, def: "Schwarz"),
            attribute("result", .stringAttributeType, def: "*"),
            attribute("timeControl", .stringAttributeType, def: "-"),
            attribute("openingName", .stringAttributeType, optional: true),
            attribute("pgn", .stringAttributeType, def: ""),
        ])
    }

    private static func makeGameAnalysisEntry() -> NSEntityDescription {
        entity("GameAnalysisEntry", for: GameAnalysisEntry.self, attributes: [
            attribute("id", .UUIDAttributeType),
            attribute("gameID", .UUIDAttributeType, optional: true),
            attribute("createdAt", .dateAttributeType),
            attribute("accuracyWhite", .doubleAttributeType, def: 0),
            attribute("accuracyBlack", .doubleAttributeType, def: 0),
            attribute("openingECO", .stringAttributeType, optional: true),
            attribute("openingName", .stringAttributeType, optional: true),
            attribute("analysisJSON", .binaryDataAttributeType),
        ])
    }

    private static func makePuzzleProgress() -> NSEntityDescription {
        entity("PuzzleProgress", for: PuzzleProgress.self, uniqueKeys: ["key"], attributes: [
            attribute("key", .stringAttributeType, def: "app"),
            attribute("rating", .integer64AttributeType, def: 1500),
            attribute("solvedCount", .integer64AttributeType, def: 0),
            attribute("failedCount", .integer64AttributeType, def: 0),
            attribute("currentStreak", .integer64AttributeType, def: 0),
            attribute("bestStreak", .integer64AttributeType, def: 0),
            attribute("lastSolvedAt", .dateAttributeType, optional: true),
        ])
    }

    private static func makePuzzleResult() -> NSEntityDescription {
        entity("PuzzleResult", for: PuzzleResult.self, attributes: [
            attribute("id", .UUIDAttributeType),
            attribute("puzzleID", .stringAttributeType, def: ""),
            attribute("createdAt", .dateAttributeType),
            attribute("solved", .booleanAttributeType, def: false),
            attribute("ratingAfter", .integer64AttributeType, def: 1500),
        ])
    }

    private static func makeLessonProgress() -> NSEntityDescription {
        entity("LessonProgress", for: LessonProgress.self, uniqueKeys: ["key"], attributes: [
            attribute("key", .stringAttributeType, def: "Kurs|Lektion"),
            attribute("completed", .booleanAttributeType, def: false),
            attribute("updatedAt", .dateAttributeType),
        ])
    }
}

/// App-seitige Store-Verwaltung: Container + Kontext, analog ModelContainer.
public final class PersistenceController {
    public let container: NSPersistentContainer

    public init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ChessApp", managedObjectModel: ChessDataModel.make())
        if inMemory {
            let store = NSPersistentStoreDescription()
            store.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [store]
        }
        container.loadPersistentStores { _, error in
            // DB-Fehler bewusst hart abbrechen: Für das Gerüst ist ein Crash beim
            // Anlegen des Stores aussagekräftiger als still laufende Defaults.
            if let error { fatalError("Persistent Store konnte nicht geladen werden: \(error)") }
        }
        // constraints: bei Schlüsselkonflikt gewinnt das Objekt im Speicher.
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    public var context: NSManagedObjectContext { container.viewContext }
}
