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

struct ClockView: View {
    let whiteTime: TimeInterval?
    let blackTime: TimeInterval?
    let activeColor: PieceColor?
    let isRunning: Bool

    var body: some View {
        HStack(spacing: 20) {
            clockBadge(title: "Weiß", time: whiteTime, isActive: activeColor == .white)
            clockBadge(title: "Schwarz", time: blackTime, isActive: activeColor == .black)
        }
    }

    @ViewBuilder
    private func clockBadge(title: String, time: TimeInterval?, isActive: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive && isRunning ? SwiftUI.Color.green : SwiftUI.Color.secondary.opacity(0.4))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formattedTime(time))
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(isLowTime(time) && isActive ? SwiftUI.Color.red : SwiftUI.Color.primary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? SwiftUI.Color.accentColor.opacity(0.12) : SwiftUI.Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? SwiftUI.Color.accentColor : SwiftUI.Color.clear, lineWidth: 1.5)
        )
    }

    private func formattedTime(_ time: TimeInterval?) -> String {
        guard let time = time else { return "∞" }
        let clamped = max(0, time)
        let minutes = Int(clamped) / 60
        let seconds = Int(clamped) % 60
        if clamped < 10 {
            let tenths = Int((clamped - Double(Int(clamped))) * 10)
            return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func isLowTime(_ time: TimeInterval?) -> Bool {
        guard let time = time else { return false }
        return time <= 30
    }
}
