import Cocoa

final class HotkeyListener {
    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isKeyDown = false

    // kVK_RightOption = 61
    private let rightOptionKeyCode: UInt16 = 61

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard event.keyCode == rightOptionKeyCode else { return }

        let optionPressed = event.modifierFlags.contains(.option)

        if optionPressed && !isKeyDown {
            isKeyDown = true
            onHotkeyDown?()
        } else if !optionPressed && isKeyDown {
            isKeyDown = false
            onHotkeyUp?()
        }
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    deinit {
        stop()
    }
}
