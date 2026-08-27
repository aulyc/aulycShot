import AppKit

@MainActor
final class RecordingSessionController {
    enum Completion {
        case cancelled(URL?)
        case failed(Error)
        case completed(URL)
    }

    private let onActiveStateChange: () -> Void
    private let onCompletion: (Completion) -> Void

    private var engine: RecordingEngine?
    private var hudPanel: RecordingHUDPanel?
    private var borderPanel: RecordingBorderPanel?
    private var screenRect: NSRect = .zero
    private var screen: NSScreen?
    private var keyboardLocalMonitor: Any?
    private var keyboardGlobalMonitor: Any?
    private var cancelRequested = false

    var isActive: Bool {
        engine != nil
    }

    init(
        onActiveStateChange: @escaping () -> Void,
        onCompletion: @escaping (Completion) -> Void
    ) {
        self.onActiveStateChange = onActiveStateChange
        self.onCompletion = onCompletion
    }

    deinit {
        MainActor.assumeIsolated {
            removeKeyboardMonitors()
            hudPanel?.close()
            borderPanel?.close()
        }
    }

    func start(rect: NSRect, screen: NSScreen) {
        guard engine == nil else { return }
        screenRect = rect
        self.screen = screen
        cancelRequested = false

        let borderPanel = RecordingBorderPanel(screen: screen)
        borderPanel.setSelectionRect(rect)
        borderPanel.orderFrontRegardless()
        self.borderPanel = borderPanel

        let hudPanel = RecordingHUDPanel()
        hudPanel.update(elapsedSeconds: 0)
        hudPanel.positionOnScreen(relativeTo: rect, screen: screen)
        hudPanel.onStopRecording = { [weak self] in
            self?.stopAndSave()
        }
        hudPanel.onPauseRecording = { [weak self] in
            self?.engine?.pauseRecording()
        }
        hudPanel.onResumeRecording = { [weak self] in
            self?.engine?.resumeRecording()
        }
        hudPanel.orderFrontRegardless()
        self.hudPanel = hudPanel

        let engine = RecordingEngine()
        engine.onProgress = { [weak self] seconds in
            self?.updateHUD(seconds: seconds)
        }
        engine.onPauseChanged = { [weak self] paused in
            self?.hudPanel?.setPaused(paused)
        }
        engine.onCompletion = { [weak self] url, error in
            self?.finish(url: url, error: error)
        }
        self.engine = engine
        installKeyboardMonitors()
        onActiveStateChange()

        let excludedWindows = [
            self.borderPanel.map { CGWindowID($0.windowNumber) },
            self.hudPanel.map { CGWindowID($0.windowNumber) },
        ].compactMap { $0 } + ToastWindow.captureExcludedWindowNumbers
        engine.startRecording(
            rect: rect,
            screen: screen,
            excludeWindowNumbers: excludedWindows
        )
    }

    func stopAndSave() {
        engine?.stopRecording()
    }

    private func cancelFromKeyboard() {
        guard let engine, !cancelRequested else { return }
        switch engine.state {
        case .recording, .paused:
            cancelRequested = true
            engine.cancelRecording()
        case .idle, .stopping:
            return
        }
    }

    private func updateHUD(seconds: Int) {
        hudPanel?.update(elapsedSeconds: seconds)
        if let screen, hudPanel?.userHasDragged != true {
            hudPanel?.positionOnScreen(relativeTo: screenRect, screen: screen)
        }
    }

    private func finish(url: URL?, error: Error?) {
        let wasCancelled = cancelRequested
        cancelRequested = false
        stopUI()
        onCompletion(Self.resolveCompletion(
            cancelRequested: wasCancelled,
            url: url,
            error: error
        ))
    }

    static func resolveCompletion(
        cancelRequested: Bool,
        url: URL?,
        error: Error?
    ) -> Completion {
        if cancelRequested {
            return .cancelled(url)
        }
        if let error {
            return .failed(error)
        }
        if let url {
            return .completed(url)
        }
        return .failed(RecordingEngine.RecordingError.noFrames)
    }

    private func stopUI() {
        removeKeyboardMonitors()
        hudPanel?.close()
        hudPanel = nil
        borderPanel?.close()
        borderPanel = nil
        engine = nil
        screenRect = .zero
        screen = nil
        onActiveStateChange()
    }

    private func installKeyboardMonitors() {
        removeKeyboardMonitors()
        keyboardLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            if Self.isPlainReturn(event) {
                self?.stopAndSave()
                return nil
            }
            if Self.isPlainEscape(event) {
                self?.cancelFromKeyboard()
                return nil
            }
            return event
        }
        keyboardGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            if Self.isPlainReturn(event) {
                self?.stopAndSave()
            } else if Self.isPlainEscape(event) {
                self?.cancelFromKeyboard()
            }
        }
    }

    private func removeKeyboardMonitors() {
        if let monitor = keyboardLocalMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardLocalMonitor = nil
        }
        if let monitor = keyboardGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardGlobalMonitor = nil
        }
    }

    static func isPlainReturn(_ event: NSEvent) -> Bool {
        let activeModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        return (event.keyCode == 36 || event.keyCode == 76) && activeModifiers.isEmpty
    }

    static func isPlainEscape(_ event: NSEvent) -> Bool {
        let activeModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        return event.keyCode == 53 && activeModifiers.isEmpty
    }
}
