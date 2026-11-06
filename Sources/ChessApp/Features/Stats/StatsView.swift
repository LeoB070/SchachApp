import SwiftUI
import CoreData
import Charts
import ChessAppKit

struct StatsView: View {
    @Environment(\.managedObjectContext) private var context

    @LocalState private var totalGames: Int = 0
    @LocalState private var whiteWins: Int = 0
    @LocalState private var blackWins: Int = 0
    @LocalState private var draws: Int = 0
    @LocalState private var puzzleRating: Int = 1500
    @LocalState private var solvedPuzzles: Int = 0
    @LocalState private var currentStreak: Int = 0
    @LocalState private var bestStreak: Int = 0
    @LocalState private var puzzleHistory: [(id: UUID, date: Date, rating: Int)] = []
    @LocalState private var accuracyHistory: [(id: UUID, date: Date, white: Double, black: Double)] = []
    @LocalState private var topOpenings: [(name: String, count: Int)] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Statistiken & Fortschritt")
                    .font(.largeTitle)
                    .bold()

                // Key metrics cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    metricCard(title: "Partien gesamt", value: "\(totalGames)", icon: "gamecontroller.fill", color: .blue)
                    metricCard(title: "Puzzle-Rating", value: "\(puzzleRating)", icon: "brain.head.profile", color: .purple)
                    metricCard(title: "Puzzles gelöst", value: "\(solvedPuzzles)", icon: "checkmark.seal.fill", color: .green)
                    metricCard(title: "Beste Serie", value: "\(bestStreak) 🔥", icon: "flame.fill", color: .orange)
                }

                // Games summary
                GroupBox("Partie-Ergebnisse") {
                    if totalGames == 0 {
                        Text("Noch keine Partien gespielt. Starte eine Partie im Bereich 'Spielen'!")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        HStack(spacing: 30) {
                            resultItem(label: "Weiß-Siege", count: whiteWins, total: totalGames, color: .white)
                            resultItem(label: "Remis", count: draws, total: totalGames, color: .gray)
                            resultItem(label: "Schwarz-Siege", count: blackWins, total: totalGames, color: .black)
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Puzzle Rating Chart
                GroupBox("Puzzle-Rating-Verlauf") {
                    if puzzleHistory.isEmpty {
                        Text("Noch keine Puzzle-Daten vorhanden. Löse Puzzles im Bereich 'Puzzles'!")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        Chart {
                            ForEach(Array(puzzleHistory.enumerated()), id: \.offset) { index, item in
                                LineMark(
                                    x: .value("Nummer", index + 1),
                                    y: .value("Rating", item.rating)
                                )
                                .foregroundStyle(SwiftUI.Color.purple)
                                PointMark(
                                    x: .value("Nummer", index + 1),
                                    y: .value("Rating", item.rating)
                                )
                                .foregroundStyle(SwiftUI.Color.purple)
                            }
                        }
                        .frame(height: 180)
                        .padding(.vertical, 8)
                    }
                }

                GroupBox("Accuracy-Verlauf") {
                    if accuracyHistory.isEmpty {
                        Text("Noch keine Partie analysiert.").foregroundStyle(.secondary)
                    } else {
                        Chart {
                            ForEach(accuracyHistory, id: \.id) { item in
                                LineMark(x: .value("Datum", item.date), y: .value("Accuracy", item.white))
                                    .foregroundStyle(by: .value("Seite", "Weiß"))
                                LineMark(x: .value("Datum", item.date), y: .value("Accuracy", item.black))
                                    .foregroundStyle(by: .value("Seite", "Schwarz"))
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 180)
                    }
                }

                // Most played openings
                GroupBox("Häufigste Eröffnungen") {
                    if topOpenings.isEmpty {
                        Text("Noch keine Eröffnungsdaten gespeichert.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(topOpenings, id: \.name) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.body)
                                    Spacer()
                                    Text("\(item.count) \(item.count == 1 ? "Partie" : "Partien")")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Divider()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(24)
        }
        .onAppear { loadStats() }
    }

    private func metricCard(title: String, value: String, icon: String, color: SwiftUI.Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title)
                .bold()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(SwiftUI.Color.secondary.opacity(0.1)))
    }

    private func resultItem(label: String, count: Int, total: Int, color: SwiftUI.Color) -> some View {
        let percent = total > 0 ? (Double(count) / Double(total)) * 100 : 0
        return VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2).bold()
            Text(String(format: "%.0f%%", percent))
                .font(.caption).foregroundStyle(.secondary)
            Text(label)
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func loadStats() {
        let gamesReq: NSFetchRequest<SavedGame> = NSFetchRequest(entityName: "SavedGame")
        if let games = try? context.fetch(gamesReq) {
            totalGames = games.count
            whiteWins = games.filter { $0.result == "1-0" }.count
            blackWins = games.filter { $0.result == "0-1" }.count
            draws = games.filter { $0.result == "1/2-1/2" }.count

            var openingCounts: [String: Int] = [:]
            for g in games {
                if let name = g.openingName, !name.isEmpty {
                    openingCounts[name, default: 0] += 1
                }
            }
            topOpenings = openingCounts.sorted { $0.value > $1.value }.prefix(5).map { (name: $0.key, count: $0.value) }
        }

        let analyses: NSFetchRequest<GameAnalysisEntry> = NSFetchRequest(entityName: "GameAnalysisEntry")
        analyses.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        analyses.fetchLimit = 30
        accuracyHistory = ((try? context.fetch(analyses)) ?? []).reversed().map {
            (id: $0.id, date: $0.createdAt, white: $0.accuracyWhite, black: $0.accuracyBlack)
        }

        let pProg = PuzzleProgress.fetchOrCreate(context: context)
        puzzleRating = Int(pProg.rating)
        solvedPuzzles = Int(pProg.solvedCount)
        currentStreak = Int(pProg.currentStreak)
        bestStreak = Int(pProg.bestStreak)

        let pResReq: NSFetchRequest<PuzzleResult> = NSFetchRequest(entityName: "PuzzleResult")
        pResReq.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        pResReq.fetchLimit = 30
        if let results = try? context.fetch(pResReq) {
            puzzleHistory = results.reversed().map { (id: $0.id, date: $0.createdAt, rating: Int($0.ratingAfter)) }
        }
    }
}
