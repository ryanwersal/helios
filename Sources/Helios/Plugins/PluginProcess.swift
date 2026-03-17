import Foundation

actor PluginProcess {
    let pluginName: String
    private let executableURL: URL
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var stdoutBuffer: String = ""
    private var responseContinuations: [String: CheckedContinuation<PluginResponse, Error>] = [:]
    private var timeoutTasks: [String: Task<Void, Never>] = [:]
    private var readyContinuation: CheckedContinuation<Void, Error>?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var isRunning = false

    init(name: String, executableURL: URL) {
        pluginName = name
        self.executableURL = executableURL
    }

    func launch() async throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = []

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe

        let pluginName = pluginName
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let text = String(data: data, encoding: .utf8) else { return }
            Task { await self?.handleStdoutData(text) }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            NSLog("[Helios] Plugin '%@' stderr: %@", pluginName, text.trimmingCharacters(in: .newlines))
        }

        process.terminationHandler = { [weak self] proc in
            let code = proc.terminationStatus
            NSLog("[Helios] Plugin '%@' exited with code %d", pluginName, code)
            Task { await self?.handleTermination() }
        }

        try process.run()
        isRunning = true

        try sendRequest(.initialize())

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            readyContinuation = continuation

            Task {
                try await Task.sleep(for: .seconds(5))
                self.handleReadyTimeout()
            }
        }
    }

    private func handleReadyTimeout() {
        if let continuation = readyContinuation {
            readyContinuation = nil
            continuation.resume(throwing: PluginError.initTimeout)
        }
    }

    func search(query: String, id: String) async throws -> PluginResponse {
        try await withCheckedThrowingContinuation { continuation in
            responseContinuations[id] = continuation

            do {
                try sendRequest(.search(query: query, id: id))
            } catch {
                responseContinuations.removeValue(forKey: id)
                continuation.resume(throwing: error)
                return
            }

            timeoutTasks[id] = Task { [weak self] in
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    return
                }
                await self?.expireSearch(id: id)
            }
        }
    }

    private func expireSearch(id: String) {
        timeoutTasks.removeValue(forKey: id)
        if let continuation = responseContinuations.removeValue(forKey: id) {
            NSLog("[Helios] Plugin '%@' search timed out (id: %@)", pluginName, id)
            continuation.resume(throwing: PluginError.searchTimeout)
        }
    }

    func shutdown() {
        guard isRunning else { return }
        try? sendRequest(.shutdown())

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            await self?.forceTerminate()
        }
    }

    private func forceTerminate() {
        if let process, process.isRunning {
            process.terminate()
        }
        cleanup()
    }

    private func sendRequest(_ request: PluginRequest) throws {
        guard let stdinPipe else { throw PluginError.notRunning }
        var data = try encoder.encode(request)
        data.append(contentsOf: [UInt8(ascii: "\n")])
        stdinPipe.fileHandleForWriting.write(data)
    }

    private func handleStdoutData(_ text: String) {
        stdoutBuffer += text

        while let newlineIndex = stdoutBuffer.firstIndex(of: "\n") {
            let line = String(stdoutBuffer[stdoutBuffer.startIndex ..< newlineIndex])
            stdoutBuffer = String(stdoutBuffer[stdoutBuffer.index(after: newlineIndex)...])

            guard !line.isEmpty else { continue }
            processLine(line)
        }
    }

    private func processLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let response = try? decoder.decode(PluginResponse.self, from: data)
        else {
            NSLog("[Helios] Plugin '%@' sent invalid JSON: %@", pluginName, line)
            return
        }

        switch response.type {
        case .ready:
            if let continuation = readyContinuation {
                readyContinuation = nil
                continuation.resume()
            }
        case .results:
            if let id = response.id {
                timeoutTasks.removeValue(forKey: id)?.cancel()
                if let continuation = responseContinuations.removeValue(forKey: id) {
                    continuation.resume(returning: response)
                }
            }
        }
    }

    private func handleTermination() {
        if let continuation = readyContinuation {
            readyContinuation = nil
            continuation.resume(throwing: PluginError.crashed)
        }
        isRunning = false
        cleanup()
    }

    private func cleanup() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stdinPipe?.fileHandleForWriting.closeFile()
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        process = nil
        isRunning = false
        for continuation in responseContinuations.values {
            continuation.resume(throwing: PluginError.crashed)
        }
        responseContinuations.removeAll()
        for task in timeoutTasks.values {
            task.cancel()
        }
        timeoutTasks.removeAll()
        if let continuation = readyContinuation {
            readyContinuation = nil
            continuation.resume(throwing: PluginError.crashed)
        }
    }
}

enum PluginError: Error {
    case initTimeout
    case notRunning
    case crashed
    case searchTimeout
}
