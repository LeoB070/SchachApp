import SwiftUI

@main
struct AppearanceChecks {
    static func main() {
        precondition(AppTheme.colorScheme("Hell") == .light)
        precondition(AppTheme.colorScheme("Dunkel") == .dark)
        precondition(AppTheme.colorScheme("System") == nil)
        precondition(AppTheme.colorScheme("unbekannt") == nil)
        precondition(Set(AppTheme.themes).count == AppTheme.themes.count)
        for legacy in ["Grün", "Blau", "Holz"] {
            precondition(AppTheme.themes.contains(legacy), "Gespeichertes Thema fehlt: \(legacy)")
        }
        for theme in AppTheme.themes {
            precondition(AppTheme.lightSquare(theme) != AppTheme.darkSquare(theme))
        }
        precondition(AppTheme.lightSquare("unbekannt") == AppTheme.lightSquare("Grün"))
        precondition(AppTheme.darkSquare("unbekannt") == AppTheme.darkSquare("Grün"))
        print("Appearance checks passed: modes, legacy themes, contrasting palettes and fallback")
    }
}
