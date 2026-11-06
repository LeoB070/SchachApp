import SwiftUI

/// Einstellungen – Platzhalter bis Task 9 (Engine-Pfad, Threads, Hash, Themes, …).
struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Einstellungen").font(.title2).bold()
            Text("Engine-Pfad, Threads, Hash, Analysetiefe, Brettfarben, Sound – Task 9")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}
