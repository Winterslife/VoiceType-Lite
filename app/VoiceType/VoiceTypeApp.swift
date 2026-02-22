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

                // Microphone selector
                Menu {
                    Button {
                        appState.selectInputDevice(nil)
                    } label: {
                        HStack {
                            Text("System Default")
                            if appState.selectedDeviceID == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    if !appState.inputDevices.isEmpty {
                        Divider()
                        ForEach(appState.inputDevices) { device in
                            Button {
                                appState.selectInputDevice(device.id)
                            } label: {
                                HStack {
                                    Text(device.name)
                                    if appState.selectedDeviceID == device.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Label(selectedMicName, systemImage: "mic")
                }
                .onAppear {
                    appState.refreshInputDevices()
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

    private var selectedMicName: String {
        if let id = appState.selectedDeviceID,
           let device = appState.inputDevices.first(where: { $0.id == id }) {
            return device.name
        }
        return "Microphone"
    }
}
