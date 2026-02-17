import Foundation

@MainActor
final class BackendManager: ObservableObject {
    @Published var isRunning = false

    private var process: Process?
    private var outputPipe: Pipe?

    // MARK: - Paths

    static let supportDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("VoiceType-Lite")
    }()

    static var venvDir: URL {
        supportDir.appendingPathComponent("venv")
    }

    static var pythonPath: String {
        venvDir.appendingPathComponent("bin/python3").path
    }

    static var backendResourceDir: URL {
        Bundle.main.resourceURL!.appendingPathComponent("Resources/backend")
    }

    static var uvBinaryPath: String {
        Bundle.main.resourceURL!.appendingPathComponent("Resources/uv").path
    }

    var isSetupComplete: Bool {
        let marker = Self.venvDir.appendingPathComponent("setup_complete").path
        let pythonExists = FileManager.default.fileExists(atPath: Self.pythonPath)
        let markerExists = FileManager.default.fileExists(atPath: marker)
        return pythonExists && markerExists
    }

    // MARK: - Start Backend

    func startBackend() {
        guard !isRunning else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: Self.pythonPath)
        proc.arguments = [
            "-m", "uvicorn", "server:app",
            "--host", "127.0.0.1",
            "--port", "8766",
            "--workers", "1",
        ]
        proc.currentDirectoryURL = Self.backendResourceDir

        // Inherit environment and set PATH to include venv bin
        var env = ProcessInfo.processInfo.environment
        let venvBin = Self.venvDir.appendingPathComponent("bin").path
        env["PATH"] = venvBin + ":" + (env["PATH"] ?? "/usr/bin:/bin")
        env["VIRTUAL_ENV"] = Self.venvDir.path
        proc.environment = env

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        outputPipe = pipe

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.isRunning = false
            }
        }

        do {
            try proc.run()
            process = proc
            isRunning = true
        } catch {
            print("Failed to start backend: \(error)")
            isRunning = false
        }
    }

    // MARK: - Stop Backend

    func stopBackend() {
        guard let proc = process, proc.isRunning else { return }
        proc.terminate()
        process = nil
        isRunning = false
    }
}
