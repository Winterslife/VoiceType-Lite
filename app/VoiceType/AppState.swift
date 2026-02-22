import Cocoa
import CoreAudio
import SwiftUI

enum AppStatus: Equatable {
    case idle
    case recording
    case processing
    case error(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published var status: AppStatus = .idle
    @Published var backendAvailable = false
    @Published var lastTranscription: String?
    @Published var inputDevices: [AudioInputDevice] = []
    @Published var selectedDeviceID: AudioDeviceID? = nil

    let audioRecorder = AudioRecorder()
    let hotkeyListener = HotkeyListener()
    let transcriptionClient = TranscriptionClient()
    let textInserter = TextInserter()

    private(set) var backendManager: BackendManager?
    private var healthCheckTask: Task<Void, Never>?
    private var isListening = false
    private var isHealthChecking = false

    init() {
        refreshInputDevices()
        // Start health checks immediately if setup is already done.
        // Hotkey listener is deferred to avoid interfering with
        // MenuBarExtra's event handling during scene setup.
        let marker = BackendManager.venvDir
            .appendingPathComponent("setup_complete").path
        if FileManager.default.fileExists(atPath: marker) {
            startHealthChecks()
            // Defer hotkey listener so MenuBarExtra can fully initialize first.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.startHotkeyListener()
            }
        }
    }

    func refreshInputDevices() {
        inputDevices = AudioRecorder.availableInputDevices()
    }

    func selectInputDevice(_ deviceID: AudioDeviceID?) {
        selectedDeviceID = deviceID
        audioRecorder.selectedDeviceID = deviceID
    }

    func attachBackend(_ manager: BackendManager) {
        self.backendManager = manager
    }

    /// Start hotkey listener + health checks.
    /// Safe to call multiple times — only starts once, and only if setup is complete.
    func startListening() {
        let marker = BackendManager.venvDir
            .appendingPathComponent("setup_complete").path
        guard FileManager.default.fileExists(atPath: marker) else { return }

        startHealthChecks()
        // Defer hotkey listener to avoid interfering with MenuBarExtra.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.startHotkeyListener()
        }
    }

    private func startHotkeyListener() {
        guard !isListening else { return }
        isListening = true

        hotkeyListener.onHotkeyDown = { [weak self] in
            Task { @MainActor in
                self?.handleHotkeyDown()
            }
        }

        hotkeyListener.onHotkeyUp = { [weak self] in
            Task { @MainActor in
                self?.handleHotkeyUp()
            }
        }

        hotkeyListener.start()
    }

    // MARK: - Hotkey Handling

    private func handleHotkeyDown() {
        guard status == .idle, backendAvailable else { return }

        // Prompt for Accessibility on first use (needed for CGEvent paste).
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            return
        }

        do {
            try audioRecorder.startRecording()
            status = .recording
        } catch {
            showError("Mic error: \(error.localizedDescription)")
        }
    }

    private func handleHotkeyUp() {
        guard status == .recording else { return }

        guard let wavData = audioRecorder.stopRecordingAndGetWAV() else {
            status = .idle
            return
        }

        status = .processing

        Task {
            do {
                let text = try await transcriptionClient.transcribe(wavData: wavData)
                if !text.isEmpty {
                    lastTranscription = text
                    textInserter.insertText(text)
                }
                status = .idle
            } catch {
                showError("Transcription failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Health Check

    private func startHealthChecks() {
        guard !isHealthChecking else { return }
        isHealthChecking = true

        healthCheckTask = Task {
            while !Task.isCancelled {
                let healthy = await transcriptionClient.isHealthy()
                self.backendAvailable = healthy
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    // MARK: - Error

    private func showError(_ message: String) {
        status = .error(message)
        Task {
            try? await Task.sleep(for: .seconds(2))
            if case .error = self.status {
                self.status = .idle
            }
        }
    }

    deinit {
        healthCheckTask?.cancel()
        hotkeyListener.stop()
    }
}
