import SwiftUI
import CoreData
import ChessAppKit

struct TrainingDashboardView: View {
    var showDetails = false
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)]) private var results: FetchedResults<PuzzleResult>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)]) private var games: FetchedResults<SavedGame>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)]) private var analyses: FetchedResults<GameAnalysisEntry>
    @LocalState private var puzzles: [PuzzleItem] = []
    @LocalState private var due = 0
    @LocalState private var loadError: String? = nil
    @LocalState private var destination: Destination? = nil

    private enum Destination: Identifiable {
        case due, topic(String), personal, openings, endgames
        var id: String {
            switch self {
            case .due: return "due"
            case .topic(let theme): return "topic-" + theme
            case .personal: return "personal"
            case .openings: return "openings"
            case .endgames: return "endgames"
            }
        }
    }

    private var themeProgress: [TrainingInsights.ThemeProgress] {
        let map = Dictionary(puzzles.map { ($0.id, $0.themes) }, uniquingKeysWith: { first, _ in first })
        return TrainingInsights.themes(results: Array(results.prefix(300)), themesByPuzzle: map)
    }
    private var phases: [TrainingInsights.PhaseProgress] {
        TrainingInsights.phases(games: Array(games), entries: Array(analyses.prefix(100)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Dein nächster Trainingsschritt", systemImage: "target").font(.title3.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 235), spacing: 16)], alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(due == 0 ? "Heute nichts fällig" : "\(due) Aufgaben warten auf dich").font(.headline)
                    Text("Gelöste und schwierige Aufgaben kommen mit Abstand wieder. Wiederholungen bleiben ohne Rating.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Heute wiederholen") { destination = .due }
                        .buttonStyle(.bordered).disabled(due == 0 || loadError != nil)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 8) {
                    if let item = TrainingInsights.recommendedTheme(in: themeProgress) {
                        Text(PuzzleViewModel.themeTitle(item.theme) + " vertiefen").font(.headline)
                        Text("\(item.failed) von \(item.attempts) erfassten Versuchen nicht gelöst.\(item.attempts < 10 ? " Noch eine kleine Stichprobe." : "")")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Passende Aufgaben üben") { destination = .topic(item.theme) }.buttonStyle(.bordered)
                    } else {
                        Text("Ein Muster nach dem anderen").font(.headline)
                        Text("Mit mehr Puzzleversuchen werden deine Empfehlungen persönlicher. Beginne mit einer kurzen Taktikrunde.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Taktik üben") { destination = .topic("") }.buttonStyle(.bordered)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if !themeProgress.isEmpty {
                Text("Basis: bis zu 300 zuletzt erfasste Puzzleversuche, inklusive Hilfen und Wiederholungen. Themen können sich überschneiden; das ist eine Übungsempfehlung, keine Spielstärkemessung.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if showDetails {
                ForEach(themeProgress) { item in
                    HStack {
                        Text(PuzzleViewModel.themeTitle(item.theme))
                        Spacer()
                        Text("\(item.attempts - item.failed)/\(item.attempts) gelöst").foregroundStyle(.secondary)
                        Button("Üben") { destination = .topic(item.theme) }
                    }.font(.callout)
                }
            }
            if !phases.isEmpty {
                Divider()
                Text("Aus deinen analysierten Partien").font(.headline)
                ForEach(phases) { item in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.phase.rawValue).font(.callout.bold())
                            Text("\(item.errors) deutliche Bewertungsverluste bei \(item.moves) eigenen Zügen aus \(item.games) Partien.\(item.games < 3 ? " Kleine Stichprobe." : "")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Trainieren") {
                            switch item.phase {
                            case .opening: destination = .openings
                            case .middlegame: destination = .personal
                            case .endgame: destination = .endgames
                            }
                        }.buttonStyle(.bordered)
                    }
                }
                Text("Nur Spielername „Du“ und der neueste Bericht je Partie; deutlicher Verlust = mindestens 10 Prozentpunkte Gewinnchance laut Analyse. Keine automatische Diagnose taktischer Motive.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let loadError { Text(loadError).font(.caption).foregroundStyle(.red) }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading).panel()
        .onAppear(perform: reload)
        .sheet(item: $destination, onDismiss: reload) { target in
            VStack(spacing: 0) {
                HStack { Text("Dein Training").font(.headline); Spacer(); Button("Schließen") { destination = nil } }.padding()
                switch target {
                case .due: PuzzleView(initialReview: true)
                case .topic(let theme): PuzzleView(initialTheme: theme)
                case .personal: PuzzleView(initialSource: .personal)
                case .openings: OpeningTrainingView()
                case .endgames: EndgameTrainingView()
                }
            }.frame(minWidth: 960, minHeight: 680)
        }
    }

    private func reload() {
        loadError = nil
        do {
            guard let url = ChessAppKitInfo.resourceBundle.url(forResource: "puzzles", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            puzzles = try JSONDecoder().decode([PuzzleItem].self, from: Data(contentsOf: url)) + PersonalPuzzleStore.load()
            let available = Set(puzzles.map(\.id))
            let now = Date()
            due = try PuzzleReviewStore.load().entries.filter { available.contains($0.key) && $0.value.dueAt <= now }.count
        } catch {
            due = 0
            loadError = "Trainingsübersicht konnte nicht vollständig geladen werden: \(error.localizedDescription)"
        }
    }
}
