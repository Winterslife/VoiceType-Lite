import SwiftUI

@main
struct VoiceTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 4) {
                Text(statusText)
                    .font(.headline)

                if let last = appState.lastTranscription {
                    Divider()
                    Text(last)
                        .font(.body)
                        .lineLimit(3)
                }

                Divider()

                Text("Right Option: push-to-talk")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding(4)
            .task {
                appState.attachBackend(appDelegate.backendManager)
                appDelegate.appState = appState
                appState.startListening()
            }
        } label: {
            Image(systemName: menuBarIcon)
        }
        .menuBarExtraStyle(.menu)
    }

    private var menuBarIcon: String {
        switch appState.status {
        case .idle:
            return appState.backendAvailable ? "mic.fill" : "mic.slash.fill"
        case .recording:
            return "record.circle"
        case .processing:
            return "ellipsis.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    private var statusText: String {
        switch appState.status {
        case .idle:
            return appState.backendAvailable ? "Ready" : "Backend offline"
        case .recording:
            return "Recording..."
        case .processing:
            return "Transcribing..."
        case .error(let message):
            return message
        }
    }
}
