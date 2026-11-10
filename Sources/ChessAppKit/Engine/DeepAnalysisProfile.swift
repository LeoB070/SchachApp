import Foundation

/// Conservative automatic budget; leaves CPU and RAM available for the desktop.
public struct DeepAnalysisProfile: Sendable {
    public let threads: Int
    public let hashMB: Int
    public let depth: Int

    public init(processorCount: Int = ProcessInfo.processInfo.activeProcessorCount,
                memoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory) {
        threads = min(32, max(1, max(1, processorCount) - 2))
        hashMB = Int(max(1, min(4096, memoryBytes / 8 / 1024 / 1024)))
        depth = threads >= 8 ? 30 : (threads >= 4 ? 28 : 24)
    }

    public var engineSettings: EngineSettings {
        EngineSettings(threads: threads, hashMB: hashMB, analysisDepth: depth)
    }
}
