import AppKit
import Carbon

// MARK: - Tab model

enum SettingsTab: CaseIterable {
    case general
    case shortcuts
    case toolbar
    case about

    var title: String {
        switch self {
        case .general: return L10n.settingsTabGeneral
        case .shortcuts: return L10n.settingsTabShortcuts
        case .toolbar: return L10n.settingsTabToolbar
        case .about: return L10n.settingsTabAbout
        }
    }

    var iconName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .shortcuts: return "keyboard"
        case .toolbar: return "slider.horizontal.3"
        case .about: return "info.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .general: return L10n.settingsTabGeneralDescription
        case .shortcuts: return L10n.settingsTabShortcutsDescription
        case .toolbar: return L10n.settingsTabToolbarDescription
        case .about: return L10n.settingsTabAboutDescription
        }
    }
}
enum SettingsActivationState: String, CaseIterable {
    case enabled
    case disabled

    init(isEnabled: Bool) {
        self = isEnabled ? .enabled : .disabled
    }

    var isEnabled: Bool {
        self == .enabled
    }

    var localizedTitle: String {
        switch self {
        case .enabled: return L10n.settingEnabled
        case .disabled: return L10n.settingDisabled
        }
    }
}

@MainActor
class SettingsView: NSView {

    struct ShortcutRowControls {
        let title: NSTextField
        let field: NSTextField
        let setButton: NSButton
    }

    var onMenuBarToggle: ((Bool) -> Void)?
    var onPermissionHelpRequest: (() -> Void)?

    var shortcutRows: [HotkeySlot: ShortcutRowControls] = [:]

    // Pane extensions share this module-internal state without exposing it publicly.
    // Activation-state pickers
    var menuBarStatePicker: NSPopUpButton!
    var launchAtLoginStatePicker: NSPopUpButton!
    var automaticUpdateChecksStatePicker: NSPopUpButton!
    var demoModeStatePicker: NSPopUpButton!

    // Picker & slider
    var langPicker: NSPopUpButton!

    var shortcutRecordingMonitor: Any?
    var recordingShortcutSlot: HotkeySlot?

    var detailResetButton: NSButton?
    weak var toolbarSettingsPane: ToolbarSettingsPane?

    // Sidebar permission status
    var featurePermissionHelpButton: NSButton?
    var featurePermissionStatus: PermissionStatusIndicator?

    // Labels (kept for language switching)
    var menuBarTitleLabel: NSTextField!
    var launchAtLoginTitleLabel: NSTextField!
    var automaticUpdateChecksTitleLabel: NSTextField!
    var demoModeTitleLabel: NSTextField!
    var demoModeSubtitleLabel: NSTextField!
    var langTitleLabel: NSTextField!
    var aboutVersionLabel: NSTextField?
    var aboutLicenseTitleLabel: NSTextField?
    var aboutSourceTitleLabel: NSTextField?
    var aboutStarTitleLabel: NSTextField?
    var aboutFeatureRequestTitleLabel: NSTextField?
    var aboutBugReportTitleLabel: NSTextField?
    var aboutUpdateTitleLabel: NSTextField?
    var aboutUpdateStatusLabel: NSTextField?
    var aboutUpdateButton: NSButton?

    // Error log entry and its separate diagnostic window.
    var errorLogTitleLabel: NSTextField?
    var errorLogWindowController: ErrorLogWindowController?

    // Sidebar / detail chrome
    var selectedTab: SettingsTab = .general
    var tabButtons: [TabButton] = []
    var sidebarTitleLabel: NSTextField!
    var sidebarVersionLabel: NSTextField?
    var detailTitleLabel: NSTextField!
    var detailHeaderDivider: NSView!
    var detailScrollWithHeaderConstraint: NSLayoutConstraint!
    var detailScrollWithoutHeaderConstraint: NSLayoutConstraint!
    var detailScrollToBottomConstraint: NSLayoutConstraint!
    var detailScrollAboveAboutFooterConstraint: NSLayoutConstraint!
    var detailScrollView: NSScrollView!
    var aboutFooterView: NSView!
    var aboutCopyrightLabel: NSTextField?
    var paneContainer: NSView!
    var paneViews: [SettingsTab: NSView] = [:]
    var screenshotOutputActionTitleLabel: NSTextField!
    var screenshotOutputPopup: NSPopUpButton!
    var screenshotQualityTitleLabel: NSTextField!
    var screenshotQualityHintLabel: NSTextField!
    var screenshotQualityPopup: NSPopUpButton!
    var recordingSavePathTitleLabel: NSTextField!
    var recordingSavePathValueLabel: NSTextField!
    var recordingSavePathChooseButton: NSButton!
    var recordingSavePathRevealButton: NSButton!
    var recordingSaveFormatTitleLabel: NSTextField!
    var recordingSaveFormatPopup: NSPopUpButton!
    var screenshotSavePathTitleLabel: NSTextField!
    var screenshotSavePathValueLabel: NSTextField!
    var screenshotSavePathChooseButton: NSButton!
    var screenshotSavePathRevealButton: NSButton!
    var screenshotSavePathRow: NSView?
    var generalPopupWidthConstraints: [NSLayoutConstraint] = []
    var generalControlGroupWidthConstraints: [NSLayoutConstraint] = []
    var permissionAlertOutsideClickMonitor: Any?

    var refreshTimer: Timer?
    override init(frame: NSRect) {
        super.init(frame: frame)
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        setupBackground()
        setupUI()
        startRefreshTimer()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLocalization),
            name: .languageDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshUpdateRow),
            name: .updateStateDidChange,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        MainActor.assumeIsolated {
            refreshTimer?.invalidate()
            removePermissionAlertOutsideClickMonitor()
            cancelShortcutRecording()
            NotificationCenter.default.removeObserver(self)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Background

    private func setupBackground() {
        layer?.backgroundColor = SettingsPalette.contentBackground.cgColor
    }

    // MARK: - Layout

    private func setupUI() {
        let sidebar = buildSidebar()
        addSubview(sidebar)

        let detail = buildDetailPanel()
        addSubview(detail)

        NSLayoutConstraint.activate([
            sidebar.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            sidebar.bottomAnchor.constraint(equalTo: bottomAnchor),
            sidebar.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 210),

            detail.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            detail.bottomAnchor.constraint(equalTo: bottomAnchor),
            detail.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            detail.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        // Build all panes
        paneViews[.general] = buildGeneralPane()
        paneViews[.shortcuts] = buildShortcutsPane()
        paneViews[.toolbar] = buildToolbarPane()
        paneViews[.about] = buildAboutPane()

        // Default selection
        selectTab(.general)

        refreshPermissionStatus()
        refreshShortcutDisplays()
    }

    // MARK: - Sidebar

    private func buildSidebar() -> NSView {
        let panel = SidebarPanel()
        panel.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: L10n.settings)
        title.font = NSFont.systemFont(ofSize: 21, weight: .bold)
        title.textColor = SettingsPalette.primaryText
        title.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(title)
        sidebarTitleLabel = title

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)

        for tab in SettingsTab.allCases {
            let btn = TabButton(tab: tab)
            btn.target = self
            btn.action = #selector(tabClicked(_:))
            btn.translatesAutoresizingMaskIntoConstraints = false
            tabButtons.append(btn)
            stack.addArrangedSubview(btn)
            btn.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        let version = NSTextField(labelWithString: aboutVersionString())
        version.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        version.textColor = SettingsPalette.secondaryText
        version.alignment = .left
        version.identifier = NSUserInterfaceItemIdentifier("sidebar-version")
        version.translatesAutoresizingMaskIntoConstraints = false
        sidebarVersionLabel = version

        let featureHelpButton = HoverButton()
        featureHelpButton.image = NSImage(
            systemSymbolName: "questionmark.circle",
            accessibilityDescription: nil
        ) ?? NSImage()
        featureHelpButton.target = self
        featureHelpButton.action = #selector(featurePermissionHelpClicked)
        featureHelpButton.showsHoverBackground = false
        configurePermissionHelpButton(
            featureHelpButton,
            tooltip: L10n.featurePermissionHelpTooltip
        )
        featurePermissionHelpButton = featureHelpButton

        let featureStatus = PermissionStatusIndicator(title: L10n.featurePermissionStatus)
        featurePermissionStatus = featureStatus

        let featureRow = permissionStatusRow(
            status: featureStatus,
            helpButton: featureHelpButton
        )

        let footerStack = NSStackView(views: [featureRow, version])
        footerStack.orientation = .vertical
        footerStack.alignment = .leading
        footerStack.spacing = 6
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(footerStack)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: panel.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor, constant: -18),

            stack.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: footerStack.topAnchor, constant: -16),

            footerStack.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            footerStack.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor, constant: -16),
            footerStack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -18),
        ])

        return panel
    }

    private func configurePermissionHelpButton(_ button: NSButton, tooltip: String) {
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = SettingsPalette.secondaryText
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 18),
            button.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    private func permissionStatusRow(
        status: PermissionStatusIndicator,
        helpButton: NSButton
    ) -> NSStackView {
        let row = NSStackView(views: [status, helpButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func aboutVersionString() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return L10n.aboutVersion(short, build: build)
    }

    func aboutVersionValueString() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return L10n.aboutVersionValue(short, build: build)
    }

    @objc private func tabClicked(_ sender: TabButton) {
        selectTab(sender.tab)
    }

    private func selectTab(_ tab: SettingsTab) {
        selectedTab = tab
        for btn in tabButtons {
            btn.isSelected = (btn.tab == tab)
        }
        refreshDetailHeader(for: tab)
        let showsAboutFooter = tab == .about
        aboutFooterView?.isHidden = !showsAboutFooter
        if let withHeader = detailScrollWithHeaderConstraint,
           let withoutHeader = detailScrollWithoutHeaderConstraint {
            NSLayoutConstraint.deactivate([withHeader, withoutHeader])
            withHeader.isActive = true
        }
        if let toBottom = detailScrollToBottomConstraint,
           let aboveFooter = detailScrollAboveAboutFooterConstraint {
            NSLayoutConstraint.deactivate([toBottom, aboveFooter])
            (showsAboutFooter ? aboveFooter : toBottom).isActive = true
        }
        detailResetButton?.isHidden = tab != .shortcuts && tab != .toolbar

        // Swap pane content
        guard let pane = paneViews[tab] else { return }
        for sub in paneContainer.subviews { sub.removeFromSuperview() }
        pane.translatesAutoresizingMaskIntoConstraints = false
        paneContainer.addSubview(pane)
        NSLayoutConstraint.activate([
            pane.topAnchor.constraint(equalTo: paneContainer.topAnchor),
            pane.leadingAnchor.constraint(equalTo: paneContainer.leadingAnchor),
            pane.trailingAnchor.constraint(equalTo: paneContainer.trailingAnchor),
            pane.bottomAnchor.constraint(equalTo: paneContainer.bottomAnchor),
        ])
    }

    private func refreshDetailHeader(for tab: SettingsTab) {
        let isAbout = tab == .about
        detailTitleLabel?.stringValue = isAbout ? L10n.aboutTitle : tab.description
        detailTitleLabel?.font = NSFont.systemFont(
            ofSize: isAbout ? 21 : 14,
            weight: isAbout ? .bold : .medium
        )
        detailTitleLabel?.textColor = isAbout
            ? SettingsPalette.primaryText
            : SettingsPalette.secondaryText
        detailTitleLabel?.isHidden = false
        detailHeaderDivider?.isHidden = isAbout || tab == .toolbar
    }

    func showGeneralTab() {
        selectTab(.general)
    }

    func showAboutTab() {
        selectTab(.about)
    }

    // MARK: - Detail panel

    private func buildDetailPanel() -> NSView {
        let panel = DetailPanel()
        panel.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: SettingsTab.general.description)
        title.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        title.textColor = SettingsPalette.secondaryText
        title.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(title)
        detailTitleLabel = title

        let resetButton = SettingsActionButton(
            title: L10n.toolbarSettingsReset,
            target: self,
            action: #selector(detailResetClicked)
        )
        resetButton.identifier = NSUserInterfaceItemIdentifier("settings-detail-reset")
        configureGeneralActionButton(resetButton)
        resetButton.isHidden = true
        panel.addSubview(resetButton)
        detailResetButton = resetButton

        let headerDivider = NSView()
        headerDivider.identifier = NSUserInterfaceItemIdentifier("settings-detail-header-divider")
        headerDivider.wantsLayer = true
        headerDivider.layer?.backgroundColor = SettingsPalette.separator.cgColor
        headerDivider.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(headerDivider)
        detailHeaderDivider = headerDivider

        let scroll = NSScrollView()
        scroll.identifier = NSUserInterfaceItemIdentifier("settings-detail-scroll")
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.verticalScrollElasticity = .none
        scroll.horizontalScrollElasticity = .none
        panel.addSubview(scroll)
        detailScrollView = scroll

        let container = FlippedView()
        container.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = container
        paneContainer = container

        let aboutFooter = NSView()
        aboutFooter.identifier = NSUserInterfaceItemIdentifier("about-footer")
        aboutFooter.translatesAutoresizingMaskIntoConstraints = false
        aboutFooter.isHidden = true
        panel.addSubview(aboutFooter)
        aboutFooterView = aboutFooter

        let footerDivider = NSView()
        footerDivider.wantsLayer = true
        footerDivider.layer?.backgroundColor = SettingsPalette.separator.cgColor
        footerDivider.translatesAutoresizingMaskIntoConstraints = false
        aboutFooter.addSubview(footerDivider)

        let copyrightLabel = NSTextField(labelWithString: L10n.aboutCopyright)
        copyrightLabel.identifier = NSUserInterfaceItemIdentifier("about-copyright")
        copyrightLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        copyrightLabel.textColor = SettingsPalette.tertiaryText
        copyrightLabel.translatesAutoresizingMaskIntoConstraints = false
        aboutFooter.addSubview(copyrightLabel)
        aboutCopyrightLabel = copyrightLabel

        let scrollWithHeader = scroll.topAnchor.constraint(equalTo: headerDivider.bottomAnchor)
        let scrollWithoutHeader = scroll.topAnchor.constraint(equalTo: panel.topAnchor)
        detailScrollWithHeaderConstraint = scrollWithHeader
        detailScrollWithoutHeaderConstraint = scrollWithoutHeader
        scrollWithHeader.isActive = true

        let scrollToBottom = scroll.bottomAnchor.constraint(equalTo: panel.bottomAnchor)
        let scrollAboveFooter = scroll.bottomAnchor.constraint(equalTo: aboutFooter.topAnchor)
        detailScrollToBottomConstraint = scrollToBottom
        detailScrollAboveAboutFooterConstraint = scrollAboveFooter
        scrollToBottom.isActive = true

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: panel.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 28),
            title.trailingAnchor.constraint(lessThanOrEqualTo: resetButton.leadingAnchor, constant: -16),

            resetButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -28),
            resetButton.centerYAnchor.constraint(equalTo: title.centerYAnchor),

            headerDivider.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 20),
            headerDivider.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 28),
            headerDivider.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -28),
            headerDivider.heightAnchor.constraint(equalToConstant: 1),

            scroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor),

            aboutFooter.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            aboutFooter.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            aboutFooter.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            aboutFooter.heightAnchor.constraint(equalToConstant: 46),

            footerDivider.topAnchor.constraint(equalTo: aboutFooter.topAnchor),
            footerDivider.leadingAnchor.constraint(equalTo: aboutFooter.leadingAnchor, constant: 28),
            footerDivider.trailingAnchor.constraint(equalTo: aboutFooter.trailingAnchor, constant: -28),
            footerDivider.heightAnchor.constraint(equalToConstant: 1),

            copyrightLabel.leadingAnchor.constraint(equalTo: aboutFooter.leadingAnchor, constant: 28),
            copyrightLabel.trailingAnchor.constraint(lessThanOrEqualTo: aboutFooter.trailingAnchor, constant: -28),
            copyrightLabel.centerYAnchor.constraint(equalTo: aboutFooter.centerYAnchor, constant: 2),

            container.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            container.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            container.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])

        return panel
    }

    // MARK: - Pane builders


private func buildToolbarPane() -> NSView {
        let host = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        let pane = ToolbarSettingsPane()
        toolbarSettingsPane = pane
        host.addSubview(pane)
        NSLayoutConstraint.activate([
            pane.topAnchor.constraint(equalTo: host.topAnchor),
            pane.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            pane.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            pane.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
        return host
    }

    @objc private func updateLocalization() {
        menuBarTitleLabel?.stringValue = L10n.showMenuBarIcon
        launchAtLoginTitleLabel?.stringValue = L10n.launchAtLogin
        automaticUpdateChecksTitleLabel?.stringValue = L10n.automaticUpdateChecks
        demoModeTitleLabel?.stringValue = L10n.demoMode
        demoModeSubtitleLabel?.stringValue = L10n.demoModeHint
        refreshActivationPicker(menuBarStatePicker, isEnabled: Defaults.showMenuBar)
        refreshActivationPicker(launchAtLoginStatePicker, isEnabled: LaunchAtLogin.isEnabled)
        refreshActivationPicker(
            automaticUpdateChecksStatePicker,
            isEnabled: Defaults.automaticUpdateChecksEnabled
        )
        refreshActivationPicker(demoModeStatePicker, isEnabled: Defaults.demoMode)
        langTitleLabel?.stringValue = L10n.languageHeader
        screenshotOutputActionTitleLabel?.stringValue = L10n.screenshotOutputActionLabel
        refreshScreenshotOutputControls()
        screenshotQualityTitleLabel?.stringValue = L10n.screenshotQualityLabel
        refreshScreenshotQualityControls()
        recordingSavePathTitleLabel?.stringValue = L10n.recordingSavePathLabel
        recordingSaveFormatTitleLabel?.stringValue = L10n.recordingSaveFormatSettingLabel
        screenshotSavePathTitleLabel?.stringValue = L10n.screenshotSavePathLabel
        recordingSavePathChooseButton?.title = L10n.savePathChoose
        recordingSavePathRevealButton?.toolTip = L10n.savePathReveal
        recordingSavePathRevealButton?.setAccessibilityLabel(L10n.savePathReveal)
        screenshotSavePathChooseButton?.title = L10n.savePathChoose
        screenshotSavePathRevealButton?.toolTip = L10n.savePathReveal
        screenshotSavePathRevealButton?.setAccessibilityLabel(L10n.savePathReveal)
        refreshSavePathControls()
        refreshGeneralPopupWidths()
        for (slot, row) in shortcutRows {
            row.title.stringValue = slot.localizedHeader
        }
        detailResetButton?.title = L10n.toolbarSettingsReset
        aboutVersionLabel?.stringValue = aboutVersionValueString()
        aboutLicenseTitleLabel?.stringValue = L10n.aboutLicense
        aboutSourceTitleLabel?.stringValue = L10n.aboutSourceCode
        aboutStarTitleLabel?.stringValue = L10n.aboutStarOnGitHub
        aboutFeatureRequestTitleLabel?.stringValue = L10n.aboutFeatureRequest
        aboutBugReportTitleLabel?.stringValue = L10n.aboutBugReport
        aboutUpdateTitleLabel?.stringValue = L10n.aboutUpdateTitle
        errorLogTitleLabel?.stringValue = L10n.aboutErrorLog
        errorLogWindowController?.refreshLocalizedText()
        refreshUpdateRow()
        refreshShortcutDisplays()
        featurePermissionHelpButton?.toolTip = L10n.featurePermissionHelpTooltip
        featurePermissionHelpButton?.setAccessibilityLabel(L10n.featurePermissionHelpTooltip)
        featurePermissionStatus?.setTitle(L10n.featurePermissionStatus)
        refreshPermissionStatus()
        for btn in tabButtons { btn.refreshTitle() }
        sidebarTitleLabel?.stringValue = L10n.settings
        sidebarVersionLabel?.stringValue = aboutVersionString()
        aboutCopyrightLabel?.stringValue = L10n.aboutCopyright
        let refreshedAboutPane = buildAboutPane()
        paneViews[.about] = refreshedAboutPane
        if selectedTab == .about {
            selectTab(.about)
        }
        refreshDetailHeader(for: selectedTab)
        window?.title = L10n.settingsTitle
    }
}
