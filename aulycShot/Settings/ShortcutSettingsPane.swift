import AppKit
import Carbon

extension SettingsView {
func buildShortcutsPane() -> NSView {
        let stack = paneStack(spacing: 0)

        // Screenshot shortcut card
        let shortcut = buildShortcutCard(
            title: L10n.shortcutHeader,
            setAction: #selector(shortcutSetClicked)
        )
        shortcutTitleLabel = shortcut.title
        shortcutField = shortcut.field
        shortcutSetButton = shortcut.setButton
        stack.addArrangedSubview(shortcut.card)
        shortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Screenshot execution (editor confirm) shortcut card
        let clipboardShortcut = buildShortcutCard(
            title: L10n.clipboardShortcutHeader,
            setAction: #selector(clipboardShortcutSetClicked)
        )
        clipboardShortcutTitleLabel = clipboardShortcut.title
        clipboardShortcutField = clipboardShortcut.field
        clipboardShortcutSetButton = clipboardShortcut.setButton
        stack.addArrangedSubview(clipboardShortcut.card)
        clipboardShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Edit selected image shortcut card
        let selectedImageEditShortcut = buildShortcutCard(
            title: L10n.selectedImageEditShortcutHeader,
            setAction: #selector(selectedImageEditShortcutSetClicked)
        )
        selectedImageEditShortcutTitleLabel = selectedImageEditShortcut.title
        selectedImageEditShortcutField = selectedImageEditShortcut.field
        selectedImageEditShortcutSetButton = selectedImageEditShortcut.setButton
        stack.addArrangedSubview(selectedImageEditShortcut.card)
        selectedImageEditShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Edit clipboard image shortcut card
        let clipboardImageEditShortcut = buildShortcutCard(
            title: L10n.clipboardImageEditShortcutHeader,
            setAction: #selector(clipboardImageEditShortcutSetClicked)
        )
        clipboardImageEditShortcutTitleLabel = clipboardImageEditShortcut.title
        clipboardImageEditShortcutField = clipboardImageEditShortcut.field
        clipboardImageEditShortcutSetButton = clipboardImageEditShortcut.setButton
        stack.addArrangedSubview(clipboardImageEditShortcut.card)
        clipboardImageEditShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Pin selected image shortcut card
        let selectedImagePinShortcut = buildShortcutCard(
            title: L10n.selectedImagePinShortcutHeader,
            setAction: #selector(selectedImagePinShortcutSetClicked)
        )
        selectedImagePinShortcutTitleLabel = selectedImagePinShortcut.title
        selectedImagePinShortcutField = selectedImagePinShortcut.field
        selectedImagePinShortcutSetButton = selectedImagePinShortcut.setButton
        stack.addArrangedSubview(selectedImagePinShortcut.card)
        selectedImagePinShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Pin clipboard image shortcut card
        let clipboardImagePinShortcut = buildShortcutCard(
            title: L10n.clipboardImagePinShortcutHeader,
            setAction: #selector(clipboardImagePinShortcutSetClicked)
        )
        clipboardImagePinShortcutTitleLabel = clipboardImagePinShortcut.title
        clipboardImagePinShortcutField = clipboardImagePinShortcut.field
        clipboardImagePinShortcutSetButton = clipboardImagePinShortcut.setButton
        stack.addArrangedSubview(clipboardImagePinShortcut.card)
        clipboardImagePinShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Recording shortcut card
        let recordShortcut = buildShortcutCard(
            title: L10n.recordShortcutHeader,
            setAction: #selector(recordShortcutSetClicked)
        )
        recordShortcutTitleLabel = recordShortcut.title
        recordShortcutField = recordShortcut.field
        recordShortcutSetButton = recordShortcut.setButton
        stack.addArrangedSubview(recordShortcut.card)
        recordShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Image Merge shortcut card
        let imageMergeShortcut = buildShortcutCard(
            title: L10n.imageMergeShortcutHeader,
            setAction: #selector(imageMergeShortcutSetClicked)
        )
        imageMergeShortcutTitleLabel = imageMergeShortcut.title
        imageMergeShortcutField = imageMergeShortcut.field
        imageMergeShortcutSetButton = imageMergeShortcut.setButton
        stack.addArrangedSubview(imageMergeShortcut.card)
        imageMergeShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Pin clipboard text shortcut card
        let clipboardTextPinShortcut = buildShortcutCard(
            title: L10n.clipboardTextPinShortcutHeader,
            setAction: #selector(clipboardTextPinShortcutSetClicked)
        )
        clipboardTextPinShortcutTitleLabel = clipboardTextPinShortcut.title
        clipboardTextPinShortcutField = clipboardTextPinShortcut.field
        clipboardTextPinShortcutSetButton = clipboardTextPinShortcut.setButton
        stack.addArrangedSubview(clipboardTextPinShortcut.card)
        clipboardTextPinShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        return wrapPane(stack, topInset: 0)
    }

// MARK: - Shortcut recording

    /// Tells the user a recorded combo is already taken by another function,
    /// so they can pick a different one. Recording is already cancelled by the
    /// caller before this is shown.
    private func presentHotkeyConflictAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.shortcutConflictTitle
        alert.informativeText = message
        alert.alertStyle = .warning
        if let win = self.window {
            alert.beginSheetModal(for: win, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    /// Tells the user a recorded key needs a modifier held with it, so they
    /// can try again. Recording is already cancelled by the caller before
    /// this is shown.
    private func presentShortcutNeedsModifierAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.shortcutNeedsModifierTitle
        alert.informativeText = L10n.shortcutNeedsModifier
        alert.alertStyle = .warning
        if let win = self.window {
            alert.beginSheetModal(for: win, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    private func cancelShortcutRecordings(except slot: HotkeyManager.HotkeySlot) {
        if slot != .screenshot, shortcutRecordingMonitor != nil {
            cancelShortcutRecording()
        }
        if slot != .selectedImagePin, selectedImagePinShortcutRecordingMonitor != nil {
            cancelSelectedImagePinShortcutRecording()
        }
        if slot != .clipboardImagePin, clipboardImagePinShortcutRecordingMonitor != nil {
            cancelClipboardImagePinShortcutRecording()
        }
        if slot != .clipboardTextPin, clipboardTextPinShortcutRecordingMonitor != nil {
            cancelClipboardTextPinShortcutRecording()
        }
        if slot != .selectedImageEdit, selectedImageEditShortcutRecordingMonitor != nil {
            cancelSelectedImageEditShortcutRecording()
        }
        if slot != .clipboardImageEdit, clipboardImageEditShortcutRecordingMonitor != nil {
            cancelClipboardImageEditShortcutRecording()
        }
        if slot != .record, recordShortcutRecordingMonitor != nil {
            cancelRecordShortcutRecording()
        }
        if slot != .imageMerge, imageMergeShortcutRecordingMonitor != nil {
            cancelImageMergeShortcutRecording()
        }
        if slot != .clipboard, clipboardShortcutRecordingMonitor != nil {
            cancelClipboardShortcutRecording()
        }
    }

    @objc private func shortcutSetClicked() {
        if shortcutRecordingMonitor != nil {
            cancelShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .screenshot)
        HotkeyManager.shared.beginRecording()
        shortcutSetButton.title = L10n.shortcutCancel
        shortcutField.stringValue = L10n.shortcutWaiting

        shortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            // Reject bare keys (no modifier and not a function key) — the user must
            // hold at least one modifier so the shortcut won't collide with typing.
            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .screenshot) {
                self.cancelShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.screenshotHotkeyKeyCode = Int(keyCode)
            Defaults.screenshotHotkeyModifiers = Int(carbonMods)
            self.finishShortcutRecording()
            return nil
        }
    }

    private func finishShortcutRecording() {
        if let m = shortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            shortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshShortcutDisplay()
    }

    func cancelShortcutRecording() {
        guard shortcutRecordingMonitor != nil else { return }
        if let m = shortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            shortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshShortcutDisplay()
    }

    func refreshShortcutDisplay() {
        shortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentDisplayString() {
            shortcutField?.stringValue = display
        } else {
            shortcutField?.stringValue = L10n.shortcutDefaultDisplay
        }
    }

    @objc private func selectedImagePinShortcutSetClicked() {
        if selectedImagePinShortcutRecordingMonitor != nil {
            cancelSelectedImagePinShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .selectedImagePin)
        HotkeyManager.shared.beginRecording()
        selectedImagePinShortcutSetButton.title = L10n.shortcutCancel
        selectedImagePinShortcutField.stringValue = L10n.shortcutWaiting

        selectedImagePinShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelSelectedImagePinShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelSelectedImagePinShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            // No two functions may share a shortcut — reject a combo already
            // bound to the screenshot hotkey.
            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .selectedImagePin) {
                self.cancelSelectedImagePinShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.selectedImagePinHotkeyKeyCode = Int(keyCode)
            Defaults.selectedImagePinHotkeyModifiers = Int(carbonMods)
            self.finishSelectedImagePinShortcutRecording()
            return nil
        }
    }

    private func finishSelectedImagePinShortcutRecording() {
        if let m = selectedImagePinShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            selectedImagePinShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshSelectedImagePinShortcutDisplay()
    }

    func cancelSelectedImagePinShortcutRecording() {
        guard selectedImagePinShortcutRecordingMonitor != nil else { return }
        if let m = selectedImagePinShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            selectedImagePinShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshSelectedImagePinShortcutDisplay()
    }

    func refreshSelectedImagePinShortcutDisplay() {
        selectedImagePinShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentSelectedImagePinDisplayString() {
            selectedImagePinShortcutField?.stringValue = display
        } else {
            selectedImagePinShortcutField?.stringValue = L10n.selectedImagePinShortcutDefaultDisplay
        }
    }

    @objc private func clipboardImagePinShortcutSetClicked() {
        if clipboardImagePinShortcutRecordingMonitor != nil {
            cancelClipboardImagePinShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .clipboardImagePin)
        HotkeyManager.shared.beginRecording()
        clipboardImagePinShortcutSetButton.title = L10n.shortcutCancel
        clipboardImagePinShortcutField.stringValue = L10n.shortcutWaiting

        clipboardImagePinShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelClipboardImagePinShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelClipboardImagePinShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            // No two functions may share a shortcut — reject a combo already
            // bound to the screenshot hotkey.
            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .clipboardImagePin) {
                self.cancelClipboardImagePinShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.clipboardImagePinHotkeyKeyCode = Int(keyCode)
            Defaults.clipboardImagePinHotkeyModifiers = Int(carbonMods)
            self.finishClipboardImagePinShortcutRecording()
            return nil
        }
    }

    private func finishClipboardImagePinShortcutRecording() {
        if let m = clipboardImagePinShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardImagePinShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardImagePinShortcutDisplay()
    }

    func cancelClipboardImagePinShortcutRecording() {
        guard clipboardImagePinShortcutRecordingMonitor != nil else { return }
        if let m = clipboardImagePinShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardImagePinShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardImagePinShortcutDisplay()
    }

    func refreshClipboardImagePinShortcutDisplay() {
        clipboardImagePinShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentClipboardImagePinDisplayString() {
            clipboardImagePinShortcutField?.stringValue = display
        } else {
            clipboardImagePinShortcutField?.stringValue = L10n.clipboardImagePinShortcutDefaultDisplay
        }
    }

    @objc private func clipboardTextPinShortcutSetClicked() {
        if clipboardTextPinShortcutRecordingMonitor != nil {
            cancelClipboardTextPinShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .clipboardTextPin)
        HotkeyManager.shared.beginRecording()
        clipboardTextPinShortcutSetButton.title = L10n.shortcutCancel
        clipboardTextPinShortcutField.stringValue = L10n.shortcutWaiting

        clipboardTextPinShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelClipboardTextPinShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelClipboardTextPinShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .clipboardTextPin) {
                self.cancelClipboardTextPinShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.clipboardTextPinHotkeyKeyCode = Int(keyCode)
            Defaults.clipboardTextPinHotkeyModifiers = Int(carbonMods)
            self.finishClipboardTextPinShortcutRecording()
            return nil
        }
    }

    private func finishClipboardTextPinShortcutRecording() {
        if let m = clipboardTextPinShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardTextPinShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardTextPinShortcutDisplay()
    }

    func cancelClipboardTextPinShortcutRecording() {
        guard clipboardTextPinShortcutRecordingMonitor != nil else { return }
        if let m = clipboardTextPinShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardTextPinShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardTextPinShortcutDisplay()
    }

    func refreshClipboardTextPinShortcutDisplay() {
        clipboardTextPinShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentClipboardTextPinDisplayString() {
            clipboardTextPinShortcutField?.stringValue = display
        } else {
            clipboardTextPinShortcutField?.stringValue = L10n.clipboardTextPinShortcutDefaultDisplay
        }
    }

    @objc private func selectedImageEditShortcutSetClicked() {
        if selectedImageEditShortcutRecordingMonitor != nil {
            cancelSelectedImageEditShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .selectedImageEdit)
        HotkeyManager.shared.beginRecording()
        selectedImageEditShortcutSetButton.title = L10n.shortcutCancel
        selectedImageEditShortcutField.stringValue = L10n.shortcutWaiting

        selectedImageEditShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelSelectedImageEditShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelSelectedImageEditShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .selectedImageEdit) {
                self.cancelSelectedImageEditShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.selectedImageEditHotkeyKeyCode = Int(keyCode)
            Defaults.selectedImageEditHotkeyModifiers = Int(carbonMods)
            self.finishSelectedImageEditShortcutRecording()
            return nil
        }
    }

    private func finishSelectedImageEditShortcutRecording() {
        if let m = selectedImageEditShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            selectedImageEditShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshSelectedImageEditShortcutDisplay()
    }

    func cancelSelectedImageEditShortcutRecording() {
        guard selectedImageEditShortcutRecordingMonitor != nil else { return }
        if let m = selectedImageEditShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            selectedImageEditShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshSelectedImageEditShortcutDisplay()
    }

    func refreshSelectedImageEditShortcutDisplay() {
        selectedImageEditShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentSelectedImageEditDisplayString() {
            selectedImageEditShortcutField?.stringValue = display
        } else {
            selectedImageEditShortcutField?.stringValue = L10n.selectedImageEditShortcutDefaultDisplay
        }
    }

    @objc private func clipboardImageEditShortcutSetClicked() {
        if clipboardImageEditShortcutRecordingMonitor != nil {
            cancelClipboardImageEditShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .clipboardImageEdit)
        HotkeyManager.shared.beginRecording()
        clipboardImageEditShortcutSetButton.title = L10n.shortcutCancel
        clipboardImageEditShortcutField.stringValue = L10n.shortcutWaiting

        clipboardImageEditShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelClipboardImageEditShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelClipboardImageEditShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .clipboardImageEdit) {
                self.cancelClipboardImageEditShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.clipboardImageEditHotkeyKeyCode = Int(keyCode)
            Defaults.clipboardImageEditHotkeyModifiers = Int(carbonMods)
            self.finishClipboardImageEditShortcutRecording()
            return nil
        }
    }

    private func finishClipboardImageEditShortcutRecording() {
        if let m = clipboardImageEditShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardImageEditShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardImageEditShortcutDisplay()
    }

    func cancelClipboardImageEditShortcutRecording() {
        guard clipboardImageEditShortcutRecordingMonitor != nil else { return }
        if let m = clipboardImageEditShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardImageEditShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardImageEditShortcutDisplay()
    }

    func refreshClipboardImageEditShortcutDisplay() {
        clipboardImageEditShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentClipboardImageEditDisplayString() {
            clipboardImageEditShortcutField?.stringValue = display
        } else {
            clipboardImageEditShortcutField?.stringValue = L10n.clipboardImageEditShortcutDefaultDisplay
        }
    }

    @objc private func recordShortcutSetClicked() {
        if recordShortcutRecordingMonitor != nil {
            cancelRecordShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .record)
        HotkeyManager.shared.beginRecording()
        recordShortcutSetButton.title = L10n.shortcutCancel
        recordShortcutField.stringValue = L10n.shortcutWaiting

        recordShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelRecordShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelRecordShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .record) {
                self.cancelRecordShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.recordHotkeyKeyCode = Int(keyCode)
            Defaults.recordHotkeyModifiers = Int(carbonMods)
            self.finishRecordShortcutRecording()
            return nil
        }
    }

    private func finishRecordShortcutRecording() {
        if let m = recordShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            recordShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshRecordShortcutDisplay()
    }

    func cancelRecordShortcutRecording() {
        guard recordShortcutRecordingMonitor != nil else { return }
        if let m = recordShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            recordShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshRecordShortcutDisplay()
    }

    func refreshRecordShortcutDisplay() {
        recordShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentRecordDisplayString() {
            recordShortcutField?.stringValue = display
        } else {
            recordShortcutField?.stringValue = L10n.recordShortcutDefaultDisplay
        }
    }

    @objc private func imageMergeShortcutSetClicked() {
        if imageMergeShortcutRecordingMonitor != nil {
            cancelImageMergeShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .imageMerge)
        HotkeyManager.shared.beginRecording()
        imageMergeShortcutSetButton.title = L10n.shortcutCancel
        imageMergeShortcutField.stringValue = L10n.shortcutWaiting

        imageMergeShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelImageMergeShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelImageMergeShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .imageMerge) {
                self.cancelImageMergeShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.imageMergeHotkeyKeyCode = Int(keyCode)
            Defaults.imageMergeHotkeyModifiers = Int(carbonMods)
            self.finishImageMergeShortcutRecording()
            return nil
        }
    }

    private func finishImageMergeShortcutRecording() {
        if let m = imageMergeShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            imageMergeShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshImageMergeShortcutDisplay()
    }

    func cancelImageMergeShortcutRecording() {
        guard imageMergeShortcutRecordingMonitor != nil else { return }
        if let m = imageMergeShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            imageMergeShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshImageMergeShortcutDisplay()
    }

    func refreshImageMergeShortcutDisplay() {
        imageMergeShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentImageMergeDisplayString() {
            imageMergeShortcutField?.stringValue = display
        } else {
            imageMergeShortcutField?.stringValue = L10n.imageMergeShortcutDefaultDisplay
        }
    }

    @objc private func clipboardShortcutSetClicked() {
        if clipboardShortcutRecordingMonitor != nil {
            cancelClipboardShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .clipboard)
        HotkeyManager.shared.beginRecording()
        clipboardShortcutSetButton.title = L10n.shortcutCancel
        clipboardShortcutField.stringValue = L10n.shortcutWaiting

        clipboardShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelClipboardShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            // Unlike the screenshot/pin hotkeys, the editor hotkeys are
            // allowed to be bare — they only fire inside the editor overlay,
            // where typing is restricted to text-annotation editing (already
            // guarded against in the local key monitor).

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .clipboard) {
                self.cancelClipboardShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.clipboardHotkeyKeyCode = Int(keyCode)
            Defaults.clipboardHotkeyModifiers = Int(carbonMods)
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
            self.finishClipboardShortcutRecording()
            return nil
        }
    }

    private func finishClipboardShortcutRecording() {
        if let m = clipboardShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardShortcutDisplay()
    }

    func cancelClipboardShortcutRecording() {
        guard clipboardShortcutRecordingMonitor != nil else { return }
        if let m = clipboardShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardShortcutDisplay()
    }

    func refreshClipboardShortcutDisplay() {
        clipboardShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentClipboardDisplayString() {
            clipboardShortcutField?.stringValue = display
        } else {
            clipboardShortcutField?.stringValue = L10n.clipboardShortcutDefaultDisplay
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
        cancelSelectedImagePinShortcutRecording()
        cancelClipboardImagePinShortcutRecording()
        cancelClipboardTextPinShortcutRecording()
        cancelSelectedImageEditShortcutRecording()
        cancelClipboardImageEditShortcutRecording()
        cancelRecordShortcutRecording()
        cancelImageMergeShortcutRecording()
        cancelClipboardShortcutRecording()
        Defaults.resetShortcutHotkeysToDefaults()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshShortcutDisplay()
        refreshSelectedImagePinShortcutDisplay()
        refreshClipboardImagePinShortcutDisplay()
        refreshClipboardTextPinShortcutDisplay()
        refreshSelectedImageEditShortcutDisplay()
        refreshClipboardImageEditShortcutDisplay()
        refreshRecordShortcutDisplay()
        refreshImageMergeShortcutDisplay()
        refreshClipboardShortcutDisplay()
    }
}
