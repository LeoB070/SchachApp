import SwiftUI
import CoreData
import UniformTypeIdentifiers
import ChessAppKit

struct GameArchiveView: View {
    @Environment(\.managedObjectContext) private var context

    @LocalState private var games: [SavedGame] = []
    @LocalState private var searchText: String = ""
    @LocalState private var filterResult: String = "Alle"
    @LocalState private var selectedGame: SavedGame? = nil
    @LocalState private var showImportSheet: Bool = false
    @LocalState private var importedPGNText: String = ""
    @LocalState private var showExportAlert: Bool = false
    @LocalState private var exportMessage: String = ""

    @LocalState private var reviewGame: SavedGame?
    @LocalState private var showReview = false
    @LocalState private var filterDate: Date = Date()
    @LocalState private var useDateFilter = false

    private let filterOptions = ["Alle", "1-0", "0-1", "1/2-1/2"]

    var filteredGames: [SavedGame] {
        games.filter { game in
            let matchesFilter = filterResult == "Alle" || game.result == filterResult
            let matchesSearch = searchText.isEmpty ||
                game.whitePlayer.localizedCaseInsensitiveContains(searchText) ||
                game.blackPlayer.localizedCaseInsensitiveContains(searchText) ||
                (game.openingName?.localizedCaseInsensitiveContains(searchText) ?? false)
            return matchesFilter && matchesSearch && (!useDateFilter || Calendar.current.isDate(game.createdAt, inSameDayAs: filterDate))
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 8) {
                    TextField("Suche nach Spieler oder Eröffnung...", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Ergebnis", selection: $filterResult) {
                            ForEach(filterOptions, id: \.self) { opt in
                                Text(opt).tag(opt)
                            }
                        }
                        .pickerStyle(.segmented)

                        Button(action: { showImportSheet = true }) {
                            Label("PGN Import", systemImage: "square.and.arrow.down")
                        }
                    }
                }
                .padding()
                HStack {
                    Toggle("Datum", isOn: $useDateFilter)
                    if useDateFilter { DatePicker("Datum", selection: $filterDate, displayedComponents: .date).labelsHidden() }
                    Spacer()
                }.padding(.horizontal).padding(.bottom, 8)

                Divider()

                if filteredGames.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("Keine Partien gefunden")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredGames, id: \.id, selection: $selectedGame) { game in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(game.whitePlayer) vs. \(game.blackPlayer)")
                                    .font(.headline)
                                Spacer()
                                Text(game.result)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .bold()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(SwiftUI.Color.secondary.opacity(0.15)))
                            }

                            HStack {
                                if let opening = game.openingName, !opening.isEmpty {
                                    Text(opening)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formattedDate(game.createdAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .tag(game)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteGame(game)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                            Button {
                                copyPGN(game)
                            } label: {
                                Label("PGN kopieren", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Archiv")
            .frame(width: 310)
            Divider()
            Group {
                if let game = selectedGame {
                    gameDetailView(game)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Wähle eine Partie aus der Liste")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .onAppear { loadGames() }
        .sheet(isPresented: $showImportSheet) {
            importSheetView
        }
        .sheet(isPresented: $showReview) {
            VStack {
                HStack { Spacer(); Button("Schließen") { showReview = false } }.padding()
                ReviewView(game: reviewGame)
            }.frame(minWidth: 1000, minHeight: 700)
        }
        .alert("Archiv", isPresented: $showExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage)
        }
    }

    @ViewBuilder
    private func gameDetailView(_ game: SavedGame) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(game.whitePlayer) – \(game.blackPlayer)")
                            .font(.title2).bold()
                        Text("Ergebnis: \(game.result) • Zeit: \(game.timeControl) • Datum: \(formattedDate(game.createdAt))")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if let op = game.openingName {
                            Text("Eröffnung: \(op)")
                                .font(.callout)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    HStack {
                        Button("Analysieren") { reviewGame = game; showReview = true }
                        Button("PGN exportieren") { exportPGN(game) }
                    }
                    HStack {
                        Button { copyPGN(game) } label: {
                            Label("PGN kopieren", systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive) { deleteGame(game) } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("PGN-Notation").font(.headline)
                    Text(game.pgn.isEmpty ? "Kein PGN-Text vorhanden." : game.pgn)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(SwiftUI.Color.secondary.opacity(0.08)))
                }
            }
            .padding(24)
        }
    }

    private var importSheetView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PGN importieren").font(.title2).bold()
            Text("Füge hier den PGN-Text einer Partie ein:")
                .font(.subheadline).foregroundStyle(.secondary)

            Button("PGN-Datei öffnen …") { openPGNFile() }

            TextEditor(text: $importedPGNText)
                .font(.system(.body, design: .monospaced))
                .border(SwiftUI.Color.secondary.opacity(0.3))
                .frame(minHeight: 200)

            HStack {
                Button("Abbrechen") {
                    showImportSheet = false
                    importedPGNText = ""
                }
                Spacer()
                Button("Importieren") {
                    importPGN()
                }
                .buttonStyle(.borderedProminent)
                .disabled(importedPGNText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500, height: 380)
    }

    private func loadGames() {
        let req: NSFetchRequest<SavedGame> = NSFetchRequest(entityName: "SavedGame")
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        do {
            let items = try context.fetch(req)
            games = items
            if selectedGame == nil {
                selectedGame = items.first
            }
        } catch { report(error) }
    }

    private func deleteGame(_ game: SavedGame) {
        do {
            let request = NSFetchRequest<GameAnalysisEntry>(entityName: "GameAnalysisEntry")
            request.predicate = NSPredicate(format: "gameID == %@", game.id as NSUUID)
            for analysis in try context.fetch(request) { context.delete(analysis) }
            context.delete(game)
            try context.save()
        } catch { context.rollback(); report(error); return }
        loadGames()
        if selectedGame == game {
            selectedGame = games.first
        }
    }

    private func copyPGN(_ game: SavedGame) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(game.pgn, forType: .string)
        exportMessage = "PGN wurde in die Zwischenablage kopiert!"
        showExportAlert = true
    }

    private func importPGN() {
        let text = importedPGNText.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let parsed = try PGN.parseMany(text)
            guard !parsed.isEmpty, parsed.allSatisfy({ !$0.moves.isEmpty || $0.tag("Result") != nil || $0.tag("FEN") != nil }) else {
                exportMessage = "Keine lesbare PGN-Partie gefunden."; showExportAlert = true; return
            }
            var inserted: [SavedGame] = []
            for item in parsed {
                let game = SavedGame(context: context)
                game.pgn = PGN.export(item)
                game.whitePlayer = item.tag("White") ?? "Weiß"
                game.blackPlayer = item.tag("Black") ?? "Schwarz"
                game.result = item.result
                game.timeControl = item.tag("TimeControl") ?? "-"
                game.openingName = item.tag("Opening")
                inserted.append(game)
            }
            do { try context.save() }
            catch { inserted.forEach { context.delete($0) }; throw error }
            selectedGame = inserted.first
            showImportSheet = false; importedPGNText = ""; loadGames()
        } catch { report(error) }
    }

    private func openPGNFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "pgn") ?? .plainText, .plainText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { importedPGNText = try String(contentsOf: url, encoding: .utf8) }
        catch { report(error) }
    }

    private func exportPGN(_ game: SavedGame) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Partie.pgn"
        panel.allowedContentTypes = [UTType(filenameExtension: "pgn") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try game.pgn.write(to: url, atomically: true, encoding: .utf8) }
        catch { report(error) }
    }

    private func report(_ error: Error) {
        exportMessage = error.localizedDescription
        showExportAlert = true
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
