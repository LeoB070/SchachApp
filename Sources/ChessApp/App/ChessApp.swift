import SwiftUI
import SwiftData
import ChessAppKit

@main
struct ChessAppMain: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: AppSettings.self, SavedGame.self, GameAnalysisEntry.self,
                PuzzleProgress.self, PuzzleResult.self, LessonProgress.self
            )
        } catch {
            fatalError("SwiftData-Container konnte nicht erstellt werden: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
    }
}
