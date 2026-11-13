// ChessAppKit – Bibliothek mit Core/Engine/Analysis/Bots/Persistence.
// Siehe Plan: docs/superpowers/plans/2026-11-06-chessapp-skeleton.md
import Foundation

public enum ChessAppKitInfo {
    public static var resourceBundle: Bundle {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("ChessApp_ChessAppKit.bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return .module
    }
    /// Validierung, dass das Kit-Modul korrekt verlinkt.
    public static let version = "1.1.0"
}
