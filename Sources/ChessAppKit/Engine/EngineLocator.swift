import Foundation

/// Sucht und lokalisiert das ausführbare Stockfish-Binary im Dateisystem oder App-Bundle.
public enum EngineLocator {
    /// Standardpfade für Stockfish auf macOS-Systemen.
    public static let standardSystemPaths: [String] = [
        "/opt/homebrew/bin/stockfish",
        "/usr/local/bin/stockfish",
        "/usr/bin/stockfish"
    ]

    /// Sucht nach der Engine in folgender Prioritätsreihenfolge:
    /// 1. App-Bundle-Ressource "stockfish" (in Bundle.main oder Bundle.module)
    /// 2. Benutzerdefinierter Pfad aus Einstellungen (falls angegeben und vorhanden)
    /// 3. `/opt/homebrew/bin/stockfish`
    /// 4. `/usr/local/bin/stockfish`
    /// 5. `/usr/bin/stockfish`
    ///
    /// - Parameters:
    ///   - customPath: Ein optionaler Pfad aus den App-Einstellungen.
    ///   - fileManager: Der zu verwendende FileManager (Standard: `.default`).
    /// - Returns: Der absolute Pfad zum ausführbaren Binary oder `nil`, falls nicht gefunden.
    public static func locateEngine(
        customPath: String? = nil,
        fileManager: FileManager = .default
    ) -> String? {
        // a) Bundle resource "stockfish"
        if let bundlePath = findInBundles(fileManager: fileManager) {
            return bundlePath
        }

        // b) Custom settings path
        if let custom = customPath?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            if isUsableExecutable(atPath: custom, fileManager: fileManager) {
                return custom
            }
        }

        // c, d, e) Standard System Paths
        for sysPath in standardSystemPaths {
            if isUsableExecutable(atPath: sysPath, fileManager: fileManager) {
                return sysPath
            }
        }

        return nil
    }

    private static func findInBundles(fileManager: FileManager) -> String? {
        // Prüfe Bundle.main
        if let path = Bundle.main.path(forResource: "stockfish", ofType: nil),
           isUsableExecutable(atPath: path, fileManager: fileManager) {
            return path
        }
        if let path = Bundle.main.path(forResource: "stockfish", ofType: nil, inDirectory: "Stockfish"),
           isUsableExecutable(atPath: path, fileManager: fileManager) {
            return path
        }

        // Prüfe Bundle.module (SPM Resources)
        #if SWIFT_PACKAGE
        if let path = ChessAppKitInfo.resourceBundle.path(forResource: "stockfish", ofType: nil),
           isUsableExecutable(atPath: path, fileManager: fileManager) {
            return path
        }
        if let path = ChessAppKitInfo.resourceBundle.path(forResource: "stockfish", ofType: nil, inDirectory: "Stockfish"),
           isUsableExecutable(atPath: path, fileManager: fileManager) {
            return path
        }
        #endif

        return nil
    }

    /// Prüft, ob an dem Pfad eine reguläre Datei liegt, die ausführbar ist (oder existiert).
    public static func isUsableExecutable(atPath path: String, fileManager: FileManager = .default) -> Bool {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
            return false
        }
        return fileManager.isExecutableFile(atPath: path)
    }
}

/// Globale Hilfsfunktion zur Lokalisierung der Engine.
public func locateEngine(customPath: String? = nil) -> String? {
    EngineLocator.locateEngine(customPath: customPath)
}
