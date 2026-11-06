import SwiftUI
import Combine
import ChessAppKit

struct PlayView: View {
    @Environment(\.managedObjectContext) private var context
    @ObservedObject var viewModel: PlayViewModel
    @LocalState private var showReview = false
    @LocalState private var showNewGame = false
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.statusText).font(.headline)
                Spacer()
                Button("Neue Partie") { showNewGame = true }
                Button("Brett drehen") { viewModel.flipBoard() }
            }.padding()
            if let message = viewModel.errorMessage {
                HStack {
                    Text(message).foregroundStyle(.red).textSelection(.enabled)
                    Button(viewModel.result == "*" ? "Erneut versuchen" : "Speichern") {
                        if viewModel.result == "*" { viewModel.resume(context: context) }
                        else { viewModel.save(context: context) }
                    }
                }.padding(.horizontal)
            }
            ClockView(whiteTime: viewModel.whiteTime, blackTime: viewModel.blackTime,
                      activeColor: viewModel.result == "*" ? viewModel.currentPosition.turn : nil,
                      isRunning: viewModel.result == "*")
            HStack(spacing: 24) {
                BoardView(position: viewModel.currentPosition, orientation: viewModel.orientation,
                          legalTargets: viewModel.legalTargets, lastMove: viewModel.lastMove,
                          arrows: [], selected: viewModel.selectedSquare,
                          onSquareTap: { viewModel.squareTapped($0, context: context) }).padding()
                VStack(alignment: .leading, spacing: 12) {
                    MoveListView(sans: viewModel.sans)
                    Spacer(minLength: 0)
                    if viewModel.savedGame != nil {
                        Button("Partie analysieren") { showReview = true }
                    }
                    Button("Aufgeben", role: .destructive) { viewModel.resign(context: context) }
                        .disabled(viewModel.result != "*")
                }.frame(width: 260).padding()
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { viewModel.resume(context: context) }
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
                Picker("Gegner", selection: $viewModel.botID) {
                    Text("Stockfish mit Stärkeregler").tag("stockfish_custom")
                    ForEach(BotLibrary.allBots) { bot in Text("\(bot.name) (\(bot.elo))").tag(bot.id) }
                }
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
            }.padding(28).frame(width: 430)
        }
        .overlay {
            if viewModel.pendingPromotion != nil {
                PromotionPicker(color: viewModel.currentPosition.turn,
                                onSelect: { viewModel.promote(to: $0, context: context) },
                                onCancel: { viewModel.cancelPromotion() })
            }
        }
    }
}
