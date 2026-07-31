import AppKit

/// Presents update alerts without entering an application-modal event loop.
///
/// aulycShot owns the global screenshot shortcut itself. A blocking
/// `NSAlert.runModal()` prevents the shortcut callback from reaching the main
/// thread while the alert is visible, so update alerts are shown as ordinary
/// modeless windows and retained until one of their buttons is chosen.
final class UpdateAlertPresenter: NSObject {
    static let shared = UpdateAlertPresenter()

    private var sessions: [ObjectIdentifier: UpdateAlertSession] = [:]

    func present(
        _ alert: NSAlert,
        completion: ((NSApplication.ModalResponse) -> Void)? = nil
    ) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.present(alert, completion: completion)
            }
            return
        }

        let session = UpdateAlertSession(alert: alert, completion: completion)
        let identifier = ObjectIdentifier(session)
        session.onFinish = { [weak self] finishedSession in
            self?.sessions.removeValue(forKey: ObjectIdentifier(finishedSession))
        }
        sessions[identifier] = session
        session.present()
    }
}

private final class UpdateAlertSession: NSObject {
    let alert: NSAlert
    let completion: ((NSApplication.ModalResponse) -> Void)?
    var onFinish: ((UpdateAlertSession) -> Void)?

    private var closeObserver: NSObjectProtocol?
    private var isFinished = false

    init(
        alert: NSAlert,
        completion: ((NSApplication.ModalResponse) -> Void)?
    ) {
        self.alert = alert
        self.completion = completion
        super.init()
    }

    deinit {
        removeCloseObserver()
    }

    func present() {
        let window = alert.window
        window.isReleasedWhenClosed = false
        window.level = .floating

        for (index, button) in alert.buttons.enumerated() {
            button.tag = index
            button.target = self
            button.action = #selector(buttonClicked(_:))
        }

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.finish(response: .cancel, orderOut: false)
        }

        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func buttonClicked(_ sender: NSButton) {
        let response = NSApplication.ModalResponse(
            rawValue: NSApplication.ModalResponse.alertFirstButtonReturn.rawValue + sender.tag
        )
        finish(response: response, orderOut: true)
    }

    private func finish(
        response: NSApplication.ModalResponse,
        orderOut: Bool
    ) {
        guard !isFinished else { return }
        isFinished = true
        removeCloseObserver()
        if orderOut {
            alert.window.orderOut(nil)
        }
        completion?(response)
        onFinish?(self)
    }

    private func removeCloseObserver() {
        guard let closeObserver else { return }
        NotificationCenter.default.removeObserver(closeObserver)
        self.closeObserver = nil
    }
}
