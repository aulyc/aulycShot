import AppKit
import UniformTypeIdentifiers

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private static let shareHandoffNotificationName = Notification.Name("com.aulyc.aulycshot.share-handoff")

    private var statusBarController: StatusBarController?
    private var overlayController: OverlayWindowController?
    private var recordingEngine: RecordingEngine?
    private var recordingHUDPanel: RecordingHUDPanel?
    private var recordingBorderPanel: RecordingBorderPanel?
    private var recordingScreenRect: NSRect = .zero
    private var recordingScreen: NSScreen?
    private var recordingKeyboardLocalMonitor: Any?
    private var recordingKeyboardGlobalMonitor: Any?
    private var recordingCancelRequested = false
    private var appInitialized = false
    private var suspendedEditDraft: OverlayWindowController.SuspendedEditDraft?
    private var pendingReopenSettingsWorkItem: DispatchWorkItem?
    private var pendingOpenImageURLs: [URL] = []

    private var activityAvailability: AppActivityAvailability {
        let availability = AppActivityAvailability(
            overlayActive: overlayController != nil,
            recordingActive: recordingEngine != nil
        )
        assert(!availability.hasConflictingActivities, "Capture overlay and recording cannot be active together")
        return availability
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerShareHandoffObserver()
        let startupPlan = AppStartupPlan.silent
        if startupPlan.shouldCreateStatusBar {
            ensureStatusBarController()
        }

        if !appInitialized, startupPlan.shouldInitializeApp {
            initializeApp()
        }
        if appInitialized {
            flushPendingOpenImageURLs()
        }
        if startupPlan.shouldShowStartupDialog {
            showStartupDialog()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if appInitialized {
            scheduleSettingsOpenFromReopen()
        } else {
            showStartupDialog()
        }
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        _ = requestOpenImageURLs(urls)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        requestOpenImageURLs([URL(fileURLWithPath: filename)])
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let handled = requestOpenImageURLs(filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: handled ? .success : .failure)
    }

    private func showStartupDialog() {
        let settingsController = configuredSettingsController()
        settingsController.showAsStartupDialog()
    }

    private func configuredSettingsController() -> SettingsWindowController {
        let settingsController = SettingsWindowController.shared
        settingsController.onMenuBarToggle = { [weak self] visible in
            self?.statusBarController?.setMenuBarVisible(visible)
        }
        return settingsController
    }

    private func registerShareHandoffObserver() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleShareHandoffNotification(_:)),
            name: Self.shareHandoffNotificationName,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    private func initializeApp() {
        guard !appInitialized else { return }
        ensureStatusBarController()
        appInitialized = true

        ImageEditLauncher.clearTempDir()
        ImageMergeLauncher.shared.onContinueEditing = { [weak self] image in
            self?.continueEditingMergedImage(image)
        }
        NotificationCenter.default.addObserver(
            forName: .hotkeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyHotkeyState()
            }
        }
        applyHotkeyState()
    }

    private func ensureStatusBarController() {
        guard statusBarController == nil else { return }

        let controller = StatusBarController(
            onTakeScreenshot: { [weak self] in
                self?.performWhenInitialized { $0.handleTrigger() }
            },
            onTakeStatusMenuScreenshot: { [weak self] dismissal in
                guard let self else { return false }
                guard self.appInitialized else {
                    self.showStartupDialog()
                    return false
                }
                return self.handleTrigger(eventTrackingDismissal: dismissal)
            },
            onRecord: { [weak self] in
                self?.performWhenInitialized { $0.handleRecordingTrigger() }
            },
            onMergeImages: { [weak self] in
                self?.performWhenInitialized { $0.handleImageMergeMenuTrigger() }
            },
            onOpenSettings: { [weak self] in
                guard let self else { return }
                if self.appInitialized {
                    self.openSettings()
                } else {
                    self.showStartupDialog()
                }
            }
        )
        controller.setMenuBarVisible(Defaults.showMenuBar)
        statusBarController = controller
    }

    private func performWhenInitialized(_ action: (AppDelegate) -> Void) {
        guard appInitialized else {
            showStartupDialog()
            return
        }
        action(self)
    }

    private func requireFeaturePermissions() -> Bool {
        guard AppPermissions.allRequiredGranted else {
            configuredSettingsController().showPermissionHelp()
            return false
        }
        return true
    }

    private func applyHotkeyState() {
        if HotkeyManager.shared.isRecording {
            HotkeyManager.shared.unregister()
            unregisterNonScreenshotHotkeys()
            return
        }

        if recordingEngine != nil {
            unregisterNonScreenshotHotkeys()
            if Defaults.hasCustomScreenshotHotkey {
                HotkeyManager.shared.register { [weak self] in
                    self?.stopRecordingAndSave()
                }
            } else {
                HotkeyManager.shared.unregister()
            }
            return
        }

        if Defaults.hasCustomScreenshotHotkey {
            HotkeyManager.shared.register { [weak self] in
                self?.handleTrigger(fromShortcut: true)
            }
        } else {
            HotkeyManager.shared.unregister()
        }

        // The pin hotkeys are independent of the screenshot hotkey.
        if Defaults.hasCustomSelectedImagePinHotkey {
            HotkeyManager.shared.registerSelectedImagePin { [weak self] in
                self?.handleSelectedImagePinTrigger()
            }
        } else {
            HotkeyManager.shared.unregisterSelectedImagePin()
        }

        if Defaults.hasCustomClipboardImagePinHotkey {
            HotkeyManager.shared.registerClipboardImagePin { [weak self] in
                self?.handleClipboardImagePinTrigger()
            }
        } else {
            HotkeyManager.shared.unregisterClipboardImagePin()
        }

        if Defaults.hasCustomClipboardTextPinHotkey {
            HotkeyManager.shared.registerClipboardTextPin { [weak self] in
                self?.handleClipboardTextPinTrigger()
            }
        } else {
            HotkeyManager.shared.unregisterClipboardTextPin()
        }

        if Defaults.hasCustomSelectedImageEditHotkey {
            HotkeyManager.shared.registerSelectedImageEdit { [weak self] in
                self?.handleSelectedImageEditTrigger()
            }
        } else {
            HotkeyManager.shared.unregisterSelectedImageEdit()
        }

        if Defaults.hasCustomClipboardImageEditHotkey {
            HotkeyManager.shared.registerClipboardImageEdit { [weak self] in
                self?.handleClipboardImageEditTrigger()
            }
        } else {
            HotkeyManager.shared.unregisterClipboardImageEdit()
        }

        if Defaults.hasCustomRecordHotkey {
            HotkeyManager.shared.registerRecord { [weak self] in
                self?.handleRecordingTrigger()
            }
        } else {
            HotkeyManager.shared.unregisterRecord()
        }

        if Defaults.hasCustomImageMergeHotkey {
            HotkeyManager.shared.registerImageMerge { [weak self] in
                self?.handleImageMergeShortcutTrigger()
            }
        } else {
            HotkeyManager.shared.unregisterImageMerge()
        }

    }

    private func unregisterNonScreenshotHotkeys() {
        HotkeyManager.shared.unregisterSelectedImagePin()
        HotkeyManager.shared.unregisterClipboardImagePin()
        HotkeyManager.shared.unregisterClipboardTextPin()
        HotkeyManager.shared.unregisterSelectedImageEdit()
        HotkeyManager.shared.unregisterClipboardImageEdit()
        HotkeyManager.shared.unregisterRecord()
        HotkeyManager.shared.unregisterImageMerge()
    }

    @discardableResult
    private func requestOpenImageURLs(_ urls: [URL]) -> Bool {
        guard Self.containsImageFile(in: urls) else {
            if appInitialized {
                ToastWindow.show(message: L10n.openImageNoImage)
            }
            return false
        }

        pendingOpenImageURLs.append(contentsOf: urls)
        cancelPendingReopenSettings()

        if appInitialized {
            flushPendingOpenImageURLs()
        } else {
            initializeApp()
            flushPendingOpenImageURLs()
        }

        return true
    }

    private func flushPendingOpenImageURLs() {
        guard appInitialized, !pendingOpenImageURLs.isEmpty else { return }
        let urls = pendingOpenImageURLs
        pendingOpenImageURLs.removeAll()
        _ = openImageURLs(urls)
    }

    @discardableResult
    private func openImageURLs(_ urls: [URL]) -> Bool {
        guard activityAvailability.canBeginActivity else { return true }
        guard let url = urls.lazy.compactMap(Self.resolvedImageFileURL).first(where: Self.isImageFile) else {
            ToastWindow.show(message: L10n.openImageNoImage)
            return false
        }

        let didLaunch = launchImageFile(url)
        if didLaunch {
            cancelPendingReopenSettings()
        }
        return didLaunch
    }

    @discardableResult
    private func launchImageFile(_ url: URL) -> Bool {
        let focusRestorer = SourceAppFocusRestorer.captureFrontmostApplication()
        guard let controller = ImageEditLauncher.launch(
            sourceURL: url,
            onRequestFocusReturn: {
                focusRestorer.restore()
            },
            onSuspend: { [weak self] draft in
                self?.handleEditSuspension(draft)
            },
            onComplete: { [weak self] finalImage in
                self?.handleEditCompletion(finalImage)
            }
        ) else {
            ToastWindow.show(message: L10n.openImageNoImage)
            return false
        }

        overlayController = controller
        applyHotkeyState()
        return true
    }

    @discardableResult
    func handleTrigger(
        fromShortcut: Bool = false,
        eventTrackingDismissal: CaptureEventTrackingDismissal? = nil
    ) -> Bool {
        var didBeginCapture = false
        AppActivityEntryRouter.routeScreenshot(
            availability: activityAvailability,
            beginCapture: { [self] in
                guard requireFeaturePermissions() else { return }
                if resumeSuspendedEditIfAvailable() {
                    return
                }
                if fromShortcut {
                    UpdateChecker.shared.checkFromScreenshotShortcutIfDue()
                }
                didBeginCapture = startCapture(
                    eventTrackingDismissal: eventTrackingDismissal
                )
            },
            stopRecording: { [self] in
                stopRecordingAndSave()
            }
        )
        return didBeginCapture
    }

    func handleRecordingTrigger() {
        AppActivityEntryRouter.routeRecordingSelection(
            availability: activityAvailability,
            beginSelection: { [self] in
                guard requireFeaturePermissions() else { return }
                let focusRestorer = SourceAppFocusRestorer.captureFrontmostApplication()
                overlayController = OverlayWindowController(
                    postCaptureAction: .record,
                    onRecordingSelection: { [weak self] rect, screen in
                        self?.beginRecording(rect: rect, screen: screen)
                    },
                    onRequestFocusReturn: {
                        focusRestorer.restore()
                    },
                    onComplete: { [weak self] finalImage in
                        self?.handleEditCompletion(finalImage)
                    }
                )
                overlayController?.activate()
                applyHotkeyState()
            }
        )
    }

    /// Opens the single image currently selected in Finder directly in the
    /// editor. Returns nil when Finder has no exactly-one editable image.
    private func launchSelectedImageEdit() -> OverlayWindowController? {
        let focusRestorer = SourceAppFocusRestorer.captureFrontmostApplication()
        let onComplete: (NSImage?) -> Void = { [weak self] finalImage in
            self?.handleEditCompletion(finalImage)
        }

        if let url = FinderSelection.currentImageFileURL(),
           let controller = ImageEditLauncher.launch(
               sourceURL: url,
               onRequestFocusReturn: {
                   focusRestorer.restore()
               },
               onSuspend: { [weak self] draft in
                   self?.handleEditSuspension(draft)
               },
               onComplete: onComplete
           ) {
            return controller
        }

        return nil
    }

    /// Opens the current clipboard image directly in the editor. Returns nil
    /// when the clipboard has no editable image.
    private func launchClipboardImageEdit() -> OverlayWindowController? {
        let focusRestorer = SourceAppFocusRestorer.captureFrontmostApplication()
        let onComplete: (NSImage?) -> Void = { [weak self] finalImage in
            self?.handleEditCompletion(finalImage)
        }

        if let image = ClipboardImageSource.currentImage(),
           let controller = ImageEditLauncher.launch(
               clipboardImage: image,
               onRequestFocusReturn: {
                   focusRestorer.restore()
               },
               onSuspend: { [weak self] draft in
                   self?.handleEditSuspension(draft)
               },
               onComplete: onComplete
           ) {
            return controller
        }

        return nil
    }

    /// Pin-hotkey trigger: pin Finder selection onto the screen. Skipped while
    /// a capture overlay is up.
    func handleSelectedImagePinTrigger() {
        guard activityAvailability.canBeginActivity else { return }
        PinLauncher.pinSelectedImagesIfAvailable()
    }

    /// Pin-hotkey trigger: pin the clipboard image onto the screen. Skipped
    /// while a capture overlay is up.
    func handleClipboardImagePinTrigger() {
        guard activityAvailability.canBeginActivity else { return }
        PinLauncher.pinClipboardImageIfAvailable()
    }

    /// Pin-hotkey trigger: render clipboard text into a desktop text pin.
    /// Skipped while a capture overlay is up.
    func handleClipboardTextPinTrigger() {
        guard activityAvailability.canBeginActivity else { return }
        PinLauncher.pinClipboardTextIfAvailable()
    }

    func handleSelectedImageEditTrigger() {
        guard activityAvailability.canBeginActivity else { return }
        guard let controller = launchSelectedImageEdit() else {
            ToastWindow.show(message: L10n.selectedImageEditNoImage)
            return
        }
        overlayController = controller
        applyHotkeyState()
    }

    func handleClipboardImageEditTrigger() {
        guard activityAvailability.canBeginActivity else { return }
        guard let controller = launchClipboardImageEdit() else {
            ToastWindow.show(message: L10n.clipboardImageEditNoImage)
            return
        }
        overlayController = controller
        applyHotkeyState()
    }

    @discardableResult
    func handlePinnedImageEditRequest(_ image: NSImage, beforePresent: () -> Void) -> Bool {
        guard activityAvailability.canBeginActivity else { return false }
        beforePresent()

        guard let controller = ImageEditLauncher.launch(
            generatedImage: image,
            source: .pin,
            onSuspend: { [weak self] draft in
                self?.handleEditSuspension(draft)
            },
            onComplete: { [weak self] finalImage in
                self?.handleEditCompletion(finalImage)
            }
        ) else {
            return false
        }

        overlayController = controller
        applyHotkeyState()
        return true
    }

    func handleImageMergeMenuTrigger() {
        guard activityAvailability.canBeginActivity else { return }
        ImageMergeLauncher.shared.openEmpty()
    }

    func handleImageMergeShortcutTrigger() {
        guard activityAvailability.canBeginActivity,
              !ImageMergeLauncher.shared.isWorkbenchActive
        else { return }
        ImageMergeLauncher.shared.openFromShortcutSources()
    }

    @discardableResult
    func startCapture(
        postCaptureAction: OverlayWindowController.PostCaptureAction = .edit,
        eventTrackingDismissal: CaptureEventTrackingDismissal? = nil
    ) -> Bool {
        guard activityAvailability.canBeginActivity else { return false }
        let focusRestorer = SourceAppFocusRestorer.captureFrontmostApplication()
        overlayController = OverlayWindowController(
            postCaptureAction: postCaptureAction,
            eventTrackingDismissal: eventTrackingDismissal,
            onRecordingSelection: { [weak self] rect, screen in
                self?.beginRecording(rect: rect, screen: screen)
            },
            onRequestFocusReturn: {
                focusRestorer.restore()
            },
            onSuspend: { [weak self] draft in
                self?.handleEditSuspension(draft)
            },
            onComplete: { [weak self] finalImage in
                self?.handleEditCompletion(finalImage)
            }
        )
        overlayController?.activate()
        applyHotkeyState()
        return true
    }

    private func handleEditCompletion(_ finalImage: NSImage?) {
        if let finalImage = finalImage {
            performConfiguredScreenshotOutput(finalImage)
        }
        overlayController = nil
        applyHotkeyState()
    }

    private func performConfiguredScreenshotOutput(_ image: NSImage) {
        let mode = Defaults.screenshotOutputMode
        if mode.copiesToClipboard, mode.savesToDirectory {
            copyAndSaveScreenshot(image)
        } else if mode.copiesToClipboard {
            copyScreenshotToClipboard(
                image,
                quality: Defaults.screenshotQuality,
                showsFeedback: true
            ) { _ in }
        } else if mode.savesToDirectory {
            saveScreenshotToConfiguredDirectory(
                image,
                quality: Defaults.screenshotQuality,
                showsFeedback: true
            ) { _ in }
        }
    }

    private func copyScreenshotToClipboard(
        _ image: NSImage,
        quality: ScreenshotImageQuality,
        showsFeedback: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        if showsFeedback, quality.usesLossyCompression {
            ToastWindow.show(message: L10n.screenshotQualityCompressingClipboard, duration: 600)
        }
        ImageOutputEncoder.encodeClipboardAsync(image: image, quality: quality) { result in
            if showsFeedback, quality.usesLossyCompression {
                ToastWindow.dismiss()
            }
            switch result {
            case .failure:
                if showsFeedback {
                    ToastWindow.show(message: L10n.screenshotCompressionFailed, duration: 3.0)
                }
                completion(false)
            case .success(let output):
                ClipboardManager.copyToClipboard(imageOutput: output)
                if showsFeedback {
                    ToastWindow.showScreenshotSuccess()
                }
                completion(true)
            }
        }
    }

    private func saveScreenshotToConfiguredDirectory(
        _ image: NSImage,
        quality: ScreenshotImageQuality,
        showsFeedback: Bool,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        if showsFeedback, quality.usesLossyCompression {
            ToastWindow.show(message: L10n.screenshotQualityCompressingSave, duration: 600)
        }
        ImageOutputEncoder.encodeAsync(image: image, quality: quality) { result in
            if showsFeedback, quality.usesLossyCompression {
                ToastWindow.dismiss()
            }
            switch result {
            case .failure(let error):
                if showsFeedback {
                    ToastWindow.show(message: L10n.screenshotCompressionFailed, duration: 3.0)
                }
                completion(.failure(error))
            case .success(let output):
                do {
                    let filename = OutputFilename.imageFileName(fileExtension: output.fileExtension)
                    let destination = try SaveDestination.uniqueFile(
                        in: Defaults.screenshotSaveDirectory,
                        fileName: filename
                    )
                    try output.data.write(to: destination, options: .atomic)
                    if showsFeedback {
                        let directoryPath = SaveDestination.displayPath(destination.deletingLastPathComponent())
                        ToastWindow.showScreenshotSuccess(
                            message: L10n.screenshotSaved(to: directoryPath)
                        )
                    }
                    completion(.success(destination))
                } catch {
                    if showsFeedback {
                        ToastWindow.show(message: L10n.screenshotSaveFailed(error.localizedDescription), duration: 3.5)
                    }
                    completion(.failure(error))
                }
            }
        }
    }

    private func copyAndSaveScreenshot(_ image: NSImage) {
        let quality = Defaults.screenshotQuality
        let showsProgress = quality.usesLossyCompression
        if showsProgress {
            ToastWindow.show(message: L10n.screenshotOutputProcessing, duration: 600)
        }

        var clipboardSucceeded: Bool?
        var saveResult: Result<URL, Error>?

        let finishIfReady = {
            guard let clipboardSucceeded,
                  let saveResult
            else {
                return
            }

            if showsProgress {
                ToastWindow.dismiss()
            }

            switch (clipboardSucceeded, saveResult) {
            case (true, .success(let destination)):
                let directoryPath = SaveDestination.displayPath(destination.deletingLastPathComponent())
                ToastWindow.showScreenshotSuccess(
                    message: L10n.screenshotCopiedAndSaved(to: directoryPath)
                )
            case (true, .failure(let error)):
                ToastWindow.show(message: L10n.screenshotSaveFailed(error.localizedDescription), duration: 3.5)
            case (false, .success):
                ToastWindow.show(message: L10n.screenshotCompressionFailed, duration: 3.0)
            case (false, .failure(let error)):
                ToastWindow.show(message: L10n.screenshotSaveFailed(error.localizedDescription), duration: 3.5)
            }
        }

        copyScreenshotToClipboard(
            image,
            quality: quality,
            showsFeedback: false
        ) { succeeded in
            clipboardSucceeded = succeeded
            finishIfReady()
        }

        saveScreenshotToConfiguredDirectory(
            image,
            quality: quality,
            showsFeedback: false
        ) { result in
            saveResult = result
            finishIfReady()
        }
    }

    private func handleEditSuspension(_ draft: OverlayWindowController.SuspendedEditDraft) {
        suspendedEditDraft = draft
        overlayController = nil
        applyHotkeyState()
        ToastWindow.show(
            message: L10n.editSuspendedToast,
            on: screen(for: draft),
            duration: 3.0
        )
    }

    private func resumeSuspendedEditIfAvailable() -> Bool {
        guard let draft = suspendedEditDraft else { return false }
        let focusRestorer = SourceAppFocusRestorer.captureFrontmostApplication()
        let controller = OverlayWindowController(
            suspendedDraft: draft,
            onRecordingSelection: { [weak self] rect, screen in
                self?.beginRecording(rect: rect, screen: screen)
            },
            onRequestFocusReturn: {
                focusRestorer.restore()
            },
            onSuspend: { [weak self] draft in
                self?.handleEditSuspension(draft)
            },
            onComplete: { [weak self] finalImage in
                self?.handleEditCompletion(finalImage)
            }
        )
        suspendedEditDraft = nil
        overlayController = controller
        controller.activate()
        applyHotkeyState()
        return true
    }

    private func screen(for draft: OverlayWindowController.SuspendedEditDraft) -> NSScreen? {
        if let displayID = draft.screenDisplayID,
           let screen = NSScreen.screens.first(where: {
               ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
           }) {
            return screen
        }
        return NSScreen.screens.first(where: { $0.frame == draft.screenFrame }) ?? NSScreen.main
    }

    private func continueEditingMergedImage(_ image: NSImage) {
        guard activityAvailability.canBeginActivity else { return }
        let focusRestorer = SourceAppFocusRestorer.captureFrontmostApplication()
        guard let controller = ImageEditLauncher.launch(
            generatedImage: image,
            source: .merge,
            onRequestFocusReturn: {
                focusRestorer.restore()
            },
            onSuspend: { [weak self] draft in
                self?.handleEditSuspension(draft)
            },
            onComplete: { [weak self] finalImage in
                self?.handleEditCompletion(finalImage)
            }
        ) else {
            ToastWindow.show(message: L10n.imageMergeFailed)
            return
        }
        overlayController = controller
        applyHotkeyState()
    }

    private func beginRecording(rect: NSRect, screen: NSScreen) {
        AppActivityEntryRouter.routeRecordingHandoff(
            availability: activityAvailability,
            beginRecording: { [self] in
                beginRecordingAfterActivityHandoff(rect: rect, screen: screen)
            }
        )
    }

    private func beginRecordingAfterActivityHandoff(rect: NSRect, screen: NSScreen) {
        recordingScreenRect = rect
        recordingScreen = screen
        recordingCancelRequested = false

        let borderPanel = RecordingBorderPanel(screen: screen)
        borderPanel.setSelectionRect(rect)
        borderPanel.orderFrontRegardless()
        recordingBorderPanel = borderPanel

        let hudPanel = RecordingHUDPanel()
        hudPanel.update(elapsedSeconds: 0)
        hudPanel.positionOnScreen(relativeTo: rect, screen: screen)
        hudPanel.onStopRecording = { [weak self] in
            self?.stopRecordingAndSave()
        }
        hudPanel.onPauseRecording = { [weak self] in
            self?.recordingEngine?.pauseRecording()
        }
        hudPanel.onResumeRecording = { [weak self] in
            self?.recordingEngine?.resumeRecording()
        }
        hudPanel.orderFrontRegardless()
        recordingHUDPanel = hudPanel

        let engine = RecordingEngine()
        engine.onProgress = { [weak self] seconds in
            self?.updateRecordingHUD(seconds: seconds)
        }
        engine.onPauseChanged = { [weak self] paused in
            self?.recordingHUDPanel?.setPaused(paused)
        }
        engine.onCompletion = { [weak self] url, error in
            self?.finishRecording(url: url, error: error)
        }
        recordingEngine = engine
        installRecordingKeyboardMonitors()
        applyHotkeyState()

        let excludedWindows = [
            recordingBorderPanel.map { CGWindowID($0.windowNumber) },
            recordingHUDPanel.map { CGWindowID($0.windowNumber) },
        ].compactMap { $0 } + ToastWindow.captureExcludedWindowNumbers
        engine.startRecording(rect: rect, screen: screen, excludeWindowNumbers: excludedWindows)
    }

    private func updateRecordingHUD(seconds: Int) {
        recordingHUDPanel?.update(elapsedSeconds: seconds)
        if let screen = recordingScreen, recordingHUDPanel?.userHasDragged != true {
            recordingHUDPanel?.positionOnScreen(relativeTo: recordingScreenRect, screen: screen)
        }
    }

    private func finishRecording(url: URL?, error: Error?) {
        let wasCancelled = recordingCancelRequested
        recordingCancelRequested = false
        stopRecordingUI()

        if wasCancelled {
            if let url {
                try? FileManager.default.removeItem(at: url)
            }
            ToastWindow.show(message: L10n.recordingCancelled)
            return
        }

        if let error {
            ToastWindow.show(message: L10n.recordingFailed(error.localizedDescription), duration: 3.5)
            return
        }

        guard let url else {
            ToastWindow.show(message: L10n.recordingFailed(RecordingEngine.RecordingError.noFrames.localizedDescription), duration: 3.5)
            return
        }

        promptToSaveRecording(tmpURL: url)
    }

    private func stopRecordingUI() {
        removeRecordingKeyboardMonitors()
        recordingHUDPanel?.close()
        recordingHUDPanel = nil
        recordingBorderPanel?.close()
        recordingBorderPanel = nil
        recordingEngine = nil
        recordingScreenRect = .zero
        recordingScreen = nil
        applyHotkeyState()
    }

    private func stopRecordingAndSave() {
        guard let recordingEngine else { return }
        recordingEngine.stopRecording()
    }

    private func cancelRecordingFromKeyboard() {
        guard let recordingEngine, !recordingCancelRequested else { return }
        switch recordingEngine.state {
        case .recording, .paused:
            break
        case .idle, .stopping:
            return
        }
        recordingCancelRequested = true
        recordingEngine.cancelRecording()
    }

    private func installRecordingKeyboardMonitors() {
        removeRecordingKeyboardMonitors()
        recordingKeyboardLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if Self.isPlainReturn(event) {
                self?.stopRecordingAndSave()
                return nil
            }
            if Self.isPlainEscape(event) {
                self?.cancelRecordingFromKeyboard()
                return nil
            }
            return event
        }
        recordingKeyboardGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if Self.isPlainReturn(event) {
                self?.stopRecordingAndSave()
            } else if Self.isPlainEscape(event) {
                self?.cancelRecordingFromKeyboard()
            }
        }
    }

    private func removeRecordingKeyboardMonitors() {
        if let monitor = recordingKeyboardLocalMonitor {
            NSEvent.removeMonitor(monitor)
            recordingKeyboardLocalMonitor = nil
        }
        if let monitor = recordingKeyboardGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            recordingKeyboardGlobalMonitor = nil
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

    private func promptToSaveRecording(tmpURL: URL) {
        let configuration = RecordingSavePromptConfiguration(
            preference: Defaults.recordingSavePreference,
            lastSelectedFormat: Defaults.recordingSaveFormat
        )
        let savePanel = RecordingSavePanel(
            initialFormat: configuration.initialFormat,
            allowsFormatSelection: configuration.allowsFormatSelection,
            defaultDirectory: Defaults.recordingSaveDirectory,
            lastCustomDirectory: Defaults.lastCustomRecordingSaveDirectory
        )
        guard savePanel.presentModally() == .OK else {
            try? FileManager.default.removeItem(at: tmpURL)
            return
        }

        let selectedFormat = savePanel.selectedFormat
        if configuration.allowsFormatSelection {
            Defaults.recordingSaveFormat = selectedFormat
        }
        if !savePanel.usesDefaultDirectory {
            Defaults.lastCustomRecordingSaveDirectory = savePanel.customDirectory
        }
        saveRecording(
            tmpURL: tmpURL,
            to: savePanel.selectedDirectory,
            format: selectedFormat,
            fileName: savePanel.selectedFileName
        )
    }

    private func saveRecording(
        tmpURL: URL,
        to directory: URL,
        format: ScreenRecordingFormat,
        fileName: String
    ) {
        do {
            let destination = try SaveDestination.uniqueFile(in: directory, fileName: fileName)
            saveRecording(tmpURL: tmpURL, destination: destination, format: format)
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
            ToastWindow.show(message: L10n.recordingFailed(error.localizedDescription), duration: 3.5)
        }
    }

    private func saveRecording(tmpURL: URL, destination: URL, format: ScreenRecordingFormat) {
        switch format {
        case .mp4:
            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: tmpURL, to: destination)
                showSavedRecording(destination)
            } catch {
                ToastWindow.show(message: L10n.recordingFailed(error.localizedDescription), duration: 3.5)
            }
        case .gif:
            ToastWindow.show(message: L10n.recordingExportingGIF, duration: 600)
            RecordingExporter.exportGIF(from: tmpURL, to: destination) { result in
                ToastWindow.dismiss()
                switch result {
                case .success:
                    try? FileManager.default.removeItem(at: tmpURL)
                    self.showSavedRecording(destination)
                case .failure(let error):
                    ToastWindow.show(message: L10n.recordingFailed(error.localizedDescription), duration: 3.5)
                    NSWorkspace.shared.activateFileViewerSelecting([tmpURL])
                }
            }
        }
    }

    private func showSavedRecording(_ destination: URL) {
        let directoryPath = SaveDestination.displayPath(destination.deletingLastPathComponent())
        ToastWindow.show(message: L10n.recordingSaved(to: directoryPath))
    }

    private func openSettings() {
        configuredSettingsController().showAsSettings()
    }

    private func scheduleSettingsOpenFromReopen() {
        cancelPendingReopenSettings()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.overlayController == nil else { return }
            self.openSettings()
        }
        pendingReopenSettingsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }

    private func cancelPendingReopenSettings() {
        pendingReopenSettingsWorkItem?.cancel()
        pendingReopenSettingsWorkItem = nil
    }

    @objc private func handleShareHandoffNotification(_ notification: Notification) {
        guard let filePath = notification.userInfo?["file"] as? String,
              !filePath.isEmpty
        else {
            return
        }

        cancelPendingReopenSettings()
        requestOpenImageURLs([URL(fileURLWithPath: filePath)])
    }

    private static func containsImageFile(in urls: [URL]) -> Bool {
        urls.lazy.compactMap(resolvedImageFileURL).contains(where: isImageFile)
    }

    private static func isImageFile(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.contentTypeKey])
        if values?.contentType?.conforms(to: .image) == true {
            return true
        }

        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return false
        }
        return type.conforms(to: .image)
    }

    private static func resolvedImageFileURL(from url: URL) -> URL? {
        if url.isFileURL {
            return url
        }

        guard url.scheme?.caseInsensitiveCompare("aulycshot") == .orderedSame,
              url.host?.caseInsensitiveCompare("edit") == .orderedSame,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let filePath = components.queryItems?.first(where: { $0.name == "file" })?.value,
              !filePath.isEmpty
        else {
            return nil
        }

        return URL(fileURLWithPath: filePath)
    }
}
