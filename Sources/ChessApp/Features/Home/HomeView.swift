import SwiftUI
import CoreData
import ChessAppKit

struct HomeView: View {
    @ObservedObject var playViewModel: PlayViewModel
    let navigate: (RootView.SidebarItem) -> Void
    let openPersonalPuzzles: () -> Void
    let chooseBot: (Bot) -> Void
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)]) private var games: FetchedResults<SavedGame>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)]) private var analyses: FetchedResults<GameAnalysisEntry>
    @FetchRequest(sortDescriptors: []) private var progress: FetchedResults<PuzzleProgress>
    @LocalState private var reviewGame: SavedGame? = nil
    @LocalState private var showReview = false

    private var lastOwnGame: SavedGame? { games.first { ClubProgress.ownSide(in: $0) != nil } }
    private var activeGame: Bool { playViewModel.result == "*" && !playViewModel.sans.isEmpty }
    private var personalPractice: (game: SavedGame, moves: [MoveAnalysis])? {
        var seen: Set<UUID> = []
        for entry in analyses.prefix(30) {
            guard let id = entry.gameID, seen.insert(id).inserted,
                  let game = games.first(where: { $0.id == id }),
                  let report = try? JSONDecoder().decode(GameAnalysis.self, from: entry.analysisJSON) else { continue }
            let moves = ClubProgress.practiceMoves(in: report, for: game)
            if !moves.isEmpty { return (game, moves) }
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("DEIN SCHACHCLUB").font(.caption.weight(.bold)).tracking(2).foregroundStyle(AppTheme.accent)
                        Text("Schön, dass du da bist.").font(.system(size: 32, weight: .bold, design: .serif))
                        Text("Ein guter Zug. Eine neue Idee. Dein nächster Schritt.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "sun.max.fill").font(.system(size: 30)).foregroundStyle(AppTheme.gold)
                        .accessibilityHidden(true)
                }
                hero
                TrainingDashboardView()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 235), spacing: 16)], alignment: .leading, spacing: 16) {
                    trainingCard(title: "Deine zweite Chance", eyebrow: "AUS DEINEN PARTIEN", icon: "arrow.uturn.backward", color: AppTheme.gold,
                                 message: personalPractice.map { "\($0.moves.count) \($0.moves.count == 1 ? "Stelle" : "Stellen") zum Nachprüfen. Stockfish wählt daraus eindeutige Aufgaben für dich aus." }
                                    ?? "Deine Partien werden zu deinem Training. Analysiere ein Spiel, um verpasste Chancen wiederzufinden.",
                                 action: personalPractice == nil ? "Partie auswählen" : "Eigene Chancen trainieren") {
                        if personalPractice != nil { openPersonalPuzzles() } else { navigate(.archive) }
                    }
                    trainingCard(title: "Kurz aufwärmen", eyebrow: "TAKTIKTRAINING", icon: "puzzlepiece.extension.fill", color: AppTheme.accent,
                                 message: "Entdecke Muster, rechne Kombinationen und nimm eine neue Idee mit in deine nächste Partie.", action: "Puzzles entdecken") { navigate(.puzzles) }
                    trainingCard(title: "Ein Aha-Moment", eyebrow: "SCHRITT FÜR SCHRITT", icon: "lightbulb.fill", color: .orange,
                                 message: "Vom ersten Matt bis zum Endspiel: kleine Lektionen, die du direkt auf dem Brett ausprobieren kannst.", action: "Weiterlernen") { navigate(.lessons) }
                }
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Deine letzte Partie", systemImage: "clock.arrow.circlepath").font(.headline)
                        if let game = lastOwnGame {
                            HStack(alignment: .top, spacing: 14) {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text("\(game.whitePlayer) · \(game.blackPlayer)").font(.title3.weight(.semibold))
                                    Text(game.openingName ?? "Jede Partie erzählt eine Geschichte.").font(.callout).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                if let position = (try? PGN.parse(game.pgn))?.positions.last {
                                    BoardView(position: position, orientation: ClubProgress.ownSide(in: game) ?? .white,
                                              legalTargets: [], lastMove: nil, arrows: [], selected: nil, onSquareTap: { _ in })
                                        .frame(width: 100, height: 100).allowsHitTesting(false).accessibilityHidden(true)
                                }
                            }
                            HStack {
                                Text(game.result).font(.system(.headline, design: .monospaced))
                                Text(game.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button("Gemeinsam ansehen") { reviewGame = game; showReview = true }.buttonStyle(.bordered)
                            }
                        } else {
                            Text("Deine Geschichte beginnt am Brett.").font(.title3.weight(.semibold))
                            Text("Spiele deine erste Partie. Danach entdecken wir gemeinsam die entscheidenden Momente.")
                                .font(.callout).foregroundStyle(.secondary)
                            Button("Erste Partie spielen") { navigate(.play) }.buttonStyle(.bordered)
                        }
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).panel()
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Du bleibst dran", systemImage: "flame.fill").font(.headline).foregroundStyle(AppTheme.gold)
                        Text("\(progress.first?.solvedCount ?? 0)").font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Puzzles gelöst · \(progress.first?.currentStreak ?? 0) in Folge").font(.caption).foregroundStyle(.secondary)
                        Button("Deinen Fortschritt ansehen") { navigate(.stats) }.buttonStyle(.link)
                    }.padding(20).frame(width: 225, alignment: .leading).panel()
                }
                clubOpponents
            }
            .padding(30)
            .frame(maxWidth: 1180, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showReview) {
            VStack {
                HStack { Text("Dein Partierückblick").font(.headline); Spacer(); Button("Schließen") { showReview = false } }.padding()
                ReviewView(game: reviewGame)
            }.frame(minWidth: 1000, minHeight: 700)
        }
    }

    private var hero: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text(activeGame ? "Dein Brett wartet auf dich." : "Zeit für eine gute Partie.")
                    .font(.system(size: 27, weight: .bold, design: .serif))
                Text(activeGame ? "Du spielst gegen \(playViewModel.activeBot.name). Dein letzter Zug bleibt an seinem Platz."
                     : "\(playViewModel.activeBot.name) ist bereit. Spiel entspannt, probier etwas aus und finde deinen eigenen Plan.")
                    .font(.callout).foregroundStyle(.white.opacity(0.80)).fixedSize(horizontal: false, vertical: true)
                Button {
                    if playViewModel.result != "*" { chooseBot(playViewModel.activeBot) }
                    else { navigate(.play) }
                } label: {
                    Label(activeGame ? "Partie fortsetzen" : (playViewModel.result != "*" ? "Neue Runde vorbereiten" : "Ans Brett"), systemImage: "play.fill")
                        .font(.headline).padding(.horizontal, 18).padding(.vertical, 12)
                        .foregroundStyle(.black)
                        .background(SwiftUI.Color(red: 0.70, green: 0.83, blue: 0.45), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                    Text("Dein Tempo. Dein Schach.")
                }.font(.caption).foregroundStyle(.white.opacity(0.65))
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 10) {
                BotPortrait(botID: playViewModel.activeBot.id, side: 120)
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 8)
                Text(playViewModel.activeBot.name).font(.headline)
                Text("Dein Spielpartner").font(.caption).foregroundStyle(.white.opacity(0.7))
            }.frame(width: 170)
        }
        .padding(28).foregroundStyle(.white)
        .background(LinearGradient(colors: [SwiftUI.Color(red: 0.23, green: 0.31, blue: 0.19), SwiftUI.Color(red: 0.12, green: 0.19, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20))
    }

    private func trainingCard(title: String, eyebrow: String, icon: String, color: SwiftUI.Color,
                              message: String, action: String, perform: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Image(systemName: icon).font(.system(size: 25, weight: .semibold)).foregroundStyle(color)
                    .frame(width: 48, height: 48).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(.tertiary)
            }
            Text(eyebrow).font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(.secondary)
            Text(title).font(.system(size: 21, weight: .bold, design: .serif))
            Text(message).font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
            Button(action, action: perform).buttonStyle(.bordered).controlSize(.large)
        }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).panel()
    }

    private var clubOpponents: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Bekannte Gesichter. Neue Herausforderungen.").font(.system(size: 22, weight: .bold, design: .serif))
                Spacer()
                Button("Alle Spielpartner") { chooseBot(playViewModel.activeBot) }.buttonStyle(.link)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                ForEach([BotLibrary.emil, BotLibrary.finn, BotLibrary.anna, BotLibrary.clara]) { bot in
                    let wins = ClubProgress.victories(against: bot, games: Array(games))
                    Button { chooseBot(bot) } label: {
                    HStack(spacing: 12) {
                        BotPortrait(botID: bot.id, side: 54)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bot.name).font(.subheadline.bold())
                            Text("≈ \(bot.elo) Elo").font(.caption).foregroundStyle(.secondary)
                            if wins > 0 {
                                Label("\(wins) Siege", systemImage: "crown.fill").foregroundStyle(AppTheme.gold).font(.caption2)
                            } else { Text("Fordere mich heraus").font(.caption2).foregroundStyle(.secondary) }
                        }
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading).panel()
                    }.buttonStyle(.plain).help("Partie gegen \(bot.name) vorbereiten")
                }
            }
        }
    }
}
