import SwiftUI

/// Stable IDs keep each opponent's geometric avatar identical across launches.
enum PixelAvatarPattern {
    static func seed(for id: String) -> UInt32 {
        id.utf8.reduce(UInt32(2_166_136_261)) { ($0 ^ UInt32($1)) &* 16_777_619 }
    }

    static func cells(for id: String) -> [[Bool]] {
        var state = seed(for: id)
        var cells = Array(repeating: Array(repeating: false, count: 7), count: 7)
        for row in 0..<7 {
            for column in 0..<4 {
                state = state &* 1_664_525 &+ 1_013_904_223
                let filled = (state >> 24) & 1 == 1
                cells[row][column] = filled
                cells[row][6 - column] = filled
            }
        }
        cells[3][3] = true
        return cells
    }
}

/// Code-drawn pixel mosaics; no image assets or generated portraits.
struct BotPortrait: View {
    let botID: String
    var side: CGFloat = 64

    private static let palettes: [(background: SwiftUI.Color, pixel: SwiftUI.Color)] = [
        (.init(red: 0.16, green: 0.23, blue: 0.28), .init(red: 0.51, green: 0.72, blue: 0.79)),
        (.init(red: 0.22, green: 0.26, blue: 0.17), .init(red: 0.71, green: 0.79, blue: 0.47)),
        (.init(red: 0.28, green: 0.21, blue: 0.17), .init(red: 0.86, green: 0.65, blue: 0.43)),
        (.init(red: 0.24, green: 0.20, blue: 0.28), .init(red: 0.74, green: 0.64, blue: 0.81)),
        (.init(red: 0.15, green: 0.26, blue: 0.23), .init(red: 0.47, green: 0.75, blue: 0.65)),
        (.init(red: 0.28, green: 0.19, blue: 0.20), .init(red: 0.83, green: 0.58, blue: 0.55))
    ]

    var body: some View {
        let cells = PixelAvatarPattern.cells(for: botID)
        let palette = Self.palettes[Int(PixelAvatarPattern.seed(for: botID)) % Self.palettes.count]
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(palette.background))
            let cell = max(1, floor(min(size.width, size.height) / 9))
            let origin = CGPoint(x: floor((size.width - cell * 7) / 2), y: floor((size.height - cell * 7) / 2))
            for row in 0..<7 {
                for column in 0..<7 where cells[row][column] {
                    let pixel = CGRect(x: origin.x + CGFloat(column) * cell, y: origin.y + CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(pixel), with: .color(palette.pixel))
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side * 0.12, style: .continuous))
        .accessibilityHidden(true)
    }
}
