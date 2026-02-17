import SwiftUI

struct SetupView: View {
    @ObservedObject var manager: SetupManager
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("VoiceType-Lite Setup")
                .font(.title)
                .fontWeight(.bold)

            Text("VoiceType-Lite needs to download Python, dependencies, and the ASR model.\nThis requires ~2GB of disk space.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.body)

            // Progress area — also keep visible on error so the user can read the log
            if manager.isRunning || manager.isComplete || manager.errorMessage != nil {
                VStack(alignment: .leading, spacing: 8) {
                    if let step = manager.currentStep {
                        Text(step.description)
                            .font(.callout)
                            .fontWeight(.medium)
                    }

                    ProgressView(value: manager.progress)
                        .progressViewStyle(.linear)

                    Text("\(Int(manager.progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Log area
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(manager.logOutput)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id("logBottom")
                    }
                    .frame(maxHeight: 200)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .onChange(of: manager.logOutput) { _ in
                        proxy.scrollTo("logBottom", anchor: .bottom)
                    }
                }
                .padding(.horizontal)
            }

            // Error message
            if let error = manager.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            // Buttons
            HStack(spacing: 12) {
                if manager.isComplete {
                    Button("Done") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if manager.errorMessage != nil {
                    Button("Retry") {
                        Task { await manager.runSetup() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if !manager.isRunning {
                    Button("Start Setup") {
                        Task { await manager.runSetup() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    ProgressView()
                        .controlSize(.small)
                    Text("Installing...")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(30)
        .frame(width: 600, height: 500)
    }
}
