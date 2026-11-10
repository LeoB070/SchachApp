import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Einfache UCI-Anbindung mit genau einem Auftrag zur Zeit.
// TODO(CLAUDE): Warteschlange, automatischer Neustart und feinere Analyse-Timeouts ergänzen.
public actor UCIEngine: ChessEngine {
    public let executablePath: String
    public private(set) var settings: EngineSettings
    private var process: Process?
    private var input: Pipe?
    private var readerTask: Task<Void, Never>?
    private var processID: UUID?
    private var busy = false
    private var expectedResponse: String?
    private var responseID: UUID?
    private var responseContinuation: CheckedContinuation<String, Error>?
    private var analysisContinuation: AsyncStream<EngineInfo>.Continuation?
    private var analysisID: UUID?
    private var analysisTimeout: Task<Void, Never>?
    private let analysisTimeoutSeconds: UInt64
    private var sideToMove: Color = .white
    #if canImport(AppKit)
    private var appTerminationObserver: Any?
    #endif

    public init(executablePath: String? = nil, settings: EngineSettings = EngineSettings(), analysisTimeoutSeconds: UInt64 = 300) throws {
        self.analysisTimeoutSeconds = min(3600, max(1, analysisTimeoutSeconds))
        guard let path = executablePath ?? EngineLocator.locateEngine() else {
            throw EngineError.binaryNotFound("Kein Stockfish in Bundle oder Standardpfaden gefunden.")
        }
        self.executablePath = path
        self.settings = settings
        signal(SIGPIPE, SIG_IGN)
    }

    deinit {
        readerTask?.cancel()
        analysisTimeout?.cancel()
        if let process { Self.shutdown(process) }
        #if canImport(AppKit)
        if let appTerminationObserver { NotificationCenter.default.removeObserver(appTerminationObserver) }
        #endif
    }

    public func start() async throws {
        try beginRequest()
        defer { busy = false }
        try await ensureReady()
    }

    public func stop() async {
        terminateProcess(error: EngineError.cancelled)
    }

    public func setOption(name: String, value: String) async throws {
        try beginRequest()
        defer { busy = false }
        try await ensureReady()
        try sendLine("setoption name \(name) value \(value)")
        _ = try await command("isready", expecting: "readyok", timeoutMs: 4000)
        switch name {
        case "Threads": if let number = Int(value) { settings.threads = max(1, number) }
        case "Hash": if let number = Int(value) { settings.hashMB = max(1, number) }
        case "Skill Level": if let number = Int(value) { settings.skillLevel = min(20, max(0, number)) }
        case "UCI_LimitStrength": settings.limitStrength = value.lowercased() == "true"
        case "UCI_Elo": if let number = Int(value) { settings.uciElo = min(3190, max(1320, number)) }
        default: break
        }
    }

    public nonisolated func analyze(fen: String, depth: Int, multiPV: Int) -> AsyncStream<EngineInfo> {
        AsyncStream { continuation in
            let id = UUID()
            let task = Task {
                do {
                    try await self.startAnalysis(fen: fen, depth: depth, multiPV: multiPV, id: id, continuation: continuation)
                } catch {
                    continuation.finish()
                }
            }
            continuation.onTermination = { [weak self] _ in
                task.cancel()
                Task { await self?.cancelAnalysis(id: id) }
            }
        }
    }

    public func bestMove(fen: String, movetimeMs: Int) async throws -> String {
        try beginRequest()
        defer { busy = false }
        try await ensureReady()
        _ = try Position(fen: fen)
        sideToMove = UCIParser.sideToMove(fromFEN: fen)
        try sendLine("setoption name MultiPV value 1")
        try sendLine("position fen \(fen)")
        let time = min(max(1, movetimeMs), 3_600_000)
        let line = try await command("go movetime \(time)", expecting: "bestmove", timeoutMs: max(time + 4000, 5000))
        guard let move = UCIParser.parseBestMoveLine(line)?.move, !move.isEmpty else {
            throw EngineError.unexpectedResponse(line)
        }
        return move
    }

    private func beginRequest() throws {
        try Task.checkCancellation()
        guard !busy, analysisID == nil else {
            throw EngineError.unexpectedResponse("Die Engine bearbeitet bereits einen Auftrag.")
        }
        busy = true
    }

    private func ensureReady() async throws {
        if let process, process.isRunning { return }
        terminateProcess(error: EngineError.processTerminated)
        guard EngineLocator.isUsableExecutable(atPath: executablePath) else {
            throw EngineError.binaryNotFound(executablePath)
        }
        let newProcess = Process()
        let inPipe = Pipe()
        let outPipe = Pipe()
        newProcess.executableURL = URL(fileURLWithPath: executablePath)
        newProcess.standardInput = inPipe
        newProcess.standardOutput = outPipe
        newProcess.standardError = FileHandle.nullDevice
        do { try newProcess.run() }
        catch { throw EngineError.failedToStart(error.localizedDescription) }
        process = newProcess
        input = inPipe
        let id = UUID()
        processID = id
        #if canImport(AppKit)
        if let appTerminationObserver { NotificationCenter.default.removeObserver(appTerminationObserver) }
        appTerminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak newProcess] _ in
            if let newProcess { Self.shutdown(newProcess) }
        }
        #endif
        readerTask = Task.detached(priority: .utility) { [weak self] in
            do {
                for try await line in outPipe.fileHandleForReading.bytes.lines {
                    await self?.handleOutput(line, processID: id)
                }
            } catch { }
            await self?.readerEnded(processID: id)
        }
        _ = try await command("uci", expecting: "uciok", timeoutMs: 4000)
        for (name, value) in settings.uciOptions {
            try sendLine("setoption name \(name) value \(value)")
        }
        _ = try await command("isready", expecting: "readyok", timeoutMs: 4000)
    }

    /// Installiert den Empfänger vor dem Schreiben, damit schnelle Antworten nicht verloren gehen.
    private func command(_ command: String, expecting: String, timeoutMs: Int) async throws -> String {
        let id = UUID()
        if Task.isCancelled {
            terminateProcess(error: CancellationError())
            throw CancellationError()
        }
        return try await withTaskCancellationHandler {
            let timeout = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000) }
                catch { return }
                await self?.cancelResponse(id: id, error: EngineError.timeout)
            }
            defer { timeout.cancel() }
            return try await withCheckedThrowingContinuation { continuation in
                responseID = id
                expectedResponse = expecting
                responseContinuation = continuation
                do { try sendLine(command) }
                catch { terminateProcess(error: error) }
            }
        } onCancel: {
            Task { await self.cancelResponse(id: id, error: CancellationError()) }
        }
    }

    private func cancelResponse(id: UUID, error: Error) {
        guard responseID == id else { return }
        terminateProcess(error: error)
    }

    private func startAnalysis(fen: String, depth: Int, multiPV: Int, id: UUID,
                               continuation: AsyncStream<EngineInfo>.Continuation) async throws {
        try beginRequest()
        defer { busy = false }
        try await ensureReady()
        try Task.checkCancellation()
        _ = try Position(fen: fen)
        sideToMove = UCIParser.sideToMove(fromFEN: fen)
        analysisID = id
        analysisContinuation = continuation
        do {
            try sendLine("setoption name MultiPV value \(max(1, multiPV))")
            try sendLine("position fen \(fen)")
            try sendLine("go depth \(max(1, depth))")
        } catch {
            terminateProcess(error: error)
            throw error
        }
        let timeout = analysisTimeoutSeconds
        analysisTimeout = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: timeout * 1_000_000_000) }
            catch { return }
            await self?.cancelAnalysis(id: id)
        }
    }

    private func cancelAnalysis(id: UUID) {
        guard analysisID == id else { return }
        terminateProcess(error: EngineError.cancelled)
    }

    private func handleOutput(_ line: String, processID id: UUID) {
        guard processID == id else { return }
        let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if let expectedResponse, line == expectedResponse || line.hasPrefix(expectedResponse + " ") {
            let continuation = responseContinuation
            responseContinuation = nil
            responseID = nil
            self.expectedResponse = nil
            continuation?.resume(returning: line)
        }
        if line.hasPrefix("info "), let continuation = analysisContinuation,
           let info = UCIParser.parseEngineInfo(line: line, sideToMove: sideToMove) {
            continuation.yield(info)
        }
        if line.hasPrefix("bestmove ") { finishAnalysis() }
    }

    private func readerEnded(processID id: UUID) {
        guard processID == id else { return }
        terminateProcess(error: EngineError.processTerminated)
    }

    private func finishAnalysis() {
        analysisTimeout?.cancel()
        analysisTimeout = nil
        let continuation = analysisContinuation
        analysisContinuation = nil
        analysisID = nil
        continuation?.finish()
    }

    private func terminateProcess(error: Error) {
        processID = nil
        readerTask?.cancel()
        readerTask = nil
        let oldProcess = process
        process = nil
        try? input?.fileHandleForWriting.close()
        input = nil
        if let oldProcess { Self.shutdown(oldProcess) }
        let continuation = responseContinuation
        responseContinuation = nil
        responseID = nil
        expectedResponse = nil
        continuation?.resume(throwing: error)
        finishAnalysis()
    }

    private nonisolated static func shutdown(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        // Ein defektes Binary darf nach Abbruch keine Hintergrundsuche fortsetzen.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }

    private func sendLine(_ line: String) throws {
        guard !line.contains("\n"), !line.contains("\r") else {
            throw EngineError.unexpectedResponse("UCI-Kommandos dürfen keine Zeilenumbrüche enthalten.")
        }
        guard let input, let process, process.isRunning else { throw EngineError.notRunning }
        try input.fileHandleForWriting.write(contentsOf: Data((line + "\n").utf8))
    }
}
