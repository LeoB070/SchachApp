import SwiftUI
import CoreData
import ChessAppKit
import AppKit
import UniformTypeIdentifiers

@MainActor
final class OpeningTrainingModel: ObservableObject {
    @Published var lines: [OpeningLine] = []
    @Published var practice: OpeningPractice?
    @Published var selected: Square?
    @Published var promotion: (Square, Square)?
    @Published var error: String?
    @Published var notice: String?
    private let store = OpeningRepertoireStore()
    private var ready = false
    private var failureRecorded = false
    private var completionRecorded = false

    var dueCount: Int { lines.filter { $0.dueAt <= Date() }.count }
    var activeName: String { lines.first { $0.id == practice?.lineID }?.name ?? "Eröffnungstraining" }
    var legalTargets: Set<Square> {
        guard let practice, !practice.complete, let selected else { return [] }
        return Set(practice.position.legalMoves().filter { $0.from == selected }.map(\.to))
    }

    func load() {
        do { lines = try store.load(); ready = true; error = nil }
        catch { self.error = "Repertoire konnte nicht gelesen werden. Die Datei bleibt erhalten: \(error.localizedDescription)"; ready = false }
    }

    func add(name: String, pgn: String, color: PieceColor) -> Bool {
        guard ready else { error = "Repertoire zuerst erneut laden; vorhandene Daten werden nicht überschrieben."; return false }
        do {
            let line = try OpeningLine(name: name, pgn: pgn, color: color)
            guard !lines.contains(where: { $0.signature == line.signature }) else { error = "Diese Variante ist für diese Farbe bereits gespeichert."; return false }
            try store.save(lines + [line])
            lines.append(line); error = nil; notice = "Variante gespeichert."
            return true
        } catch { self.error = "Variante nicht gespeichert: \(error.localizedDescription)"; return false }
    }

    func remove(_ line: OpeningLine) {
        guard ready else { return }
        do {
            let remaining = lines.filter { $0.id != line.id }
            try store.save(remaining); lines = remaining
            if practice?.lineID == line.id { practice = nil; selected = nil; promotion = nil }
            error = nil
        } catch { self.error = "Löschen fehlgeschlagen: \(error.localizedDescription)" }
    }

    func start(_ line: OpeningLine) {
        do {
            practice = try OpeningPractice(line: line)
            selected = nil; promotion = nil; failureRecorded = false; completionRecorded = false; error = nil; notice = nil
        } catch { self.error = error.localizedDescription }
    }

    func tap(_ square: Square) {
        guard let practice, !practice.complete else { return }
        if let selected, let move = practice.position.move(from: selected, to: square) {
            if move.promotion != nil { promotion = (selected, square) }
            else { attempt(move) }
        } else { selected = practice.position.board[square.index]?.color == practice.color ? square : nil }
    }

    func promote(_ type: PieceType) {
        guard let practice, let (from, to) = promotion,
              let move = practice.position.move(from: from, to: to, promotion: type) else { return }
        promotion = nil; attempt(move)
    }

    func attempt(_ move: Move) {
        guard var current = practice else { return }
        current.attempt(move); practice = current; selected = nil
        recordProgress()
    }

    func hint() {
        practice?.hint()
        recordProgress()
    }

    func recordProgress() {
        guard ready, let practice, let index = lines.firstIndex(where: { $0.id == practice.lineID }) else { return }
        let failed = practice.hadError || practice.usedHint
        guard (failed && !failureRecorded) || (practice.complete && !completionRecorded) else { return }
        let alreadyScheduled = lines[index].dueAt > Date()
        var updated = lines
        updated[index].record(success: practice.complete && !failed)
        do {
            try store.save(updated); lines = updated
            if failed { failureRecorded = true }
            if practice.complete { completionRecorded = true }
            error = nil
            notice = practice.complete && !failed && alreadyScheduled ? "Zusätzliche Übung geschafft. Dein Wiederholungstermin bleibt erhalten. Ohne Rating." : practice.complete ? "Nächste Wiederholung: \(updated[index].dueAt.formatted(date: .abbreviated, time: .omitted)). Ohne Rating." : "Mit Fehler oder Hinweis: morgen erneut üben."
        } catch { self.error = "Trainingsfortschritt nicht gespeichert: \(error.localizedDescription)" }
    }
}

struct OpeningTrainingView: View {
    @StateObject private var model = OpeningTrainingModel()
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)]) private var games: FetchedResults<SavedGame>
    @LocalState private var mode = 0
    @LocalState private var importing = false
    @LocalState private var name = ""
    @LocalState private var pgn = ""
    @LocalState private var colorName = "white"
    @LocalState private var deleteLine: OpeningLine? = nil
    @LocalState private var explorerPositions: [Position] = [PGNGame().initialPosition]
    @LocalState private var explorerPGN: String? = nil
    @LocalState private var records: [OpeningGameRecord] = []

    private var ownColor: PieceColor { colorName == "black" ? .black : .white }
    private var explorerPosition: Position { explorerPositions.last ?? PGNGame().initialPosition }
    private var explorerRows: [OpeningExplorerRow] { OpeningExplorer.rows(records: records, at: explorerPosition, ownColor: ownColor) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Meine Eröffnungen").font(.largeTitle.bold())
                Text("Deine Varianten aktiv üben und eigene Partien am Brett entdecken. Alles bleibt auf diesem Mac.").foregroundStyle(.secondary)
                Picker("Bereich", selection: $mode) {
                    Text("Repertoire trainieren").tag(0)
                    Text("Eigene Partien erkunden").tag(1)
                }.pickerStyle(.segmented).frame(maxWidth: 520)
                if let error = model.error {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(error).foregroundStyle(.red).textSelection(.enabled)
                        HStack {
                            Button("Erneut laden") { model.load() }
                            Button("Fortschritt erneut speichern") { model.recordProgress() }.disabled(model.practice == nil)
                        }
                    }
                }
                if mode == 0 { repertoire } else { explorer }
            }.padding(24)
        }
        .background(AppTheme.background)
        .onAppear {
            model.load()
            records = games.map { OpeningGameRecord(id: $0.id, white: $0.whitePlayer, black: $0.blackPlayer, result: $0.result, pgn: $0.pgn) }
        }
        .sheet(isPresented: $importing) { importSheet }
        .sheet(isPresented: Binding(get: { explorerPGN != nil }, set: { if !$0 { explorerPGN = nil } })) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Beispielpartie als PGN").font(.headline)
                ScrollView { Text(explorerPGN ?? "").font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                Button("Schließen") { explorerPGN = nil }
            }.padding(24).frame(width: 650, height: 500)
        }
        .alert("Variante löschen?", isPresented: Binding(get: { deleteLine != nil }, set: { if !$0 { deleteLine = nil } })) {
            Button("Abbrechen", role: .cancel) { deleteLine = nil }
            Button("Löschen", role: .destructive) { if let line = deleteLine { model.remove(line) }; deleteLine = nil }
        } message: { Text("Die gespeicherte Variante und ihr Wiederholungsplan werden entfernt. Deine Partien bleiben erhalten.") }
    }

    private var repertoire: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(model.dueCount) Varianten fällig").font(.headline)
                Button("PGN-Variante hinzufügen") { importing = true }
                Text("Gespeicherte Linien sind dein eigener Plan, keine Enginebewertung. Auch andere legale Züge können gut sein.")
                    .font(.caption).foregroundStyle(.secondary)
                if model.lines.isEmpty { Text("Speichere zunächst eine Hauptvariante für Weiß oder Schwarz.").foregroundStyle(.secondary) }
                ForEach(model.lines.sorted { $0.dueAt < $1.dueAt }) { line in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(line.name).font(.headline)
                        Text("\(line.color == .white ? "Weiß" : "Schwarz") · \(line.dueAt <= Date() ? "Jetzt fällig" : line.dueAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("Üben") { model.start(line) }
                            Spacer()
                            Button(role: .destructive) { deleteLine = line } label: { Image(systemName: "trash") }.help("Variante löschen")
                        }
                    }.padding(12).panel()
                }
            }.frame(width: 260)
            VStack(alignment: .leading, spacing: 12) {
                if let practice = model.practice {
                    Text(model.activeName).font(.title2.bold())
                    Text("Du trainierst \(practice.color == .white ? "Weiß" : "Schwarz") · \(practice.ply) / \(practice.game.moves.count) Halbzüge")
                        .font(.caption).foregroundStyle(.secondary)
                    ZStack {
                        BoardView(position: practice.position, orientation: practice.color, legalTargets: model.legalTargets,
                                  lastMove: practice.lastMove, arrows: [], selected: model.selected, onSquareTap: model.tap)
                        if model.promotion != nil {
                            PromotionPicker(color: practice.color, onSelect: model.promote, onCancel: { model.promotion = nil })
                        }
                    }.frame(maxWidth: 540).aspectRatio(1, contentMode: .fit)
                    Text(practice.feedback).font(.headline)
                    if let notice = model.notice { Text(notice).font(.callout).foregroundStyle(.secondary) }
                    HStack {
                        Button("Hinweis") { model.hint() }.disabled(practice.complete)
                        Button("Von vorn") { if let line = model.lines.first(where: { $0.id == practice.lineID }) { model.start(line) } }
                    }
                } else {
                    ContentUnavailableView("Wähle eine Variante", systemImage: "book", description: Text("Die Gegenzüge werden automatisch gespielt. Deine Züge gibst du selbst am Brett ein."))
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var explorer: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Deine Farbe in den Partien", selection: $colorName) {
                    Text("Du als Weiß").tag("white"); Text("Du als Schwarz").tag("black")
                }.pickerStyle(.segmented)
                BoardView(position: explorerPosition, orientation: ownColor, legalTargets: [], lastMove: nil, arrows: [], selected: nil, onSquareTap: { _ in })
                    .frame(maxWidth: 520).aspectRatio(1, contentMode: .fit)
                HStack {
                    Button("Zurück") { if explorerPositions.count > 1 { explorerPositions.removeLast() } }.disabled(explorerPositions.count == 1)
                    Button("Grundstellung") { explorerPositions = [PGNGame().initialPosition] }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 12) {
                Text(explorerPosition.turn == ownColor ? "Deine Fortsetzungen" : "Antworten deiner Gegner").font(.title2.bold())
                Text("Nur Partien mit genau einem Spielernamen „Du“, gefiltert nach deiner Farbe. S/R/N gelten aus deiner Sicht; Häufigkeit belegt keine Zugqualität.")
                    .font(.caption).foregroundStyle(.secondary)
                if explorerRows.isEmpty { Text("Keine eigenen Partien mit einer Fortsetzung aus dieser Stellung.").foregroundStyle(.secondary) }
                ForEach(explorerRows) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        Button { explorerPositions.append(explorerPosition.make(row.move)) } label: {
                            HStack { Text(row.san).bold(); Spacer(); Text("\(row.count) \(row.count == 1 ? "Partie" : "Partien")") }
                        }.buttonStyle(.bordered)
                        Text("\(row.wins) S · \(row.draws) R · \(row.losses) N\(row.unfinished > 0 ? " · \(row.unfinished) offen" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                        if row.count < 5 { Text("Kleine Stichprobe").font(.caption2).foregroundStyle(.secondary) }
                        ForEach(Array(row.examples.prefix(3)), id: \.id) { record in
                            Button("\(record.white) – \(record.black) · \(record.result)") { explorerPGN = record.pgn }
                                .font(.caption).buttonStyle(.link)
                        }
                    }.padding(12).panel()
                }
            }.frame(width: 300, alignment: .leading)
        }
    }

    private var importSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Eigene Variante speichern").font(.title2.bold())
            TextField("Name der Variante", text: $name)
            Picker("Trainingsfarbe", selection: $colorName) { Text("Weiß").tag("white"); Text("Schwarz").tag("black") }.pickerStyle(.segmented)
            HStack {
                Button("PGN-Datei öffnen …") { openPGN() }
                Menu("Aus eigener Partie") {
                    ForEach(games.filter { ($0.whitePlayer == "Du") != ($0.blackPlayer == "Du") }, id: \.id) { game in
                        Button("\(game.whitePlayer) – \(game.blackPlayer) · \(game.createdAt.formatted(date: .abbreviated, time: .omitted))") {
                            pgn = game.pgn; name = game.openingName ?? "Meine Partie"; colorName = game.whitePlayer == "Du" ? "white" : "black"
                        }
                    }
                }
            }
            Text("Genau eine Partie; nur die Hauptvariante wird übernommen. Untervarianten und Kommentare werden nicht als zusätzliche Trainingslinien angelegt.")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $pgn).font(.system(.body, design: .monospaced)).frame(minHeight: 200)
            if let error = model.error { Text(error).foregroundStyle(.red).font(.caption).textSelection(.enabled) }
            HStack {
                Button("Abbrechen") { importing = false }
                Spacer()
                Button("Speichern") { if model.add(name: name, pgn: pgn, color: ownColor) { importing = false; pgn = ""; name = "" } }
                    .buttonStyle(.borderedProminent).disabled(pgn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width: 650, height: 500)
    }

    private func openPGN() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "pgn") ?? .plainText, .plainText]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do { pgn = try String(contentsOf: url, encoding: .utf8) }
            catch { model.error = "PGN nicht lesbar: \(error.localizedDescription)" }
        }
    }
}
