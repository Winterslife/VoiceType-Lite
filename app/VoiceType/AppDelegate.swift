import Cocoa
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let backendManager = BackendManager()
    weak var appState: AppState?
    private var setupWindow: NSWindow?
    private var setupManager: SetupManager?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // If setup is needed, become a regular app EARLY — before any window
        // is created. LSUIElement apps must switch policy before showing
        // interactive windows, and the switch needs a run-loop cycle.
        if !backendManager.isSetupComplete && !isPortOpen(port: 8766) {
            NSApp.setActivationPolicy(.regular)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if backendManager.isSetupComplete {
            backendManager.startBackend()
        } else if isPortOpen(port: 8766) {
            // Dev mode — backend already running via manual ./start.sh
        } else {
            showSetupWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if backendManager.isRunning {
            backendManager.stopBackend()
        }
    }

    // MARK: - Port Check

    private nonisolated func isPortOpen(port: UInt16) -> Bool {
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { Darwin.close(fd) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }

    // MARK: - Setup Window

    private func showSetupWindow() {
        // Activation policy already set to .regular in willFinishLaunching
        let manager = SetupManager()
        self.setupManager = manager

        let setupView = SetupView(manager: manager) { [weak self] in
            self?.onSetupComplete()
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoiceType-Lite Setup"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: setupView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.setupWindow = window
    }

    private func onSetupComplete() {
        setupWindow?.close()
        setupWindow = nil
        setupManager = nil

        NSApp.setActivationPolicy(.accessory)

        backendManager.startBackend()
        appState?.startListening()
    }
}
