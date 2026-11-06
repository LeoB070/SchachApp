import SwiftUI
import Charts
import ChessAppKit

struct EvalGraphPoint: Identifiable {
    let id: Int
    let ply: Int
    let winPercentWhite: Double
    let evalText: String
}

struct EvalGraphView: View {
    let points: [EvalGraphPoint]
    let currentPly: Int
    let onSelectPly: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Vorteilsverlauf (Weiß %)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("50% = Ausgeglichen")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if points.isEmpty {
                RoundedRectangle(cornerRadius: 6)
                    .fill(SwiftUI.Color.secondary.opacity(0.1))
                    .frame(height: 90)
                    .overlay(Text("Keine Analysedaten").font(.caption).foregroundStyle(.secondary))
            } else {
                Chart {
                    // Baseline at 50%
                    RuleMark(y: .value("Equal", 50))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(SwiftUI.Color.secondary.opacity(0.5))

                    // Area under line
                    ForEach(points) { pt in
                        AreaMark(
                            x: .value("Ply", pt.ply),
                            yStart: .value("Baseline", 50),
                            yEnd: .value("WinPercent", pt.winPercentWhite)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [SwiftUI.Color.blue.opacity(0.35), SwiftUI.Color.blue.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Ply", pt.ply),
                            y: .value("WinPercent", pt.winPercentWhite)
                        )
                        .foregroundStyle(SwiftUI.Color.blue)
                        .interpolationMethod(.monotone)
                    }

                    // Current ply marker
                    if currentPly > 0 && currentPly <= points.count {
                        RuleMark(x: .value("CurrentPly", currentPly))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .foregroundStyle(SwiftUI.Color.yellow)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine()
                        AxisTick()
                        if let intVal = value.as(Int.self) {
                            AxisValueLabel("Zug \((intVal + 1) / 2)")
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { value in
                        AxisGridLine()
                        AxisTick()
                        if let intVal = value.as(Int.self) {
                            AxisValueLabel("\(intVal)%")
                        }
                    }
                }
                .frame(height: 90)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(SwiftUI.Color.secondary.opacity(0.08)))
    }
}
