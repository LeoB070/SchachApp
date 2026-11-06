import SwiftUI
import ChessAppKit

// Umwandlungsdialog: Zentrum-Overlay in PlayView; nur die Auswahl.
struct PromotionPicker: View {
    var color: ChessAppKit.Color   // Farbe der zugreifenden Seite (Figur-Motive)
    var onSelect: (PieceType) -> Void
    var onCancel: () -> Void

    private let choices: [PieceType] = [.queen, .rook, .bishop, .knight]

    var body: some View {
        VStack(spacing: 12) {
            Text("Umwandlung").font(.headline)
            HStack(spacing: 10) {
                ForEach(choices, id: \.self) { type in
                    Button {
                        onSelect(type)
                    } label: {
                        VStack(spacing: 4) {
                            PieceView(color: color, type: type, side: 46)
                            Text(name(type)).font(.caption)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(SwiftUI.Color.secondary.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(name(type))
                }
            }
            Button("Abbrechen") { onCancel() }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14).fill(SwiftUI.Color(.windowBackgroundColor)))
        .shadow(radius: 8)
    }

    private func name(_ type: PieceType) -> String {
        switch type {
        case .queen: return "Dame"
        case .rook: return "Turm"
        case .bishop: return "Läufer"
        case .knight: return "Springer"
        default: return type.rawValue
        }
    }
}
