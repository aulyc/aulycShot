import AppKit

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private let onTakeScreenshot: () -> Void
    private let onRecord: () -> Void
    private let onMergeImages: () -> Void
    private let onOpenSettings: () -> Void

    init(
        onTakeScreenshot: @escaping () -> Void,
        onRecord: @escaping () -> Void,
        onMergeImages: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.onTakeScreenshot = onTakeScreenshot
        self.onRecord = onRecord
        self.onMergeImages = onMergeImages
        self.onOpenSettings = onOpenSettings

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.isVisible = true

        super.init()

        if let button = statusItem.button {
            button.image = Self.statusBarIcon()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
        }

        setupMenu()

        NotificationCenter.default.addObserver(forName: .languageDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.setupMenu()
        }
        NotificationCenter.default.addObserver(forName: .hotkeyDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.setupMenu()
        }
        NotificationCenter.default.addObserver(forName: .updateStateDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.setupMenu()
            self?.syncUpdateProgressHUD()
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        let screenshotItem = NSMenuItem(title: L10n.takeScreenshot, action: #selector(takeScreenshot), keyEquivalent: "")
        screenshotItem.target = self
        screenshotItem.image = Self.menuIcon(systemName: "crop")
        HotkeyManager.applyToMenuItem(screenshotItem)
        menu.addItem(screenshotItem)

        let recordItem = NSMenuItem(title: L10n.record, action: #selector(record), keyEquivalent: "")
        recordItem.target = self
        recordItem.image = Self.menuIcon(systemName: "record.circle")
        HotkeyManager.applyRecordToMenuItem(recordItem)
        menu.addItem(recordItem)

        let mergeItem = NSMenuItem(title: L10n.mergeImages, action: #selector(mergeImages), keyEquivalent: "")
        mergeItem.target = self
        mergeItem.image = Self.menuIcon(systemName: "square.grid.2x2")
        HotkeyManager.applyImageMergeToMenuItem(mergeItem)
        menu.addItem(mergeItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: L10n.settings, action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = Self.menuIcon(systemName: "gearshape")
        menu.addItem(settingsItem)

        menu.addItem(makeUpdateMenuItem())

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: L10n.quitApp, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = Self.menuIcon(systemName: "power")
        menu.addItem(quitItem)

        statusItem.menu = menu

    }

    fileprivate static func menuIcon(systemName: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    private static func statusBarIcon() -> NSImage {
        let size = NSSize(width: 20, height: 20)
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            image.size = size
            image.isTemplate = true
            return image
        }

        let image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "aulycShot")
            ?? NSImage(size: size)
        image.size = size
        image.isTemplate = true
        return image
    }

    @objc private func takeScreenshot() {
        onTakeScreenshot()
    }

    @objc private func record() {
        onRecord()
    }

    @objc private func mergeImages() {
        onMergeImages()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    /// Builds the update menu item — its title and action track the current
    /// state: an installable "new version" entry, a passive download/install
    /// progress line, or a "Check for Updates" action.
    private func makeUpdateMenuItem() -> NSMenuItem {
        let item: NSMenuItem
        switch UpdateChecker.shared.state {
        case .available(let version):
            item = NSMenuItem(title: L10n.updateAvailableMenu(version),
                              action: #selector(updateMenuItemClicked), keyEquivalent: "")
            item.image = Self.menuIcon(systemName: "arrow.down.circle.fill")
        case .downloading(_, let fraction):
            item = NSMenuItem(title: L10n.updateDownloadingMenu(Int(fraction * 100)),
                              action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.image = Self.menuIcon(systemName: "arrow.down.circle")
        case .installing:
            item = NSMenuItem(title: L10n.updateInstallingMenu, action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.image = Self.menuIcon(systemName: "arrow.down.circle")
        case .installFailed:
            item = NSMenuItem(title: L10n.updateInstallFailedMenu,
                              action: #selector(updateMenuItemClicked), keyEquivalent: "")
            item.image = Self.menuIcon(systemName: "exclamationmark.triangle")
        case .checking:
            item = NSMenuItem(title: L10n.checkingForUpdatesMenu, action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.image = Self.menuIcon(systemName: "arrow.triangle.2.circlepath")
        default:
            item = NSMenuItem(title: L10n.checkForUpdatesMenu,
                              action: #selector(checkForUpdatesClicked), keyEquivalent: "")
            item.image = Self.menuIcon(systemName: "arrow.triangle.2.circlepath")
        }
        item.target = self
        return item
    }

    @objc private func checkForUpdatesClicked() {
        // Give the manual check immediate feedback — the GitHub round trip can
        // take a moment, and otherwise nothing visible happens until it lands.
        UpdateProgressWindow.show(message: L10n.updateCheckingHUD, style: .spinner)
        UpdateChecker.shared.check(manual: true) { state in
            UpdateProgressWindow.dismiss()
            Self.presentManualCheckResult(state)
        }
    }

    /// Reflects an in-flight download/install into the progress HUD. The
    /// checking HUD and every dismissal are driven explicitly by the
    /// manual-check and install-failure paths, so this only advances the HUD
    /// through the download and install phases.
    private func syncUpdateProgressHUD() {
        switch UpdateChecker.shared.state {
        case .downloading(_, let fraction):
            UpdateProgressWindow.show(
                message: L10n.updateDownloadingHUD(Int(fraction * 100)),
                style: .bar(fraction: fraction)
            )
        case .installing(_, let phase):
            let message: String
            switch phase {
            case .verifying:  message = L10n.updateVerifyingHUD
            case .unzipping:  message = L10n.updateUnzippingHUD
            case .installing: message = L10n.updateInstallingHUD
            }
            UpdateProgressWindow.show(message: message, style: .spinner)
        default:
            break
        }
    }

    /// Handles a click on the update menu item once a release is known: offers
    /// the install prompt, or — after a failed install — the release page.
    @objc private func updateMenuItemClicked() {
        switch UpdateChecker.shared.state {
        case .available(let version):
            Self.presentUpdateAvailableAlertAfterRefresh(fallbackVersion: version)
        case .installFailed:
            if let url = UpdateChecker.shared.latestPageURL {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }

    /// Reports the outcome of a user-initiated check with a standard alert.
    /// Background launch checks stay silent and only update the menu item.
    private static func presentManualCheckResult(_ state: UpdateState) {
        switch state {
        case .available(let version):
            presentUpdateAvailableAlert(version: version)
        case .upToDate:
            UpdateAlertPresenter.shared.present(
                UpdateAlertPresentation(
                    title: L10n.updateUpToDateTitle,
                    message: L10n.updateUpToDateBody(UpdateChecker.shared.currentVersion),
                    buttonTitles: [L10n.updateOKButton]
                )
            )
        case .failed:
            UpdateAlertPresenter.shared.present(
                UpdateAlertPresentation(
                    title: L10n.updateFailedTitle,
                    message: L10n.updateFailedBody,
                    buttonTitles: [L10n.updateOKButton]
                )
            )
        case .idle, .checking, .downloading, .installing, .installFailed:
            // Either a check was already in flight, or an install is being
            // driven elsewhere — nothing to report here.
            break
        }
    }

    /// Prompts the user to install a newer release. The download/install runs
    /// in the background; on success the app relaunches itself.
    static func presentUpdateAvailableAlert(version: String) {
        UpdateAlertPresenter.shared.present(
            UpdateAlertPresentation(
                title: L10n.updateAvailableTitle(version),
                message: L10n.updateAvailableBody,
                buttonTitles: [
                    L10n.updateInstallNowButton,
                    L10n.updateSkipButton,
                    L10n.updateLaterButton,
                ]
            )
        ) { response in
            switch response {
            case .alertFirstButtonReturn:
                UpdateChecker.shared.downloadAndInstall(onFailure: presentInstallFailedAlert)
            case .alertSecondButtonReturn:
                UpdateChecker.shared.skipVersion()
            default:
                break
            }
        }
    }

    /// Refreshes GitHub before showing the install prompt so a long-running app
    /// does not offer an older release after a newer one is published.
    static func presentUpdateAvailableAlertAfterRefresh(fallbackVersion: String) {
        UpdateProgressWindow.show(message: L10n.updateCheckingHUD, style: .spinner)
        UpdateChecker.shared.check(manual: true) { state in
            UpdateProgressWindow.dismiss()
            switch state {
            case .available(let version):
                presentUpdateAvailableAlert(version: version)
            case .upToDate, .failed:
                presentManualCheckResult(state)
            case .idle, .checking, .downloading, .installing, .installFailed:
                presentUpdateAvailableAlert(version: fallbackVersion)
            }
        }
    }

    /// Shown when a download or install fails — offers the release page as a
    /// manual fallback.
    static func presentInstallFailedAlert() {
        UpdateProgressWindow.dismiss()
        UpdateAlertPresenter.shared.present(
            UpdateAlertPresentation(
                title: L10n.updateInstallFailedTitle,
                message: L10n.updateInstallFailedBody,
                buttonTitles: [L10n.updateOpenPageButton, L10n.updateOKButton]
            )
        ) { response in
            if response == .alertFirstButtonReturn,
               let url = UpdateChecker.shared.latestPageURL {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func setMenuBarVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }
}
