import SwiftUI
import CoreData
import ChessAppKit

/// Own model and engine keep this sheet independent of the active game.
struct PositionTrainingView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    let position: Position
    var title = "Stellung trainieren"
    var exercise: EndgameExercise? = nil
    @StateObject private var model = PlayViewModel()
    @LocalState private var player: PieceColor = .white
    @LocalState private var botID = BotLibrary.emil.id
    @LocalState private var started = false
    @LocalState private var goalReached = false
    @LocalState private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.title2.bold())
                Spacer()
                Button("Schließen") { model.stop(); dismiss() }
            }
            Text("Freies Training · ohne Wertung und ohne Eintrag im Partiearchiv.")
                .font(.caption).foregroundStyle(.secondary)
            if let exercise { Text(exercise.advice).font(.callout) }
            HStack(alignment: .top, spacing: 24) {
                BoardView(position: started ? model.currentPosition : position,
                          orientation: started ? model.orientation : player,
                          legalTargets: started && !goalReached ? model.legalTargets : [], lastMove: started ? model.lastMove : nil,
                          arrows: [], selected: started && !goalReached ? model.selectedSquare : nil,
                          onSquareTap: { if started && !goalReached { model.squareTapped($0, context: context) } })
                    .frame(width: 440, height: 440)
                    .overlay {
                        if model.pendingPromotion != nil {
                            PromotionPicker(color: model.currentPosition.turn,
                                onSelect: { model.promote(to: $0, context: context) },
                                onCancel: { model.cancelPromotion() })
                        }
                    }
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Deine Farbe", selection: $player) {
                        Text("Weiß").tag(PieceColor.white)
                        Text("Schwarz").tag(PieceColor.black)
                    }.disabled(started || exercise != nil)
                    Picker("Spielpartner", selection: $botID) {
                        ForEach(BotLibrary.allBots) { bot in Text("\(bot.name) · ≈ \(bot.elo) Elo").tag(bot.id) }
                    }.disabled(started)
                    if started {
                        Label(goalReached ? "Trainingsziel erreicht!" : model.statusText,
                              systemImage: goalReached ? "checkmark.seal.fill" : "checkerboard.rectangle")
                            .font(.headline).foregroundStyle(goalReached ? AppTheme.accent : .primary)
                        if model.isThinking { ProgressView().controlSize(.small) }
                        if let error = model.errorMessage {
                            Text(error).foregroundStyle(.red).font(.callout).textSelection(.enabled)
                            Button("Erneut versuchen") { model.resume(context: context) }
                                .disabled(goalReached || model.result != "*")
                        }
                        Text(model.sans.joined(separator: " · ")).font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled).frame(maxHeight: 130, alignment: .topLeading)
                        Button("Ausgangsstellung erneut spielen") { start() }.buttonStyle(.borderedProminent)
                        Button("Farbe und Spielpartner ändern") {
                            model.stop(); started = false; goalReached = false; copied = false
                        }
                        Button(copied ? "PGN kopiert" : "Trainings-PGN kopieren") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(model.exportPGN(), forType: .string)
                            copied = true
                        }
                    } else {
                        Text("\(position.turn == .white ? "Weiß" : "Schwarz") ist in dieser Stellung am Zug.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Training starten") { start() }.buttonStyle(.borderedProminent)
                    }
                    Spacer()
                }.frame(width: 270, alignment: .leading)
            }
        }
        .padding(24).frame(minWidth: 790, minHeight: 550)
        .background(AppTheme.background)
        .onAppear { player = exercise == nil ? position.turn : .white }
        .onDisappear { model.stop() }
        .onChange(of: model.positions.count) { _, _ in
            if started, let exercise, exercise.goalReached(in: model.currentPosition, player: player) {
                goalReached = true
                model.stop()
            }
        }
    }

    private func start() {
        goalReached = false; copied = false; started = true
        model.startTraining(position: position, playerColor: player, botID: botID, context: context)
    }
}

struct EndgameTrainingView: View {
    @LocalState private var selected: EndgameExercise? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Endspiele am Brett").font(.largeTitle.bold())
                Text("Übe ein klares Ziel gegen einen Bot – ohne Zeitdruck. Alle Stellungen bleiben auf deinem Mac.")
                    .foregroundStyle(.secondary)
                ForEach(EndgameExercise.all) { exercise in
                    HStack(spacing: 20) {
                        if let position = try? Position(fen: exercise.fen) {
                            BoardView(position: position, orientation: .white, legalTargets: [], lastMove: nil,
                                      arrows: [], selected: nil, onSquareTap: { _ in })
                                .frame(width: 140, height: 140).allowsHitTesting(false).accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(exercise.title).font(.title3.bold())
                            Text(exercise.advice).foregroundStyle(.secondary)
                            Button("Gegen Bot üben") { selected = exercise }.buttonStyle(.borderedProminent)
                        }
                        Spacer()
                    }.padding(18).panel()
                }
                Text("Kuratierte Ausgangsstellungen. Die Engine spielt die Gegenwehr; es wird kein perfektes Tablebase-Urteil angezeigt.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(28).frame(maxWidth: 950, alignment: .leading)
        }.background(AppTheme.background)
        .sheet(item: $selected) { exercise in
            if let position = try? Position(fen: exercise.fen) {
                PositionTrainingView(position: position, title: exercise.title, exercise: exercise)
            }
        }
    }
}
