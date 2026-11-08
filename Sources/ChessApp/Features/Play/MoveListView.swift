import SwiftUI

/// Zugliste in SAN als Tabelle: Nummer | Weiß | Schwarz, letzter Zug markiert.
struct MoveListView: View {
    let sans: [String]

    var body: some View {
        if sans.isEmpty {
            Text("Noch keine Züge")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(stride(from: 0, to: sans.count, by: 2)), id: \.self) { i in
                            HStack(spacing: 0) {
                                Text("\(i / 2 + 1).")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 38, alignment: .leading)
                                cell(i)
                                cell(i + 1)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 26)
                            .background(i / 2 % 2 == 1 ? SwiftUI.Color.secondary.opacity(0.06) : .clear)
                            .id(i)
                        }
                    }
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                }
                .onChange(of: sans.count) { _, count in
                    withAnimation { proxy.scrollTo((count - 1) / 2 * 2, anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ index: Int) -> some View {
        let isLast = index == sans.count - 1
        Text(index < sans.count ? sans[index] : "")
            .fontWeight(isLast ? .bold : .medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4)
                .fill(isLast ? SwiftUI.Color.accentColor.opacity(0.18) : .clear))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
