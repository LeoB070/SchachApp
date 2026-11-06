import SwiftUI

/// Brett-Farbschemata (Themes). Drei fest vorgegebene, später in den Einstellungen wählbar.
enum AppTheme {
    static let themes = ["Grün", "Blau", "Holz"]

    static func lightSquare(_ name: String) -> SwiftUI.Color {
        switch name {
        case "Blau": return SwiftUI.Color(red: 0.90, green: 0.93, blue: 0.98)
        case "Holz": return SwiftUI.Color(red: 0.96, green: 0.85, blue: 0.70)
        default:     return SwiftUI.Color(red: 0.92, green: 0.91, blue: 0.82)
        }
    }

    static func darkSquare(_ name: String) -> SwiftUI.Color {
        switch name {
        case "Blau": return SwiftUI.Color(red: 0.45, green: 0.61, blue: 0.71)
        case "Holz": return SwiftUI.Color(red: 0.71, green: 0.53, blue: 0.40)
        default:     return SwiftUI.Color(red: 0.47, green: 0.58, blue: 0.41)
        }
    }
}
