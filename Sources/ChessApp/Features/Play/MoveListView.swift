import SwiftUI

/// Zugliste in SAN, paarweise "1. e4 e5" angeordnet.
struct MoveListView: View {
    let sans: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Züge").font(.subheadline).bold()
            if sans.isEmpty {
                Text("Noch keine Züge.").foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(stride(from: 0, to: sans.count, by: 2), id: \.self) { i in
                            HStack(spacing: 4) {
                                Text("\(i / 2 + 1).")
                                Text(sans[i])
                                if i + 1 < sans.count {
                                    Text(sans[i + 1])
                                }
                            }
                            .font(.system(.body, design: .monospaced))
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxHeight: 300)
            }
        }
    }
}
