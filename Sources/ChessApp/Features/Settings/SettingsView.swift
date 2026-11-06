import SwiftUI
import CoreData
import ChessAppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("ChessApp")
                .font(.title)
                .bold()

            Text("Version 1.0.0 – Native macOS Schach-App")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Lizenzen & Open Source Hinweise:")
                    .font(.headline)

                Text("• **Stockfish Engine:** Verwendet die Stockfish Chess Engine, lizenziert unter der **GNU General Public License v3 (GPLv3)**.")
                    .font(.callout)
                Link("Stockfish Quellcode auf GitHub", destination: URL(string: "https://github.com/official-stockfish/Stockfish")!)
                    .font(.callout)

                Text("• **Eröffnungen, Puzzles & Lektionen:** Kleine lokale Beispielsammlung für diese App.")
                    .font(.callout)

                Text("• **Markenhinweis:** Diese Anwendung ist unabhängig und steht in keiner Verbindung zu Chess.com oder anderen kommerziellen Anbietern. Es werden keine proprietären Marken oder Grafiken Dritter genutzt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(SwiftUI.Color.secondary.opacity(0.08)))

            Spacer()

            Button("Schließen") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 480, height: 440)
    }
}

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var context
    @LocalState private var enginePath: String = ""
    @LocalState private var threads: Int = 4
    @LocalState private var hashMB: Int = 256
    @LocalState private var analysisDepth: Int = 18
    @LocalState private var boardTheme: String = "Grün"
    @LocalState private var soundEnabled: Bool = true
    @LocalState private var animationsEnabled: Bool = true
    @LocalState private var showAbout: Bool = false
    @LocalState private var isLoaded: Bool = false
    @LocalState private var saveError: String?

    private let themes = ["Grün", "Blau", "Holz"]

    var body: some View {
        Form {
            Section("Engine (Stockfish)") {
                HStack {
                    TextField("Pfad zur Engine", text: $enginePath)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { save() }
                        .onChange(of: enginePath) { save() }
                    Button("Standard") {
                        enginePath = "/opt/homebrew/bin/stockfish"
                        save()
                    }
                }
                Text("Standardpfad: /opt/homebrew/bin/stockfish (Installation: brew install stockfish)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stepper("Threads: \(threads)", value: $threads, in: 1...32)
                    .onChange(of: threads) { save() }

                Stepper("Hash-Speicher: \(hashMB) MB", value: $hashMB, in: 16...4096, step: 64)
                    .onChange(of: hashMB) { save() }

                Stepper("Standard-Analysetiefe: \(analysisDepth)", value: $analysisDepth, in: 10...30)
                    .onChange(of: analysisDepth) { save() }
            }

            Section("Darstellung & Verhalten") {
                Picker("Brett-Thema", selection: $boardTheme) {
                    ForEach(themes, id: \.self) { theme in
                        Text(theme).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: boardTheme) { save() }

                Toggle("Tonsignale aktivieren", isOn: $soundEnabled)
                    .onChange(of: soundEnabled) { save() }

                Toggle("Zug-Animationen aktivieren", isOn: $animationsEnabled)
                    .onChange(of: animationsEnabled) { save() }
            }

            Section("Über die App") {
                Button("Lizenzen, Stockfish GPLv3 & Quellennachweise…") {
                    showAbout = true
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Einstellungen")
        .onAppear { load() }
        .alert("Einstellungen nicht gespeichert", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) { Button("OK") { saveError = nil } } message: { Text(saveError ?? "") }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
    }

    private func load() {
        guard !isLoaded else { return }
        let settings = AppSettings.fetchOrCreate(context: context)
        enginePath = settings.enginePath ?? "/opt/homebrew/bin/stockfish"
        threads = Int(settings.threads)
        hashMB = Int(settings.hashMB)
        analysisDepth = Int(settings.analysisDepth)
        boardTheme = settings.boardTheme.isEmpty ? "Grün" : settings.boardTheme
        soundEnabled = settings.soundEnabled
        animationsEnabled = settings.animationsEnabled
        isLoaded = true
    }

    private func save() {
        guard isLoaded else { return }
        let settings = AppSettings.fetchOrCreate(context: context)
        settings.enginePath = enginePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : enginePath
        settings.threads = Int64(threads)
        settings.hashMB = Int64(hashMB)
        settings.analysisDepth = Int64(analysisDepth)
        settings.boardTheme = boardTheme
        settings.soundEnabled = soundEnabled
        settings.animationsEnabled = animationsEnabled
        do {
            try context.save()
            UserDefaults.standard.set(boardTheme, forKey: "boardTheme")
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
            UserDefaults.standard.set(animationsEnabled, forKey: "animationsEnabled")
        } catch { saveError = error.localizedDescription }
    }
}
