import Foundation

enum SetupStep: Int, CaseIterable {
    case createDirectories = 0
    case downloadUV
    case createVenv
    case installDependencies
    case downloadModel
    case writeMarker

    var description: String {
        switch self {
        case .createDirectories: return "Creating directories..."
        case .downloadUV: return "Downloading uv package manager..."
        case .createVenv: return "Setting up Python 3.12 environment..."
        case .installDependencies: return "Installing Python dependencies (~1GB)..."
        case .downloadModel: return "Downloading ASR model (~600MB)..."
        case .writeMarker: return "Finalizing setup..."
        }
    }
}

@MainActor
final class SetupManager: ObservableObject {
    @Published var currentStep: SetupStep?
    @Published var progress: Double = 0
    @Published var logOutput: String = ""
    @Published var isRunning = false
    @Published var isComplete = false
    @Published var errorMessage: String?

    private var currentProcess: Process?

    private let totalSteps = Double(SetupStep.allCases.count)

    /// uv binary path — downloaded to Application Support (not bundled)
    private var uvPath: String {
        BackendManager.supportDir.appendingPathComponent("uv").path
    }

    func runSetup() async {
        isRunning = true
        isComplete = false
        errorMessage = nil
        logOutput = ""
        progress = 0

        do {
            // Step 1: Create directories
            try await runStep(.createDirectories) {
                try FileManager.default.createDirectory(
                    at: BackendManager.supportDir,
                    withIntermediateDirectories: true
                )
                self.appendLog("Created \(BackendManager.supportDir.path)\n")
            }

            // Step 2: Download uv binary (avoids Gatekeeper issues with bundled binaries)
            try await runStep(.downloadUV) {
                if FileManager.default.fileExists(atPath: self.uvPath) {
                    self.appendLog("uv already exists, skipping download.\n")
                    return
                }

                let arch = Self.machineArchitecture()
                let archStr = arch == "arm64" ? "aarch64" : "x86_64"
                let url = "https://github.com/astral-sh/uv/releases/latest/download/uv-\(archStr)-apple-darwin.tar.gz"
                let tarball = BackendManager.supportDir.appendingPathComponent("uv.tar.gz").path

                self.appendLog("Architecture: \(arch)\n")
                self.appendLog("Downloading uv from \(url)\n")

                try await self.runProcess(
                    executablePath: "/usr/bin/curl",
                    arguments: ["-fsSL", url, "-o", tarball]
                )

                // Extract uv binary from tarball
                try await self.runProcess(
                    executablePath: "/usr/bin/tar",
                    arguments: ["-xzf", tarball, "-C", BackendManager.supportDir.path, "--strip-components=1"]
                )

                // Clean up tarball
                try? FileManager.default.removeItem(atPath: tarball)

                // Ensure executable
                self.runShell("/bin/chmod", arguments: ["+x", self.uvPath])
                self.appendLog("uv ready at \(self.uvPath)\n")
            }

            // Step 3: Create venv with uv
            try await runStep(.createVenv) {
                // Verify uv binary works
                self.appendLog("uv path: \(self.uvPath)\n")
                try await self.runProcess(
                    executablePath: self.uvPath,
                    arguments: ["--version"]
                )

                // Remove leftover venv from a previous failed attempt
                let venvDir = BackendManager.venvDir
                if FileManager.default.fileExists(atPath: venvDir.path) {
                    self.appendLog("Removing leftover venv directory...\n")
                    try FileManager.default.removeItem(at: venvDir)
                }

                self.appendLog("Creating venv at \(venvDir.path)\n")
                try await self.runProcess(
                    executablePath: self.uvPath,
                    arguments: [
                        "venv",
                        "--python", "3.10",
                        "--verbose",
                        venvDir.path,
                    ]
                )
            }

            // Step 4: Install dependencies
            try await runStep(.installDependencies) {
                let requirementsPath = BackendManager.backendResourceDir
                    .appendingPathComponent("requirements.txt").path
                try await self.runProcess(
                    executablePath: self.uvPath,
                    arguments: [
                        "pip", "install",
                        "--python", BackendManager.pythonPath,
                        "-r", requirementsPath,
                    ]
                )
            }

            // Step 5: Download model
            try await runStep(.downloadModel) {
                try await self.runProcess(
                    executablePath: BackendManager.pythonPath,
                    arguments: [
                        "-c",
                        "from funasr import AutoModel; AutoModel(model='iic/SenseVoiceSmall', trust_remote_code=True, device='cpu')",
                    ]
                )
            }

            // Step 6: Write marker
            try await runStep(.writeMarker) {
                let markerPath = BackendManager.venvDir.appendingPathComponent("setup_complete")
                try "done".write(to: markerPath, atomically: true, encoding: .utf8)
                self.appendLog("Setup complete!\n")
            }

            isComplete = true
        } catch is CancellationError {
            appendLog("\nSetup cancelled.")
        } catch {
            errorMessage = error.localizedDescription
            appendLog("\nError: \(error.localizedDescription)")
        }

        isRunning = false
    }

    func cancel() {
        currentProcess?.terminate()
        currentProcess = nil
    }

    // MARK: - Helpers

    private static func machineArchitecture() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        return withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
    }

    private func runStep(_ step: SetupStep, action: @escaping () async throws -> Void) async throws {
        currentStep = step
        appendLog("\n[\(step.description)]\n")
        try await action()
        progress = Double(step.rawValue + 1) / totalSteps
    }

    private func runProcess(executablePath: String, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            var env = ProcessInfo.processInfo.environment
            let venvBin = BackendManager.venvDir.appendingPathComponent("bin").path
            env["PATH"] = venvBin + ":" + (env["PATH"] ?? "/usr/bin:/bin")
            process.environment = env

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let handle = pipe.fileHandleForReading
            handle.readabilityHandler = { [weak self] fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor [weak self] in
                    self?.appendLog(text)
                }
            }

            process.terminationHandler = { proc in
                handle.readabilityHandler = nil
                let remaining = handle.readDataToEndOfFile()
                if !remaining.isEmpty, let text = String(data: remaining, encoding: .utf8) {
                    Task { @MainActor [weak self] in
                        self?.appendLog(text)
                    }
                }

                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: SetupError.processExitCode(Int(proc.terminationStatus)))
                }
            }

            do {
                self.currentProcess = process
                try process.run()
            } catch {
                self.currentProcess = nil
                continuation.resume(throwing: error)
            }
        }
        currentProcess = nil
    }

    private func runShell(_ path: String, arguments: [String]) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = arguments
        try? proc.run()
        proc.waitUntilExit()
    }

    private func appendLog(_ text: String) {
        logOutput += text
    }
}

enum SetupError: LocalizedError {
    case processExitCode(Int)

    var errorDescription: String? {
        switch self {
        case .processExitCode(let code):
            return "Process exited with code \(code)"
        }
    }
}
