import SwiftUI
import ChessAppKit

/// Partie gegen den lokalen Rechner (noch ohne Engine – Task 3 fügt den Gegner hinzu).
struct PlayView: View {
    @State private var viewModel = PlayViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.statusText).font(.headline)
                Spacer()
                Button("Neue Partie") { viewModel.newGame() }
                Button("Brett drehen") { viewModel.flipBoard() }
            }
            .padding()

            HStack(spacing: 24) {
                BoardView(
                    position: viewModel.currentPosition,
                    orientation: viewModel.orientation,
                    legalTargets: viewModel.legalTargets,
                    lastMove: viewModel.lastMove,
                    arrows: [],
                    selected: viewModel.selectedSquare,
                    onSquareTap: { viewModel.squareTapped($0) }
                )
                .padding()

                VStack(alignment: .leading, spacing: 12) {
                    MoveListView(sans: viewModel.sans)
                    Spacer(minLength: 0)
                    Button("Aufgabe (Stub)") { /* Task 4: Aufgabe gegen Engine */ }
                        .disabled(true)
                }
                .frame(width: 260)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .center) {
            if let pending = viewModel.pendingPromotion {
                PromotionPicker(
                    pieceColor: viewModel.currentPosition.turn,
                    onSelect: { viewModel.promote(to: $0) },
                    onCancel: { viewModel.cancelPromotion() }
                )
            }
        }
    }
}
