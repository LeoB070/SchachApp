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

    var side: CGFloat = 56
    var showFile = false
    var showRank = false

    var body: some View {
        ZStack {
            if isLastMove || isSelected {
                Rectangle().fill(SwiftUI.Color(red: 1.0, green: 0.84, blue: 0.25)
                    .opacity(isSelected ? 0.55 : 0.38))
            }
            if isTarget {
                if piece == nil {
                    Circle().fill(SwiftUI.Color.black.opacity(0.16))
                        .frame(width: side * 0.30, height: side * 0.30)
                } else {
                    Circle().strokeBorder(SwiftUI.Color.black.opacity(0.16), lineWidth: side * 0.08)
                }
            }
            if showRank {
                Text(String(square.rank + 1))
                    .padding(.leading, side * 0.05).padding(.top, side * 0.03)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            if showFile {
                Text(String(UnicodeScalar(97 + square.file)!))
                    .padding(.trailing, side * 0.05).padding(.bottom, side * 0.02)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(width: side, height: side)
        .font(.system(size: max(8, side * 0.15), weight: .bold))
        .foregroundStyle(square.isLight ? dark : light)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(square.name), \(piece.map { "\($0.color == .white ? "Weiß" : "Schwarz") \(pieceName($0.type))" } ?? "leer")")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Ziehen"), onTap)
    }

    private func pieceName(_ type: PieceType) -> String {
        switch type {
        case .pawn: return "Bauer"
        case .knight: return "Springer"
        case .bishop: return "Läufer"
        case .rook: return "Turm"
        case .queen: return "Dame"
        case .king: return "König"
        }
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

    private func center(_ square: Square, cell: CGFloat) -> CGPoint {
        let shown = orientation == .white ? square : Square(index: 63 - square.index)
        return CGPoint(x: (CGFloat(shown.file) + 0.5) * cell, y: (7 - CGFloat(shown.rank) + 0.5) * cell)
    }

    var body: some View {
        let cell = size / 8
        let start = center(from, cell: cell)
        let end = center(to, cell: cell)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let head = cell * 0.42
        let base = CGPoint(x: end.x - head * cos(angle), y: end.y - head * sin(angle))
        ZStack {
            if from == to {
                // Nur ein Feld (z. B. Puzzle-Hinweis): Ring statt Pfeil.
                Circle().strokeBorder(color, lineWidth: cell * 0.08)
                    .frame(width: cell * 0.9, height: cell * 0.9)
                    .position(start)
            } else {
                Path { p in p.move(to: start); p.addLine(to: base) }
                    .stroke(color, style: StrokeStyle(lineWidth: cell * 0.16, lineCap: .round))
                Path { p in
                    p.move(to: end)
                    p.addLine(to: CGPoint(x: base.x + head * 0.6 * cos(angle + .pi / 2),
                                          y: base.y + head * 0.6 * sin(angle + .pi / 2)))
                    p.addLine(to: CGPoint(x: base.x + head * 0.6 * cos(angle - .pi / 2),
                                          y: base.y + head * 0.6 * sin(angle - .pi / 2)))
                    p.closeSubpath()
                }
                .fill(color)
            }
        }
        .frame(width: size, height: size)
        .opacity(0.8)
        .allowsHitTesting(false)
    }
}

/// 8×8-Brett mit Figuren, Selektion, legalen Zielen, letztem Zug und optionalen Pfeilen.
struct BoardPiece: Identifiable, Equatable {
    let id: UUID
    var square: Square
    var piece: Piece

    static func snapshot(_ position: Position) -> [BoardPiece] {
        return position.board.enumerated().compactMap { index, piece in
            piece.map { BoardPiece(id: UUID(), square: Square(index: index), piece: $0) }
        }
    }

    static func advancing(_ pieces: [BoardPiece], from old: Position, to new: Position, move: Move?) -> [BoardPiece] {
        guard let move, old.make(move) == new,
              pieces.contains(where: { $0.square == move.from }) else {
            return snapshot(new)
        }
        var next = pieces
        next.removeAll { item in
            item.square == move.to || (move.flags.contains(.enPassant)
                && item.square == Square(file: move.to.file, rank: move.from.rank))
        }
        if let index = next.firstIndex(where: { $0.square == move.from }),
           let piece = new.board[move.to.index] {
            next[index].square = move.to
            next[index].piece = piece
        }
        if move.flags.contains(.castleKing) || move.flags.contains(.castleQueen) {
            let rookFrom = Square(file: move.flags.contains(.castleKing) ? 7 : 0, rank: move.from.rank)
            if let index = next.firstIndex(where: { $0.square == rookFrom }) {
                next[index].square = Square(file: move.flags.contains(.castleKing) ? 5 : 3, rank: move.from.rank)
            }
        }
        return next
    }
}

struct BoardView: View {
    let position: Position
    let orientation: PieceColor
    let legalTargets: Set<Square>
    let lastMove: Move?
    let arrows: [MoveArrow]
    let selected: Square?
    let onSquareTap: (Square) -> Void

    @LocalState private var pieces: [BoardPiece] = []

    @AppStorage("boardTheme") private var boardTheme = "Grün"
    @AppStorage("animationsEnabled") private var animationsEnabled = true

    var body: some View {
        let light = AppTheme.lightSquare(boardTheme)
        let dark = AppTheme.darkSquare(boardTheme)

        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cell = size / 8
            ZStack {
                Canvas { context, _ in
                    for rank in 0..<8 {
                        for file in 0..<8 {
                            let rect = CGRect(x: CGFloat(file) * cell, y: CGFloat(rank) * cell,
                                              width: cell, height: cell)
                            context.fill(Path(rect), with: .color((file + rank) % 2 == 0 ? light : dark),
                                         style: FillStyle(antialiased: false))
                        }
                    }
                }
                .allowsHitTesting(false)
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
                    let isLastMove = lastMove.map { $0.from == square || $0.to == square } ?? false

                    SquareView(
                        square: square,
                        piece: piece,
                        isSelected: isSelected,
                        isTarget: isTarget,
                        isLastMove: isLastMove,
                        light: light,
                        dark: dark,
                        onTap: { onSquareTap(square) },
                        side: cell,
                        showFile: rank == 0,
                        showRank: file == 0
                    )
                    .frame(width: cell, height: cell)
                    .position(x: (CGFloat(file) + 0.5) * cell,
                              y: (7 - CGFloat(rank) + 0.5) * cell)
                }
                ForEach(pieces) { item in
                    let square = orientation == .white ? item.square : Square(index: 63 - item.square.index)
                    PieceView(piece: item.piece, side: cell * 0.94)
                        .position(x: (CGFloat(square.file) + 0.5) * cell,
                                  y: (7 - CGFloat(square.rank) + 0.5) * cell)
                        .allowsHitTesting(false)
                }
                .animation(animationsEnabled ? .easeInOut(duration: 0.22) : nil, value: pieces)
                ForEach(arrows) { arrow in
                    MoveArrowView(from: arrow.from, to: arrow.to, size: size,
                                  color: arrow.color, orientation: orientation)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { pieces = BoardPiece.snapshot(position) }
        .onChange(of: position) { old, new in
            pieces = BoardPiece.advancing(pieces, from: old, to: new, move: lastMove)
        }
    }


}
