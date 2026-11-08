import SwiftUI

enum AppTheme {
    static let accent = adaptive(light: (0.30, 0.43, 0.23), dark: (0.65, 0.79, 0.41))
    static let background = adaptive(light: (0.96, 0.95, 0.92), dark: (0.12, 0.13, 0.11))
    static let surface = adaptive(light: (1.0, 0.99, 0.96), dark: (0.18, 0.19, 0.16))
    static let sidebar = adaptive(light: (0.91, 0.91, 0.85), dark: (0.15, 0.16, 0.13))
    static let gold = SwiftUI.Color(red: 0.88, green: 0.66, blue: 0.27)

    private static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> SwiftUI.Color {
        SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }

    static let themes = ["Grün", "Blau", "Holz", "Walnuss", "Schiefer"]
    static let pieceThemes = ["Klassisch", "Walnuss", "Ozean"]
    static let appearances = ["System", "Hell", "Dunkel"]

    static func colorScheme(_ appearance: String) -> ColorScheme? {
        switch appearance {
        case "Hell": return .light
        case "Dunkel": return .dark
        default: return nil
        }
    }

    static func lightSquare(_ name: String) -> SwiftUI.Color {
        switch name {
        case "Blau": return SwiftUI.Color(red: 0.90, green: 0.93, blue: 0.98)
        case "Holz": return SwiftUI.Color(red: 0.94, green: 0.87, blue: 0.75)
        case "Walnuss": return SwiftUI.Color(red: 0.89, green: 0.80, blue: 0.67)
        case "Schiefer": return SwiftUI.Color(red: 0.88, green: 0.90, blue: 0.91)
        default:     return SwiftUI.Color(red: 0.92, green: 0.91, blue: 0.82)
        }
    }

    static func darkSquare(_ name: String) -> SwiftUI.Color {
        switch name {
        case "Blau": return SwiftUI.Color(red: 0.45, green: 0.61, blue: 0.71)
        case "Holz": return SwiftUI.Color(red: 0.71, green: 0.53, blue: 0.40)
        case "Walnuss": return SwiftUI.Color(red: 0.48, green: 0.33, blue: 0.25)
        case "Schiefer": return SwiftUI.Color(red: 0.42, green: 0.47, blue: 0.51)
        default:     return SwiftUI.Color(red: 0.47, green: 0.58, blue: 0.41)
        }
    }
}

/// Gemeinsame Kartenoptik für Seitenpanels (Zugliste, Status, Statistik).
struct PanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.accent.opacity(0.16), lineWidth: 1))
    }
}

extension View {
    func panel() -> some View { modifier(PanelStyle()) }
}
