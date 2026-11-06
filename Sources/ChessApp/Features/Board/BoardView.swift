import SwiftUI
import ChessAppKit

/// Ein einzelnes Brett-Feld: Hintergrund, Figur, Overlays (Selektion/Ziel/letzter Zug).
struct SquareView: View {
    let square: Square
    let piece: Piece?
    let isSelected: Bool
    let isTarget: Bool
    let isLastMove: Bool
    let light: SwiftUI.Color
    let dark: SwiftUI.Color
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    isSelected ? SwiftUI.Color.blue.opacity(0.55) :
                    isTarget ? SwiftUI.Color.green.opacity(0.45) :
                    isLastMove ? SwiftUI.Color.yellow.opacity(0.45) :
                    square.isLight ? light : dark
                )
            if let piece {
                PieceView(piece: piece)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

/// Grafischer Pfeil für den besten Zug (Review-Ansicht, später belegt).
struct MoveArrow: Identifiable {
    let id = UUID()
    let from: Square
    let to: Square
    let color: SwiftUI.Color
}

struct MoveArrowView: View {
    let from: Square
    let to: Square
    let size: CGFloat
    let color: SwiftUI.Color

    var body: some View {
        Path { path in
            let cell = size / 8
            let start = CGPoint(x: (CGFloat(from.file) + 0.5) * cell,
                                y: (7 - CGFloat(from.rank) + 0.5) * cell)
            let end = CGPoint(x: (CGFloat(to.file) + 0.5) * cell,
                              y: (7 - CGFloat(to.rank) + 0.5) * cell)
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(color, lineWidth: 3)
        .allowsHitTesting(false)
    }
}

/// 8×8-Brett mit Figuren, Selektion, legalen Zielen, letztem Zug und optionalen Pfeilen.
struct BoardView: View {
    let position: Position
    let orientation: Color
    let legalTargets: Set<Square>
    let lastMove: Move?
    let arrows: [MoveArrow]
    let selected: Square?
    let onSquareTap: (Square) -> Void

    var body: some View {
        let light = AppTheme.lightSquare("Grün")
        let dark = AppTheme.darkSquare("Grün")

        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cell = size / 8
            ZStack {
                ForEach(arrows) { arrow in
                    MoveArrowView(from: arrow.from, to: arrow.to, size: size, color: arrow.color)
                }
                ForEach(0..<64, id: \.self) { index in
                    let file = index % 8
                    let rank = index / 8
                    // Beim gedrehten Brett zeigt Screen-Position (file,rank) das
                    // Brett-Feld (7-rank, 7-file).
                    let displayIndex = orientation == .white ? index : (7 - rank) * 8 + (7 - file)
                    let square = Square(index: displayIndex)
                    let piece = position.board[displayIndex]
                    let isSelected = selected == square
                    let isTarget = legalTargets.contains(square)
                    let isLastMove = lastMove != nil && (lastMove!.from == square || lastMove!.to == square)

                    SquareView(
                        square: square,
                        piece: piece,
                        isSelected: isSelected,
                        isTarget: isTarget,
                        isLastMove: isLastMove,
                        light: light,
                        dark: dark
                    ) {
                        onSquareTap(square)
                    }
                    .frame(width: cell, height: cell)
                    .position(x: (CGFloat(file) + 0.5) * cell,
                              y: (7 - CGFloat(rank) + 0.5) * cell)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
