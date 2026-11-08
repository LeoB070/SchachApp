import SwiftUI
import ChessAppKit

public enum TimeControl: String, CaseIterable, Identifiable, Sendable {
    case unlimited = "Unbegrenzt"
    case blitz3_2 = "3 + 2 (Blitz)"
    case blitz5_0 = "5 + 0 (Blitz)"
    case rapid10_0 = "10 + 0 (Schnell)"
    case rapid15_10 = "15 + 10 (Schnell)"

    public var id: String { rawValue }

    public var initialSeconds: TimeInterval? {
        switch self {
        case .unlimited: return nil
        case .blitz3_2: return 180
        case .blitz5_0: return 300
        case .rapid10_0: return 600
        case .rapid15_10: return 900
        }
    }

    public var incrementSeconds: TimeInterval {
        switch self {
        case .unlimited, .blitz5_0, .rapid10_0: return 0
        case .blitz3_2: return 2
        case .rapid15_10: return 10
        }
    }
}

/// Einzelne Schachuhr als Pille: aktiv hell hervorgehoben, unter 30 s rot.
struct ClockView: View {
    let time: TimeInterval?
    let isActive: Bool

    var body: some View {
        let low = isActive && (time ?? .infinity) <= 30
        Text(formattedTime(time))
            .font(.system(size: 20, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .padding(.horizontal, 14)
            .frame(minWidth: 104, minHeight: 38, alignment: .trailing)
            .foregroundStyle(isActive ? (low ? SwiftUI.Color.white : SwiftUI.Color.black) : SwiftUI.Color.secondary)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? (low ? SwiftUI.Color.red : SwiftUI.Color.white) : SwiftUI.Color.secondary.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(SwiftUI.Color.black.opacity(isActive ? 0.15 : 0), lineWidth: 1))
            .shadow(color: .black.opacity(isActive ? 0.18 : 0), radius: 3, y: 1)
            .animation(.easeInOut(duration: 0.15), value: isActive)
            .accessibilityLabel("Uhr \(formattedTime(time))")
    }

    private func formattedTime(_ time: TimeInterval?) -> String {
        guard let time = time else { return "–:––" }
        let clamped = max(0, time)
        let minutes = Int(clamped) / 60
        let seconds = Int(clamped) % 60
        if clamped < 10 {
            let tenths = Int((clamped - Double(Int(clamped))) * 10)
            return String(format: "%d:%02d.%d", minutes, seconds, tenths)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
