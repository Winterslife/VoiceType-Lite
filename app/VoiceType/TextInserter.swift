import Cocoa

final class TextInserter {
    func insertText(_ text: String) {
        let pasteboard = NSPasteboard.general

        // 1. Backup current pasteboard contents
        let backup = backupPasteboard(pasteboard)

        // 2. Set our text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Simulate Cmd+V
        simulatePaste()

        // 4. Restore pasteboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.restorePasteboard(pasteboard, from: backup)
        }
    }

    // MARK: - Pasteboard Backup/Restore

    private struct PasteboardItem {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    private func backupPasteboard(_ pasteboard: NSPasteboard) -> [[PasteboardItem]] {
        var backup: [[PasteboardItem]] = []
        guard let items = pasteboard.pasteboardItems else { return backup }

        for item in items {
            var itemBackup: [PasteboardItem] = []
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemBackup.append(PasteboardItem(type: type, data: data))
                }
            }
            backup.append(itemBackup)
        }
        return backup
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, from backup: [[PasteboardItem]]) {
        pasteboard.clearContents()
        guard !backup.isEmpty else { return }

        var newItems: [NSPasteboardItem] = []
        for itemBackup in backup {
            let item = NSPasteboardItem()
            for entry in itemBackup {
                item.setData(entry.data, forType: entry.type)
            }
            newItems.append(item)
        }
        pasteboard.writeObjects(newItems)
    }

    // MARK: - Key Simulation

    private func simulatePaste() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("[VoiceType] ⚠️ Accessibility NOT granted — CGEvent paste will fail")
            print("[VoiceType] → System Settings > Privacy & Security > Accessibility > enable VoiceType")
            return
        }

        // keyCode 9 = V
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false)

        guard let keyDown, let keyUp else {
            print("[VoiceType] ⚠️ Failed to create CGEvent")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
