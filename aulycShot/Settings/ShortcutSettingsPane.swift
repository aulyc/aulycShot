import AppKit
import Carbon

extension SettingsView {
    func buildShortcutsPane() -> NSView {
        let stack = paneStack(spacing: 0)
        shortcutRows.removeAll()

        for slot in HotkeySlot.allCases {
            let row = buildShortcutCard(
                title: slot.localizedHeader,
                setAction: #selector(shortcutSetClicked(_:))
            )
            row.setButton.identifier = NSUserInterfaceItemIdentifier(slot.rawValue)
            shortcutRows[slot] = ShortcutRowControls(
                title: row.title,
                field: row.field,
                setButton: row.setButton
            )
            stack.addArrangedSubview(row.card)
            row.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        return wrapPane(stack, topInset: 0)
    }

    // MARK: - Shortcut recording

    private func presentHotkeyConflictAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.shortcutConflictTitle
        alert.informativeText = message
        alert.alertStyle = .warning
        if let window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    private func presentShortcutNeedsModifierAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.shortcutNeedsModifierTitle
        alert.informativeText = L10n.shortcutNeedsModifier
        alert.alertStyle = .warning
        if let window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    @objc private func shortcutSetClicked(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
              let slot = HotkeySlot(rawValue: rawValue)
        else {
            return
        }

        if recordingShortcutSlot == slot {
            cancelShortcutRecording()
            return
        }

        cancelShortcutRecording()
        HotkeyManager.shared.beginRecording()
        recordingShortcutSlot = slot
        refreshShortcutDisplay(for: slot)

        shortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            self?.handleRecordedShortcut(event, for: slot) ?? event
        }
    }

    private func handleRecordedShortcut(_ event: NSEvent, for slot: HotkeySlot) -> NSEvent? {
        let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let pressedModifiers = event.modifierFlags.intersection(activeModifierMask)
        if event.keyCode == UInt16(kVK_Escape), pressedModifiers.isEmpty {
            cancelShortcutRecording()
            return nil
        }

        let keyCode = UInt32(event.keyCode)
        let modifiers = carbonModifiers(from: pressedModifiers)
        if !slot.descriptor.allowsBareKey,
           modifiers == 0,
           !HotkeyManager.isFunctionKey(keyCode) {
            cancelShortcutRecording()
            presentShortcutNeedsModifierAlert()
            return nil
        }

        if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
            forKeyCode: keyCode,
            modifiers: modifiers,
            assigningTo: slot
        ) {
            cancelShortcutRecording()
            presentHotkeyConflictAlert(conflict)
            return nil
        }

        Defaults.setHotkey(
            HotkeyBinding(keyCode: keyCode, modifiers: modifiers),
            for: slot
        )
        finishShortcutRecording()
        return nil
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        return modifiers
    }

    private func finishShortcutRecording() {
        let slot = recordingShortcutSlot
        removeShortcutRecordingMonitor()
        recordingShortcutSlot = nil
        HotkeyManager.shared.endRecording()
        if let slot {
            refreshShortcutDisplay(for: slot)
        }
    }

    func cancelShortcutRecording() {
        guard shortcutRecordingMonitor != nil || recordingShortcutSlot != nil else { return }
        let slot = recordingShortcutSlot
        removeShortcutRecordingMonitor()
        recordingShortcutSlot = nil
        HotkeyManager.shared.endRecording()
        if let slot {
            refreshShortcutDisplay(for: slot)
        }
    }

    private func removeShortcutRecordingMonitor() {
        if let monitor = shortcutRecordingMonitor {
            NSEvent.removeMonitor(monitor)
            shortcutRecordingMonitor = nil
        }
    }

    func refreshShortcutDisplays() {
        for slot in HotkeySlot.allCases {
            refreshShortcutDisplay(for: slot)
        }
    }

    private func refreshShortcutDisplay(for slot: HotkeySlot) {
        guard let controls = shortcutRows[slot] else { return }
        let isRecording = recordingShortcutSlot == slot
        controls.setButton.title = isRecording ? L10n.shortcutCancel : L10n.shortcutSet
        if isRecording {
            controls.field.stringValue = L10n.shortcutWaiting
        } else {
            controls.field.stringValue = HotkeyManager.currentDisplayString(for: slot)
                ?? slot.localizedDefaultDisplay
        }
    }

    @objc func detailResetClicked() {
        switch selectedTab {
        case .shortcuts:
            resetShortcutsToDefault()
        case .toolbar:
            toolbarSettingsPane?.resetToDefault()
        case .general, .about:
            break
        }
    }

    private func resetShortcutsToDefault() {
        cancelShortcutRecording()
        Defaults.resetShortcutHotkeysToDefaults()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshShortcutDisplays()
    }
}
