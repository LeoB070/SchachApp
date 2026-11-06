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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(square.name), \(piece.map { "\($0.color == .white ? "Weiß" : "Schwarz") \($0.type.rawValue)" } ?? "leer")")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Ziehen"), onTap)
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
    let orientation: PieceColor

    var body: some View {
        Path { path in
            let cell = size / 8
            let startSquare = orientation == .white ? from : Square(index: 63 - from.index)
            let endSquare = orientation == .white ? to : Square(index: 63 - to.index)
            let start = CGPoint(x: (CGFloat(startSquare.file) + 0.5) * cell,
                                y: (7 - CGFloat(startSquare.rank) + 0.5) * cell)
            let end = CGPoint(x: (CGFloat(endSquare.file) + 0.5) * cell,
                              y: (7 - CGFloat(endSquare.rank) + 0.5) * cell)
            path.move(to: start)
            path.addLine(to: end)
            let angle = atan2(end.y - start.y, end.x - start.x)
            for offset in [-CGFloat.pi / 6, CGFloat.pi / 6] {
                path.move(to: end)
                path.addLine(to: CGPoint(x: end.x - cell * 0.35 * cos(angle + offset),
                                         y: end.y - cell * 0.35 * sin(angle + offset)))
            }
        }
        .stroke(color, lineWidth: 3)
        .allowsHitTesting(false)
    }
}

/// 8×8-Brett mit Figuren, Selektion, legalen Zielen, letztem Zug und optionalen Pfeilen.
struct BoardView: View {
    let position: Position
    let orientation: PieceColor
    let legalTargets: Set<Square>
    let lastMove: Move?
    let arrows: [MoveArrow]
    let selected: Square?
    let onSquareTap: (Square) -> Void

    @AppStorage("boardTheme") private var boardTheme = "Grün"
    @AppStorage("animationsEnabled") private var animationsEnabled = true

    var body: some View {
        let light = AppTheme.lightSquare(boardTheme)
        let dark = AppTheme.darkSquare(boardTheme)

        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cell = size / 8
            ZStack {
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
                ForEach(arrows) { arrow in
                    MoveArrowView(from: arrow.from, to: arrow.to, size: size,
                                  color: arrow.color, orientation: orientation)
                }
            }
            .animation(animationsEnabled ? .easeInOut(duration: 0.15) : nil, value: lastMove)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
