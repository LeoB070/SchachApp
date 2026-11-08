import SwiftUI
import Combine
import CoreData
import ChessAppKit

struct PlayView: View {
    @Environment(\.managedObjectContext) private var context
    @ObservedObject var viewModel: PlayViewModel
    var initialBotID: String? = nil
    @FetchRequest(sortDescriptors: []) private var games: FetchedResults<SavedGame>
    @LocalState private var showReview = false
    @LocalState private var showNewGame = false
    @LocalState private var showGameOver = false
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            GeometryReader { geo in
                let barHeight: CGFloat = 44
                let side = max(200, min(geo.size.width, geo.size.height - 2 * (barHeight + 10)))
                VStack(spacing: 10) {
                    playerBar(viewModel.orientation == .white ? .black : .white).frame(height: barHeight)
                    BoardView(position: viewModel.currentPosition, orientation: viewModel.orientation,
                              legalTargets: viewModel.legalTargets, lastMove: viewModel.lastMove,
                              arrows: [], selected: viewModel.selectedSquare,
                              onSquareTap: { viewModel.squareTapped($0, context: context) })
                        .frame(width: side, height: side)
                        .overlay {
                            if showGameOver {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(.black.opacity(0.35))
                                    gameOverCard
                                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                                }
                                .transition(.opacity)
                            }
                        }
                    playerBar(viewModel.orientation).frame(height: barHeight)
                }
                .frame(width: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            sidePanel.frame(width: 290)
        }
        .padding(24)
        .onChange(of: viewModel.result) { _, result in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { showGameOver = result != "*" }
            if result != "*", AppSettings.fetchOrCreate(context: context).soundEnabled { NSSound(named: "Glass")?.play() }
        }
        .onAppear {
            viewModel.resume(context: context)
            if let initialBotID { viewModel.botID = initialBotID; showNewGame = true }
        }
        .onDisappear { viewModel.stop() }
        .onReceive(timer) { viewModel.tick(context: context, now: $0) }
        .sheet(isPresented: $showReview) {
            VStack {
                HStack { Spacer(); Button("Schließen") { showReview = false } }.padding()
                ReviewView(game: viewModel.savedGame)
            }.frame(minWidth: 1000, minHeight: 700)
        }
        .sheet(isPresented: $showNewGame) {
            VStack(spacing: 18) {
                Text("Neue Partie").font(.title2)
                Picker("Deine Farbe", selection: $viewModel.playerColor) {
                    Text("Weiß").tag(PieceColor.white)
                    Text("Schwarz").tag(PieceColor.black)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dein Schachclub").font(.title.bold())
                    Text("Such dir einen Spielpartner – vom ersten Zug bis zur Herausforderung.")
                        .font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(BotLibrary.allBots) { bot in
                            Button { viewModel.botID = bot.id } label: {
                                VStack(spacing: 7) {
                                    BotPortrait(botID: bot.id, side: 70)
                                    Text(bot.name).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                                    Text("≈ \(bot.elo) Elo").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                    let wins = ClubProgress.victories(against: bot, games: Array(games))
                                    if wins > 0 { Label("\(wins) Siege", systemImage: "crown.fill").font(.caption2).foregroundStyle(AppTheme.gold) }
                                    Text(bot.description).font(.caption).foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center).frame(height: 44, alignment: .top)
                                }
                                .padding(12).frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 16).fill(viewModel.botID == bot.id ? SwiftUI.Color.accentColor.opacity(0.12) : SwiftUI.Color(nsColor: .controlBackgroundColor)))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(viewModel.botID == bot.id ? SwiftUI.Color.accentColor : SwiftUI.Color.secondary.opacity(0.2), lineWidth: viewModel.botID == bot.id ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(bot.name), ungefähr \(bot.elo) Elo")
                            .accessibilityAddTraits(viewModel.botID == bot.id ? [.isSelected] : [])
                        }
                    }.padding(3)
                }.frame(height: 390)
                Toggle("Stockfish mit eigenem Stärkeregler", isOn: Binding(
                    get: { viewModel.botID == "stockfish_custom" },
                    set: { viewModel.botID = $0 ? "stockfish_custom" : BotLibrary.emil.id }
                ))
                if viewModel.botID == "stockfish_custom" {
                    Stepper("Stockfish-Stärke: \(viewModel.skillLevel)", value: $viewModel.skillLevel, in: 0...20)
                }
                Picker("Bedenkzeit", selection: $viewModel.timeControl) {
                    ForEach(TimeControl.allCases) { Text($0.rawValue).tag($0) }
                }
                Text("Eine laufende Partie wird beim Neustart verworfen.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Abbrechen") { showNewGame = false }
                    Button("Starten") { viewModel.newGame(context: context); showNewGame = false }.buttonStyle(.borderedProminent)
                }
            }.padding(28).frame(width: 650)
        }
        .overlay {
            if viewModel.pendingPromotion != nil {
                PromotionPicker(color: viewModel.currentPosition.turn,
                                onSelect: { viewModel.promote(to: $0, context: context) },
                                onCancel: { viewModel.cancelPromotion() })
            }
        }
    }

    private var isRunning: Bool { viewModel.result == "*" }

    @ViewBuilder
    private func playerBar(_ color: PieceColor) -> some View {
        let isBot = color != viewModel.activePlayerColor
        let isActive = isRunning && viewModel.currentPosition.turn == color
        HStack(spacing: 10) {
            if isBot {
                BotPortrait(botID: viewModel.activeBot.id, side: 38)
            } else {
                PieceView(color: color, type: .king, side: 26)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 7).fill(SwiftUI.Color.secondary.opacity(0.15)))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(isBot ? viewModel.activeBot.name : "Du").font(.system(size: 14, weight: .semibold))
                HStack(spacing: 6) {
                    Text(isBot ? "≈ \(viewModel.activeBot.elo) Elo" : (color == .white ? "Weiß" : "Schwarz"))
                    if isBot && viewModel.isThinking {
                        ProgressView().controlSize(.mini)
                        Text("denkt")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let time = color == .white ? viewModel.whiteTime : viewModel.blackTime {
                ClockView(time: time, isActive: isActive)
            } else if isActive {
                Text("am Zug").font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(SwiftUI.Color.accentColor.opacity(0.18)))
            }
        }
    }

    private var sidePanel: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isRunning ? "Partie läuft" : "Partie beendet")
                        .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    Text(viewModel.statusText).font(.headline).lineLimit(2)
                }
                Spacer()
                if !isRunning {
                    Text(viewModel.result)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                }
            }
            .padding(14)
            if let message = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout).foregroundStyle(.red).textSelection(.enabled)
                    Button(isRunning ? "Erneut versuchen" : "Speichern") {
                        if isRunning { viewModel.resume(context: context) }
                        else { viewModel.save(context: context) }
                    }
                    .controlSize(.small)
                }
                .padding([.horizontal, .bottom], 14)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    BotPortrait(botID: viewModel.activeBot.id, side: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.activeBot.name).font(.headline)
                        let wins = ClubProgress.victories(against: viewModel.activeBot, games: Array(games))
                        if wins > 0 { Label("\(wins) Siege gegen mich", systemImage: "crown.fill").font(.caption).foregroundStyle(AppTheme.gold) }
                        else { Text("Dein Gegenüber am Brett").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Text(viewModel.botMessage).font(.callout).fixedSize(horizontal: false, vertical: true)
                    .id(viewModel.botMessage)
                    .transition(.opacity)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.accent.opacity(0.07))
            Divider()
            MoveListView(sans: viewModel.sans)
                .frame(maxHeight: .infinity)
            Divider()
            VStack(spacing: 10) {
                if viewModel.savedGame != nil {
                    Button { showReview = true } label: {
                        Label("Partie analysieren", systemImage: "chart.xyaxis.line").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                }
                HStack(spacing: 8) {
                    Button { showNewGame = true } label: {
                        Label("Neue Partie", systemImage: "plus").frame(maxWidth: .infinity)
                    }
                    .help("Neue Partie")
                    Button { viewModel.flipBoard() } label: {
                        Label("Brett drehen", systemImage: "arrow.up.arrow.down").frame(maxWidth: .infinity)
                    }
                    .help("Brett drehen")
                    Button(role: .destructive) { viewModel.resign(context: context) } label: {
                        Label("Aufgeben", systemImage: "flag").frame(maxWidth: .infinity)
                    }
                    .disabled(!isRunning)
                    .help("Aufgeben")
                }
                .labelStyle(.iconOnly)
                .controlSize(.large)
            }
            .padding(12)
        }
        .panel()
    }

    /// Ergebnis aus Sicht des Spielers: Sieg, Niederlage oder Remis.
    private var outcome: (title: String, icon: String, tint: SwiftUI.Color) {
        let playerWon = (viewModel.result == "1-0") == (viewModel.activePlayerColor == .white)
        if viewModel.result == "1/2-1/2" { return ("Remis", "equal.circle.fill", .gray) }
        return playerWon ? ("Gewonnen", "trophy.fill", .orange) : ("Verloren", "flag.fill", .red)
    }

    private var gameOverCard: some View {
        VStack(spacing: 14) {
            Image(systemName: outcome.icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(outcome.tint)
                .symbolEffect(.bounce, value: showGameOver)
            VStack(spacing: 4) {
                Text(outcome.title).font(.system(size: 26, weight: .bold, design: .serif))
                Text(viewModel.ending).font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text(viewModel.result).font(.system(.title3, design: .monospaced).weight(.semibold))
                    .padding(.top, 2)
            }
            HStack(spacing: 10) {
                if viewModel.savedGame != nil {
                    Button("Analysieren") { showReview = true }
                }
                Button("Revanche") { viewModel.rematch(context: context) }
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
            Button("Anderen Spielpartner wählen") { showNewGame = true }.buttonStyle(.link)
        }
        .padding(28)
        .frame(width: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showGameOver = false }
            } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                    .padding(8)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .help("Schließen und Stellung ansehen")
            .padding(6)
        }
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
    }
}
