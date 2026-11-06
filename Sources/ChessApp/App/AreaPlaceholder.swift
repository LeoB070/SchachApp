import SwiftUI

/// Platzhalter für einen Bereich, der in einem späteren Meilenstein gebaut wird.
struct AreaPlaceholder: View {
    let title: String
    let hint: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gear")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title).font(.title2).bold()
            Text(hint).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
