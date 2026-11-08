import AppKit
import SwiftUI
import ChessAppKit

@main
struct NavigationLayoutChecks {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let persistence = PersistenceController(inMemory: true)
        let sample = SavedGame(context: persistence.context)
        sample.whitePlayer = "Du"; sample.blackPlayer = BotLibrary.emil.name; sample.result = "0-1"
        sample.pgn = "1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6 4. Qe2 Nd4 5. Qd1 Nxe4 0-1"
        let parsed = try! PGN.parse(sample.pgn)
        let moves = parsed.moveList.enumerated().map { index, move in
            MoveAnalysis(ply: index + 1, san: parsed.sanList[index], fenBefore: parsed.positions[index].fen,
                         fenAfter: parsed.positions[index + 1].fen, evalBefore: 0, evalAfter: 0,
                         bestMove: index == 6 ? "h5f7" : move.uci, classification: index == 6 ? .blunder : .best,
                         accuracy: index == 6 ? 40 : 100, winPercentBefore: index == 6 ? 99 : 50,
                         winPercentAfter: 50, winPercentLoss: index == 6 ? 49 : 0)
        }
        let report = GameAnalysisEntry(context: persistence.context)
        report.gameID = sample.id
        report.accuracyWhite = 75; report.accuracyBlack = 90
        report.analysisJSON = try! JSONEncoder().encode(GameAnalysis(moves: moves, accuracyWhite: 75, accuracyBlack: 90))
        try! persistence.context.save()
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 1100, height: 720),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: AnyView(EmptyView()))
        window.contentView = host
        window.orderBack(nil)
        for mode in [ColorScheme.light, .dark] {
        for section in [RootView.SidebarItem.home, .play, .puzzles, .analysis, .lessons, .openings, .endgames, .archive, .stats] {
            // Replace identity so each section starts with its own initial selection.
            host.rootView = AnyView(RootView(selection: section).id(section)
                .environment(\.managedObjectContext, persistence.context)
                .preferredColorScheme(mode))
            for width in [1100.0, 960.0, 1400.0, 1100.0] {
                window.setContentSize(NSSize(width: width, height: 720))
                RunLoop.main.run(until: Date().addingTimeInterval(0.15))
                window.contentView?.layoutSubtreeIfNeeded()
                if width == 1100, let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    if let png = bitmap.representation(using: .png, properties: [:]) {
                        let name = mode == .dark ? "dark" : "light"
                        try! png.write(to: URL(fileURLWithPath: "/tmp/chess-club-\(section.rawValue)-\(name).png"))
                    }
                }
                func splitCount(_ view: NSView) -> Int {
                    (view is NSSplitView ? 1 : 0) + view.subviews.reduce(0) { $0 + splitCount($1) }
                }
                assert(splitCount(host) == 0, "\(section) installs a window-level navigation split controller")
                func scrollFrames(_ view: NSView) -> [NSRect] {
                    let own = view is NSScrollView ? [host.convert(view.bounds, from: view)] : []
                    return own + view.subviews.flatMap(scrollFrames)
                }
                let frames = scrollFrames(host)
                assert(frames.contains { abs($0.minX) < 1 && abs($0.width - 220) < 1 },
                       "\(section) moved or covered the main sidebar: \(frames)")
                assert(window.frame.width <= 1500, "\(section) made window constraints grow without bound")
                assert(host.fittingSize.width.isFinite && host.fittingSize.width <= 1500,
                       "\(section) has unstable minimum width: \(host.fittingSize)")
            }
        }
        host.rootView = AnyView(ReviewView(game: sample).environment(\.managedObjectContext, persistence.context).preferredColorScheme(mode))
        window.setContentSize(NSSize(width: 1100, height: 720))
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        host.layoutSubtreeIfNeeded()
        if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let name = mode == .dark ? "dark" : "light"
            try! bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "/tmp/chess-club-review-\(name).png"))
        }
        }
        window.close()
        print("Navigation layout checks passed: nine sections at four window widths in light and dark modes")
    }
}
