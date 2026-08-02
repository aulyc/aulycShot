import AppKit
import Carbon

extension SettingsView {
// MARK: - Permission polling

    func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshPermissionStatus()
            }
        }
    }

    func refreshPermissionStatus() {
        let availability = AppPermissions.featureAvailability
        featurePermissionStatus?.configure(isAvailable: availability.isAvailable)
    }

@objc func featurePermissionHelpClicked() {
        presentPermissionHelp()
    }

    func presentPermissionHelp() {
        if let onPermissionHelpRequest {
            onPermissionHelpRequest()
            return
        }

        guard window?.attachedSheet == nil else { return }
        let alert = makePermissionHelpAlert()

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            switch response {
            case .alertFirstButtonReturn:
                NSWorkspace.shared.open(PermissionSettingsDestination.accessibility)
            case .alertSecondButtonReturn:
                NSWorkspace.shared.open(PermissionSettingsDestination.screenRecording)
            default:
                return
            }
        }

        if let window {
            alert.beginSheetModal(for: window) { [weak self] response in
                self?.removePermissionAlertOutsideClickMonitor()
                completion(response)
            }
            DispatchQueue.main.async { [weak self, weak alert] in
                guard let self, let alert else { return }
                self.applyPermissionHelpAlertButtonRoles(alert)
            }
            installPermissionAlertOutsideClickMonitor(for: alert.window)
        } else {
            completion(alert.runModal())
        }
    }

    private func installPermissionAlertOutsideClickMonitor(for sheetWindow: NSWindow) {
        removePermissionAlertOutsideClickMonitor()
        permissionAlertOutsideClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .keyDown]
        ) { [weak self, weak sheetWindow] event in
            guard let self,
                  let sheetWindow,
                  sheetWindow.sheetParent != nil
            else {
                return event
            }

            if event.type == .keyDown,
               PermissionAlertDismissalPolicy.shouldDismiss(
                   keyCode: event.keyCode,
                   modifiers: event.modifierFlags
               ) {
                removePermissionAlertOutsideClickMonitor()
                DispatchQueue.main.async { [weak sheetWindow] in
                    guard let sheetWindow, let parentWindow = sheetWindow.sheetParent else { return }
                    parentWindow.endSheet(sheetWindow, returnCode: .cancel)
                }
                return nil
            }

            guard event.type == .leftMouseDown,
                  PermissionAlertDismissalPolicy.shouldDismiss(
                sheetFrame: sheetWindow.frame,
                clickScreenPoint: NSEvent.mouseLocation
            ) else {
                return event
            }

            removePermissionAlertOutsideClickMonitor()
            DispatchQueue.main.async { [weak sheetWindow] in
                guard let sheetWindow, let parentWindow = sheetWindow.sheetParent else { return }
                parentWindow.endSheet(sheetWindow, returnCode: .cancel)
            }
            return nil
        }
    }

    func removePermissionAlertOutsideClickMonitor() {
        guard let permissionAlertOutsideClickMonitor else { return }
        NSEvent.removeMonitor(permissionAlertOutsideClickMonitor)
        self.permissionAlertOutsideClickMonitor = nil
    }

    func makePermissionHelpAlert(
        availability: PermissionFeatureAvailability = AppPermissions.featureAvailability
    ) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.featurePermissionHelpTitle
        alert.informativeText = L10n.featurePermissionHelpBody(
            accessibilityStatus: availability.accessibilityGranted
                ? L10n.permissionAvailable
                : L10n.permissionUnavailable,
            screenRecordingStatus: availability.screenRecordingGranted
                ? L10n.permissionAvailable
                : L10n.permissionUnavailable
        )
        let accessibilityButton = alert.addButton(withTitle: L10n.permissionHelpOpenAccessibility)
        accessibilityButton.keyEquivalent = ""
        accessibilityButton.keyEquivalentModifierMask = []

        let screenRecordingButton = alert.addButton(
            withTitle: L10n.permissionHelpOpenScreenRecording
        )
        screenRecordingButton.keyEquivalent = ""
        screenRecordingButton.keyEquivalentModifierMask = []

        let doneButton = alert.addButton(withTitle: L10n.permissionHelpDone)
        doneButton.keyEquivalent = "\r"
        doneButton.keyEquivalentModifierMask = []
        applyPermissionHelpAlertButtonRoles(alert)
        return alert
    }

    private func applyPermissionHelpAlertButtonRoles(_ alert: NSAlert) {
        guard alert.buttons.count == 3 else { return }
        let permissionButtons = alert.buttons.prefix(2)
        let doneButton = alert.buttons[2]

        for button in permissionButtons {
            button.keyEquivalent = ""
            button.keyEquivalentModifierMask = []
            button.bezelColor = nil
        }

        doneButton.keyEquivalent = "\r"
        doneButton.keyEquivalentModifierMask = []
        doneButton.bezelColor = NSColor.controlAccentColor
        alert.window.defaultButtonCell = doneButton.cell as? NSButtonCell
        doneButton.needsDisplay = true
    }
}

private enum PermissionSettingsDestination {
    static let accessibility = makeURL(anchor: "Privacy_Accessibility")
    static let screenRecording = makeURL(anchor: "Privacy_ScreenCapture")

    private static func makeURL(anchor: String) -> URL {
        URL(
            string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)"
        )!
    }
}

enum PermissionAlertDismissalPolicy {
    static func shouldDismiss(sheetFrame: NSRect, clickScreenPoint: NSPoint) -> Bool {
        !sheetFrame.contains(clickScreenPoint)
    }

    static func shouldDismiss(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) -> Bool {
        let activeModifiers = modifiers.intersection([.command, .shift, .option, .control])
        return keyCode == UInt16(kVK_Escape) && activeModifiers.isEmpty
    }
}
