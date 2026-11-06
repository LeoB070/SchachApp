import SwiftUI
import CoreData
import ChessAppKit

@main
struct ChessAppMain: App {
    let persistence = PersistenceController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistence.context)
        }
    }
}
