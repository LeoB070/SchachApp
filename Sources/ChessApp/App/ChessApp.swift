import SwiftUI
import CoreData
import ChessAppKit

@main
struct ChessAppMain: App {
    let persistence = PersistenceController()
    @AppStorage("appearance") private var appearance = "System"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistence.context)
                .preferredColorScheme(AppTheme.colorScheme(appearance))
        }
    }
}
