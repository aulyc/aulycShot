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

    var iconTint: NSColor {
        switch self {
        case .general: return NSColor(calibratedRed: 0.62, green: 0.66, blue: 0.72, alpha: 1.0)
        case .shortcuts: return NSColor(calibratedRed: 0.36, green: 0.66, blue: 0.98, alpha: 1.0)
        case .toolbar: return NSColor(calibratedRed: 0.95, green: 0.54, blue: 0.62, alpha: 1.0)
        case .about: return NSColor(calibratedRed: 0.70, green: 0.56, blue: 0.96, alpha: 1.0)
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

class SettingsView: NSView {

    var onMenuBarToggle: ((Bool) -> Void)?
    var onPermissionHelpRequest: (() -> Void)?

    // Activation-state pickers
    private var menuBarStatePicker: NSPopUpButton!
    private var launchAtLoginStatePicker: NSPopUpButton!
    private var automaticUpdateChecksStatePicker: NSPopUpButton!
    private var demoModeStatePicker: NSPopUpButton!

    // Picker & slider
    private var langPicker: NSPopUpButton!

    // Screenshot shortcut card
    private var shortcutTitleLabel: NSTextField!
    private var shortcutField: NSTextField!
    private var shortcutSetButton: NSButton!
    private var shortcutRecordingMonitor: Any?

    // Pin selected image shortcut card
    private var selectedImagePinShortcutTitleLabel: NSTextField!
    private var selectedImagePinShortcutField: NSTextField!
    private var selectedImagePinShortcutSetButton: NSButton!
    private var selectedImagePinShortcutRecordingMonitor: Any?

    // Pin clipboard image shortcut card
    private var clipboardImagePinShortcutTitleLabel: NSTextField!
    private var clipboardImagePinShortcutField: NSTextField!
    private var clipboardImagePinShortcutSetButton: NSButton!
    private var clipboardImagePinShortcutRecordingMonitor: Any?

    // Pin clipboard text shortcut card
    private var clipboardTextPinShortcutTitleLabel: NSTextField!
    private var clipboardTextPinShortcutField: NSTextField!
    private var clipboardTextPinShortcutSetButton: NSButton!
    private var clipboardTextPinShortcutRecordingMonitor: Any?

    // Edit selected image shortcut card
    private var selectedImageEditShortcutTitleLabel: NSTextField!
    private var selectedImageEditShortcutField: NSTextField!
    private var selectedImageEditShortcutSetButton: NSButton!
    private var selectedImageEditShortcutRecordingMonitor: Any?

    // Edit clipboard image shortcut card
    private var clipboardImageEditShortcutTitleLabel: NSTextField!
    private var clipboardImageEditShortcutField: NSTextField!
    private var clipboardImageEditShortcutSetButton: NSButton!
    private var clipboardImageEditShortcutRecordingMonitor: Any?

    // Recording shortcut card
    private var recordShortcutTitleLabel: NSTextField!
    private var recordShortcutField: NSTextField!
    private var recordShortcutSetButton: NSButton!
    private var recordShortcutRecordingMonitor: Any?

    // Image Merge shortcut card
    private var imageMergeShortcutTitleLabel: NSTextField!
    private var imageMergeShortcutField: NSTextField!
    private var imageMergeShortcutSetButton: NSButton!
    private var imageMergeShortcutRecordingMonitor: Any?

    // Screenshot execution (editor confirm) shortcut card
    private var clipboardShortcutTitleLabel: NSTextField!
    private var clipboardShortcutField: NSTextField!
    private var clipboardShortcutSetButton: NSButton!
    private var clipboardShortcutRecordingMonitor: Any?

    private var detailResetButton: NSButton?
    private weak var toolbarSettingsPane: ToolbarSettingsPane?

    // Sidebar permission status
    private var featurePermissionHelpButton: NSButton?
    private var featurePermissionStatus: PermissionStatusIndicator?

    // Labels (kept for language switching)
    private var menuBarTitleLabel: NSTextField!
    private var launchAtLoginTitleLabel: NSTextField!
    private var automaticUpdateChecksTitleLabel: NSTextField!
    private var demoModeTitleLabel: NSTextField!
    private var demoModeSubtitleLabel: NSTextField!
    private var langTitleLabel: NSTextField!
    private var aboutVersionLabel: NSTextField?
    private var aboutLicenseTitleLabel: NSTextField?
    private var aboutSourceTitleLabel: NSTextField?
    private var aboutStarTitleLabel: NSTextField?
    private var aboutFeatureRequestTitleLabel: NSTextField?
    private var aboutBugReportTitleLabel: NSTextField?
    private var aboutUpdateTitleLabel: NSTextField?
    private var aboutUpdateStatusLabel: NSTextField?
    private var aboutUpdateButton: NSButton?

    // Error log entry and its separate diagnostic window.
    private var errorLogTitleLabel: NSTextField?
    private var errorLogWindowController: ErrorLogWindowController?

    // Sidebar / detail chrome
    private var selectedTab: SettingsTab = .general
    private var tabButtons: [TabButton] = []
    private var sidebarTitleLabel: NSTextField!
    private var sidebarVersionLabel: NSTextField?
    private var detailTitleLabel: NSTextField!
    private var detailHeaderDivider: NSView!
    private var detailScrollWithHeaderConstraint: NSLayoutConstraint!
    private var detailScrollWithoutHeaderConstraint: NSLayoutConstraint!
    private var detailScrollToBottomConstraint: NSLayoutConstraint!
    private var detailScrollAboveAboutFooterConstraint: NSLayoutConstraint!
    private var detailScrollView: NSScrollView!
    private var aboutFooterView: NSView!
    private var aboutCopyrightLabel: NSTextField?
    private var paneContainer: NSView!
    private var paneViews: [SettingsTab: NSView] = [:]
    private var screenshotOutputActionTitleLabel: NSTextField!
    private var screenshotOutputPopup: NSPopUpButton!
    private var screenshotQualityTitleLabel: NSTextField!
    private var screenshotQualityHintLabel: NSTextField!
    private var screenshotQualityPopup: NSPopUpButton!
    private var recordingSavePathTitleLabel: NSTextField!
    private var recordingSavePathValueLabel: NSTextField!
    private var recordingSavePathChooseButton: NSButton!
    private var recordingSavePathRevealButton: NSButton!
    private var recordingSaveFormatTitleLabel: NSTextField!
    private var recordingSaveFormatPopup: NSPopUpButton!
    private var screenshotSavePathTitleLabel: NSTextField!
    private var screenshotSavePathValueLabel: NSTextField!
    private var screenshotSavePathChooseButton: NSButton!
    private var screenshotSavePathRevealButton: NSButton!
    private var screenshotSavePathRow: NSView?
    private var generalPopupWidthConstraints: [NSLayoutConstraint] = []
    private var generalControlGroupWidthConstraints: [NSLayoutConstraint] = []
    private var permissionAlertOutsideClickMonitor: Any?

    private var refreshTimer: Timer?
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
        refreshTimer?.invalidate()
        removePermissionAlertOutsideClickMonitor()
        cancelShortcutRecording()
        cancelSelectedImagePinShortcutRecording()
        cancelClipboardImagePinShortcutRecording()
        cancelClipboardTextPinShortcutRecording()
        cancelSelectedImageEditShortcutRecording()
        cancelClipboardImageEditShortcutRecording()
        cancelRecordShortcutRecording()
        cancelImageMergeShortcutRecording()
        cancelClipboardShortcutRecording()
        NotificationCenter.default.removeObserver(self)
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

    private func aboutVersionValueString() -> String {
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

    private func buildGeneralPane() -> NSView {
        let stack = paneStack(spacing: 0)

        // Language card
        let langCard = generalCard()
        let langRow = NSStackView()
        langRow.orientation = .horizontal
        langRow.alignment = .centerY
        langRow.spacing = 10
        langRow.translatesAutoresizingMaskIntoConstraints = false
        langCard.addSubview(langRow)
        pin(langRow, to: langCard, insets: NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))
        constrainSettingsRowHeight(langRow)

        langTitleLabel = primaryLabel(L10n.languageHeader)
        langRow.addArrangedSubview(langTitleLabel)
        langRow.addArrangedSubview(flexSpacer())

        langPicker = SettingsPopUpButton(frame: .zero, pullsDown: false)
        langPicker.addItems(withTitles: AppLanguage.allCases.map { $0.displayName })
        langPicker.selectItem(at: AppLanguage.allCases.firstIndex(of: Defaults.language) ?? 0)
        langPicker.target = self
        langPicker.action = #selector(languageChanged(_:))
        langPicker.controlSize = .small
        langPicker.font = NSFont.systemFont(ofSize: 12)
        constrainGeneralPopupWidth(langPicker)
        langRow.addArrangedSubview(langPicker)

        stack.addArrangedSubview(langCard)
        langCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Activation-state card
        let activationCard = generalCard()
        let activationInner = verticalInnerStack()
        activationCard.addSubview(activationInner)
        pin(
            activationInner,
            to: activationCard,
            insets: NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        )

        let menuBar = makeActivationRow(
            title: L10n.showMenuBarIcon,
            subtitle: nil,
            isOn: Defaults.showMenuBar,
            identifier: "menu-bar-state-picker",
            action: #selector(menuBarStateChanged(_:))
        )
        menuBarTitleLabel = menuBar.title
        menuBarStatePicker = menuBar.picker
        activationInner.addArrangedSubview(menuBar.row)
        menuBar.row.widthAnchor.constraint(equalTo: activationInner.widthAnchor).isActive = true
        activationInner.addArrangedSubview(rowDivider())

        let login = makeActivationRow(
            title: L10n.launchAtLogin,
            subtitle: nil,
            isOn: LaunchAtLogin.isEnabled,
            identifier: "launch-at-login-state-picker",
            action: #selector(launchAtLoginStateChanged(_:))
        )
        launchAtLoginTitleLabel = login.title
        launchAtLoginStatePicker = login.picker
        activationInner.addArrangedSubview(login.row)
        login.row.widthAnchor.constraint(equalTo: activationInner.widthAnchor).isActive = true
        activationInner.addArrangedSubview(rowDivider())

        let automaticUpdates = makeActivationRow(
            title: L10n.automaticUpdateChecks,
            subtitle: nil,
            isOn: Defaults.automaticUpdateChecksEnabled,
            identifier: "automatic-update-checks-state-picker",
            action: #selector(automaticUpdateChecksStateChanged(_:))
        )
        automaticUpdateChecksTitleLabel = automaticUpdates.title
        automaticUpdateChecksStatePicker = automaticUpdates.picker
        activationInner.addArrangedSubview(automaticUpdates.row)
        automaticUpdates.row.widthAnchor.constraint(equalTo: activationInner.widthAnchor).isActive = true

        stack.addArrangedSubview(activationCard)
        activationCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        buildScreenshotOutputCard(into: stack)

        buildScreenshotQualityCard(into: stack)

        buildSavePathCard(into: stack)

        buildDemoModeCard(into: stack)

        return wrapPane(stack, topInset: 0)
    }

    private func buildDemoModeCard(into stack: NSStackView) {
        let card = generalCard()
        let inner = verticalInnerStack()
        card.addSubview(inner)
        pin(inner, to: card, insets: NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))

        let demo = makeActivationRow(
            title: L10n.demoMode,
            subtitle: L10n.demoModeHint,
            isOn: Defaults.demoMode,
            identifier: "demo-mode-state-picker",
            action: #selector(demoModeStateChanged(_:))
        )
        demoModeTitleLabel = demo.title
        demoModeSubtitleLabel = demo.subtitle
        demoModeStatePicker = demo.picker
        inner.addArrangedSubview(demo.row)
        demo.row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func refreshSavePathControls() {
        recordingSavePathValueLabel?.stringValue = SaveDestination.displayPath(Defaults.recordingSaveDirectory)
        let screenshotState = ScreenshotSavePathControlState(
            directory: Defaults.screenshotSaveDirectory,
            outputMode: Defaults.screenshotOutputMode
        )
        screenshotSavePathValueLabel?.stringValue = SaveDestination.displayPath(screenshotState.directory)
        applyScreenshotSavePathControlState(screenshotState)
        refreshRecordingSaveFormatPopup()
    }

    private func refreshScreenshotQualityControls() {
        let quality = Defaults.screenshotQuality
        refreshScreenshotQualityPopup(screenshotQualityPopup, selected: quality)
        screenshotQualityHintLabel?.stringValue = quality.localizedHint
    }

    private func refreshScreenshotOutputControls() {
        let selected = Defaults.screenshotOutputMode
        if let popup = screenshotOutputPopup {
            popup.removeAllItems()
            for mode in ScreenshotOutputMode.allCases {
                popup.addItem(withTitle: mode.localizedTitle)
                popup.lastItem?.representedObject = mode.rawValue
            }
            if let index = ScreenshotOutputMode.allCases.firstIndex(of: selected) {
                popup.selectItem(at: index)
            }
        }
        applyScreenshotSavePathControlState(
            ScreenshotSavePathControlState(
                directory: Defaults.screenshotSaveDirectory,
                outputMode: selected
            )
        )
    }

    private func applyScreenshotSavePathControlState(_ state: ScreenshotSavePathControlState) {
        screenshotSavePathChooseButton?.isEnabled = state.isEnabled
        screenshotSavePathRevealButton?.isEnabled = state.isEnabled
        screenshotSavePathRow?.alphaValue = state.isEnabled ? 1 : 0.45
    }

    private func refreshScreenshotQualityPopup(
        _ popup: NSPopUpButton?,
        selected: ScreenshotImageQuality
    ) {
        guard let popup else { return }
        popup.removeAllItems()
        for quality in ScreenshotImageQuality.allCases {
            popup.addItem(withTitle: quality.localizedTitle)
            popup.lastItem?.representedObject = quality.rawValue
        }
        if let index = ScreenshotImageQuality.allCases.firstIndex(of: selected) {
            popup.selectItem(at: index)
        }
    }

    private func refreshRecordingSaveFormatPopup() {
        guard let popup = recordingSaveFormatPopup else { return }
        let selected = Defaults.recordingSavePreference
        popup.removeAllItems()
        for preference in RecordingSavePreference.allCases {
            popup.addItem(withTitle: preference.displayName)
            popup.lastItem?.representedObject = preference.rawValue
        }
        if let index = RecordingSavePreference.allCases.firstIndex(of: selected) {
            popup.selectItem(at: index)
        }
    }

    private func buildShortcutsPane() -> NSView {
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

    private func buildScreenshotOutputCard(into stack: NSStackView) {
        let card = generalCard()
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 0
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        pin(inner, to: card, insets: NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        screenshotOutputActionTitleLabel = primaryLabel(L10n.screenshotOutputActionLabel)
        row.addArrangedSubview(screenshotOutputActionTitleLabel)
        row.addArrangedSubview(flexSpacer())

        screenshotOutputPopup = SettingsPopUpButton(frame: .zero, pullsDown: false)
        screenshotOutputPopup.controlSize = .small
        screenshotOutputPopup.font = NSFont.systemFont(ofSize: 12)
        screenshotOutputPopup.target = self
        screenshotOutputPopup.action = #selector(screenshotOutputModeChanged(_:))
        constrainGeneralPopupWidth(screenshotOutputPopup)
        row.addArrangedSubview(screenshotOutputPopup)
        constrainSettingsRowHeight(row)

        inner.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let pathDivider = rowDivider()
        inner.addArrangedSubview(pathDivider)
        pathDivider.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let screenshotPath = makeSavePathRow(
            title: L10n.screenshotSavePathLabel,
            identifierPrefix: "screenshot",
            chooseAction: #selector(chooseScreenshotSavePathClicked),
            revealAction: #selector(revealScreenshotSavePathClicked)
        )
        screenshotSavePathTitleLabel = screenshotPath.title
        screenshotSavePathValueLabel = screenshotPath.value
        screenshotSavePathChooseButton = screenshotPath.chooseButton
        screenshotSavePathRevealButton = screenshotPath.revealButton
        screenshotSavePathRow = screenshotPath.row
        inner.addArrangedSubview(screenshotPath.row)
        screenshotPath.row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        refreshScreenshotOutputControls()
        refreshSavePathControls()

        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func buildScreenshotQualityCard(into stack: NSStackView) {
        let card = generalCard()
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 0
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        pin(inner, to: card, insets: NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))

        let quality = makeScreenshotQualityRow(
            title: L10n.screenshotQualityLabel,
            quality: Defaults.screenshotQuality,
            action: #selector(screenshotQualityChanged(_:))
        )
        screenshotQualityTitleLabel = quality.title
        screenshotQualityHintLabel = quality.hint
        screenshotQualityPopup = quality.popup
        inner.addArrangedSubview(quality.row)
        quality.row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        refreshScreenshotQualityControls()

        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func makeScreenshotQualityRow(
        title: String,
        quality: ScreenshotImageQuality,
        action: Selector
    ) -> (row: NSView, title: NSTextField, hint: NSTextField, popup: NSPopUpButton) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        let labelStack = NSStackView()
        labelStack.orientation = .vertical
        labelStack.alignment = .leading
        labelStack.spacing = 3
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = primaryLabel(title)
        let hintLabel = secondaryLabel(quality.localizedHint, wrapping: true)
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(hintLabel)
        row.addArrangedSubview(labelStack)
        labelStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true

        row.addArrangedSubview(flexSpacer())

        let popup = SettingsPopUpButton(frame: .zero, pullsDown: false)
        popup.controlSize = .small
        popup.font = NSFont.systemFont(ofSize: 12)
        popup.target = self
        popup.action = action
        constrainGeneralPopupWidth(popup)
        row.addArrangedSubview(popup)
        constrainSettingsRowHeight(row)

        return (row, titleLabel, hintLabel, popup)
    }

    private func buildSavePathCard(into stack: NSStackView) {
        let card = generalCard()
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 0
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        pin(inner, to: card, insets: NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))

        let recordingPath = makeSavePathRow(
            title: L10n.recordingSavePathLabel,
            identifierPrefix: "recording",
            chooseAction: #selector(chooseRecordingSavePathClicked),
            revealAction: #selector(revealRecordingSavePathClicked)
        )
        recordingSavePathTitleLabel = recordingPath.title
        recordingSavePathValueLabel = recordingPath.value
        recordingSavePathChooseButton = recordingPath.chooseButton
        recordingSavePathRevealButton = recordingPath.revealButton
        inner.addArrangedSubview(recordingPath.row)
        recordingPath.row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let formatDivider = rowDivider()
        inner.addArrangedSubview(formatDivider)
        formatDivider.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let formatRow = NSStackView()
        formatRow.orientation = .horizontal
        formatRow.alignment = .centerY
        formatRow.spacing = 10
        formatRow.translatesAutoresizingMaskIntoConstraints = false

        recordingSaveFormatTitleLabel = primaryLabel(L10n.recordingSaveFormatSettingLabel)
        formatRow.addArrangedSubview(recordingSaveFormatTitleLabel)
        formatRow.addArrangedSubview(flexSpacer())

        recordingSaveFormatPopup = SettingsPopUpButton(frame: .zero, pullsDown: false)
        recordingSaveFormatPopup.controlSize = .small
        recordingSaveFormatPopup.font = NSFont.systemFont(ofSize: 12)
        recordingSaveFormatPopup.target = self
        recordingSaveFormatPopup.action = #selector(recordingSaveFormatPreferenceChanged(_:))
        constrainGeneralPopupWidth(recordingSaveFormatPopup)
        formatRow.addArrangedSubview(recordingSaveFormatPopup)
        constrainSettingsRowHeight(formatRow)
        inner.addArrangedSubview(formatRow)
        formatRow.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        refreshSavePathControls()

        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func makeSavePathRow(
        title: String,
        identifierPrefix: String,
        chooseAction: Selector,
        revealAction: Selector
    ) -> (row: NSView, title: NSTextField, value: NSTextField, chooseButton: NSButton, revealButton: NSButton) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        let labelStack = NSStackView()
        labelStack.orientation = .vertical
        labelStack.alignment = .leading
        labelStack.spacing = 3
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = primaryLabel(title)
        let valueLabel = secondaryLabel("", wrapping: false)
        valueLabel.lineBreakMode = .byTruncatingMiddle
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(valueLabel)
        row.addArrangedSubview(labelStack)
        labelStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        row.addArrangedSubview(flexSpacer())

        let chooseButton = SettingsOutlinedButton(
            title: L10n.savePathChoose,
            target: self,
            action: chooseAction
        )
        chooseButton.identifier = NSUserInterfaceItemIdentifier("\(identifierPrefix)-save-path-choose")
        configureGeneralOutlinedButton(chooseButton)
        chooseButton.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let revealButton = makeGeneralIconButton(
            symbolName: "folder",
            tooltip: L10n.savePathReveal,
            target: self,
            action: revealAction
        )
        revealButton.identifier = NSUserInterfaceItemIdentifier("\(identifierPrefix)-save-path-reveal")

        let controlGroup = NSStackView(views: [chooseButton, revealButton])
        controlGroup.orientation = .horizontal
        controlGroup.alignment = .centerY
        controlGroup.spacing = 6
        controlGroup.identifier = NSUserInterfaceItemIdentifier("\(identifierPrefix)-save-path-controls")
        controlGroup.translatesAutoresizingMaskIntoConstraints = false
        constrainGeneralControlGroupWidth(controlGroup)
        chooseButton.widthAnchor.constraint(
            equalTo: controlGroup.widthAnchor,
            constant: -(34 + controlGroup.spacing)
        ).isActive = true
        row.addArrangedSubview(controlGroup)
        constrainSettingsRowHeight(row)

        return (row, titleLabel, valueLabel, chooseButton, revealButton)
    }

    private func constrainGeneralPopupWidth(_ popup: NSPopUpButton) {
        popup.translatesAutoresizingMaskIntoConstraints = false
        let constraint = popup.widthAnchor.constraint(equalToConstant: preferredGeneralPopupWidth())
        constraint.isActive = true
        generalPopupWidthConstraints.append(constraint)
    }

    private func refreshGeneralPopupWidths() {
        let width = preferredGeneralPopupWidth()
        for constraint in generalPopupWidthConstraints {
            constraint.constant = width
        }
        for constraint in generalControlGroupWidthConstraints {
            constraint.constant = preferredGeneralControlGroupWidth()
        }
    }

    private func preferredGeneralPopupWidth() -> CGFloat {
        let titles = AppLanguage.allCases.map(\.displayName)
            + SettingsActivationState.allCases.map(\.localizedTitle)
            + ScreenshotOutputMode.allCases.map(\.localizedTitle)
            + ScreenshotImageQuality.allCases.map(\.localizedTitle)
            + RecordingSavePreference.allCases.map(\.displayName)
        let font = NSFont.systemFont(ofSize: 12)
        let textWidth = titles.map {
            ($0 as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 0
        return ceil(textWidth) + 42
    }

    private func configureGeneralActionButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        (button as? SettingsActionButton)?.enableHoverFeedback()
    }

    private func constrainGeneralControlGroupWidth(_ view: NSView) {
        let constraint = view.widthAnchor.constraint(equalToConstant: preferredGeneralControlGroupWidth())
        constraint.isActive = true
        generalControlGroupWidthConstraints.append(constraint)
    }

    private func preferredGeneralControlGroupWidth() -> CGFloat {
        let popup = SettingsPopUpButton(frame: .zero, pullsDown: false)
        popup.controlSize = .small
        let alignmentRect = NSRect(
            x: 0,
            y: 0,
            width: preferredGeneralPopupWidth(),
            height: 34
        )
        return popup.frame(forAlignmentRect: alignmentRect).width
    }

    private func configureGeneralOutlinedButton(_ button: SettingsOutlinedButton) {
        button.controlSize = .large
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
    }

    private func makeGeneralIconButton(
        symbolName: String,
        tooltip: String,
        target: AnyObject?,
        action: Selector
    ) -> SettingsOutlinedButton {
        let button = SettingsOutlinedButton(title: "", target: target, action: action)
        button.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: tooltip
        )?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
        configureGeneralOutlinedButton(button)
        button.widthAnchor.constraint(equalToConstant: 34).isActive = true
        return button
    }

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

    private func buildAboutPane() -> NSView {
        let stack = paneStack(spacing: 0)
        stack.alignment = .leading
        stack.identifier = NSUserInterfaceItemIdentifier("about-content")

        let version = makeAboutMetadataRow(
            title: L10n.aboutVersionTitle,
            value: aboutVersionValueString()
        )
        aboutVersionLabel = version.value
        stack.addArrangedSubview(version.row)
        stack.addArrangedSubview(makeAboutMetadataRow(
            title: L10n.aboutCompatibilityTitle,
            value: L10n.aboutCompatibilityValue
        ).row)
        stack.addArrangedSubview(makeAboutMetadataRow(
            title: L10n.aboutSystemRequirementTitle,
            value: L10n.aboutSystemRequirementValue
        ).row)

        stack.addArrangedSubview(aboutSpacer(height: 22))
        stack.addArrangedSubview(aboutSectionTitle(L10n.aboutIntroductionTitle))
        stack.addArrangedSubview(aboutSpacer(height: 8))
        for paragraph in [
            L10n.aboutIntroductionFirst,
            L10n.aboutIntroductionSecond,
            L10n.aboutIntroductionThird,
        ] {
            let label = aboutBodyLabel(paragraph)
            stack.addArrangedSubview(label)
            label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            stack.addArrangedSubview(aboutSpacer(height: 7))
        }

        stack.addArrangedSubview(aboutSpacer(height: 11))
        stack.addArrangedSubview(aboutSectionTitle(L10n.aboutWebsiteTitle))
        stack.addArrangedSubview(aboutSpacer(height: 6))
        let website = makeAboutActionRow(
            title: L10n.aboutWebsiteURL,
            action: #selector(openWebsite)
        )
        stack.addArrangedSubview(website.row)

        stack.addArrangedSubview(aboutSpacer(height: 20))
        stack.addArrangedSubview(aboutSectionTitle(L10n.aboutRelatedLinksTitle))
        stack.addArrangedSubview(aboutSpacer(height: 6))

        let updateRow = makeUpdateRow()
        stack.addArrangedSubview(updateRow)

        let license = makeAboutActionRow(
            title: L10n.aboutLicense,
            action: #selector(openLicense)
        )
        aboutLicenseTitleLabel = license.title
        stack.addArrangedSubview(license.row)

        let repo = makeAboutActionRow(
            title: L10n.aboutSourceCode,
            action: #selector(openSourceRepo)
        )
        aboutSourceTitleLabel = repo.title
        stack.addArrangedSubview(repo.row)

        let star = makeAboutActionRow(
            title: L10n.aboutStarOnGitHub,
            action: #selector(openStarOnGitHub)
        )
        aboutStarTitleLabel = star.title
        stack.addArrangedSubview(star.row)

        let featureRequest = makeAboutActionRow(
            title: L10n.aboutFeatureRequest,
            action: #selector(openFeatureRequest)
        )
        aboutFeatureRequestTitleLabel = featureRequest.title
        stack.addArrangedSubview(featureRequest.row)

        let bugReport = makeAboutActionRow(
            title: L10n.aboutBugReport,
            action: #selector(openBugReport)
        )
        aboutBugReportTitleLabel = bugReport.title
        stack.addArrangedSubview(bugReport.row)

        let errorLog = makeAboutActionRow(
            title: L10n.aboutErrorLog,
            action: #selector(showErrorLogWindow)
        )
        errorLogTitleLabel = errorLog.title
        stack.addArrangedSubview(errorLog.row)

        stack.addArrangedSubview(aboutSpacer(height: 20))
        stack.addArrangedSubview(aboutSectionTitle(L10n.aboutAcknowledgementsTitle))
        stack.addArrangedSubview(aboutSpacer(height: 8))
        for acknowledgement in [
            L10n.aboutAcknowledgementFirst,
            L10n.aboutAcknowledgementSecond,
            L10n.aboutAcknowledgementThird,
            L10n.aboutAcknowledgementFourth,
            L10n.aboutAcknowledgementFifth,
            L10n.aboutAcknowledgementSixth,
        ] {
            let label = aboutBodyLabel(acknowledgement)
            stack.addArrangedSubview(label)
            label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            stack.addArrangedSubview(aboutSpacer(height: 7))
        }

        return wrapPane(stack, topInset: 18)
    }

    private struct AboutMetadataRowBuild {
        let row: NSView
        let value: NSTextField
    }

    private func makeAboutMetadataRow(title: String, value: String) -> AboutMetadataRowBuild {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = SettingsPalette.primaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.widthAnchor.constraint(equalToConstant: 92).isActive = true

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        valueLabel.textColor = SettingsPalette.secondaryText

        let row = NSStackView(views: [titleLabel, valueLabel])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 25).isActive = true
        return AboutMetadataRowBuild(row: row, value: valueLabel)
    }

    private func aboutSectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        label.textColor = SettingsPalette.primaryText
        return label
    }

    private func aboutBodyLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = SettingsPalette.secondaryText
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    private func aboutSpacer(height: CGFloat) -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }

    @objc private func showErrorLogWindow() {
        if errorLogWindowController == nil {
            errorLogWindowController = ErrorLogWindowController()
        }
        errorLogWindowController?.show(relativeTo: window)
    }

    func closeErrorLogWindow() {
        errorLogWindowController?.close()
    }

    private struct AboutActionRowBuild {
        let row: NSView
        let title: NSTextField
        let detail: NSTextField
        let button: NSButton?
    }

    /// Plain text link used by the document-style About page.
    private func makeAboutActionRow(
        title: String,
        detail: String = "",
        action: Selector? = nil
    ) -> AboutActionRowBuild {
        let row: NSView
        let button: HoverButton?
        if let action {
            let link = HoverButton()
            link.target = self
            link.action = action
            link.title = ""
            link.isBordered = false
            link.cornerRadius = 0
            link.showsHoverBackground = false
            link.setAccessibilityLabel(title)
            row = link
            button = link
        } else {
            row = NSView()
            button = nil
        }
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        titleLabel.textColor = NSColor.systemBlue
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = SettingsPalette.secondaryText
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.isHidden = detail.isEmpty

        let contentStack = NSStackView(views: [titleLabel, detailLabel])
        contentStack.orientation = .horizontal
        contentStack.alignment = .firstBaseline
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(contentStack)
        button?.interactiveContentView = contentStack
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.aboutLinkRowHeight),
            contentStack.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            contentStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        return AboutActionRowBuild(
            row: row,
            title: titleLabel,
            detail: detailLabel,
            button: button
        )
    }

    @objc private func openSourceRepo() {
        if let url = URL(string: "https://github.com/aulyc/aulycShot") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openWebsite() {
        if let url = URL(string: "https://www.aulyc.com") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openLicense() {
        if let url = URL(string: "https://github.com/aulyc/aulycShot/blob/main/LICENSE") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openStarOnGitHub() {
        if let url = URL(string: "https://github.com/aulyc/aulycShot") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openFeatureRequest() {
        if let url = URL(string: "https://github.com/aulyc/aulycShot/issues/new?template=feature_request.yml") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openBugReport() {
        if let url = URL(string: "https://github.com/aulyc/aulycShot/issues/new?template=bug_report.yml") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Compact update link whose trailing status tracks the current update state.
    private func makeUpdateRow() -> NSView {
        let update = makeAboutActionRow(
            title: L10n.aboutUpdateTitle,
            action: #selector(aboutUpdateButtonClicked)
        )
        aboutUpdateTitleLabel = update.title
        aboutUpdateStatusLabel = update.detail
        aboutUpdateButton = update.button

        refreshUpdateRow()
        return update.row
    }

    @objc private func aboutUpdateButtonClicked() {
        switch UpdateChecker.shared.state {
        case .available(let version):
            StatusBarController.presentUpdateAvailableAlertAfterRefresh(fallbackVersion: version)
        case .installFailed:
            if let url = UpdateChecker.shared.latestPageURL {
                NSWorkspace.shared.open(url)
            }
        default:
            UpdateChecker.shared.check(manual: true)
        }
    }

    /// Syncs the Updates row to the current check state.
    @objc private func refreshUpdateRow() {
        guard let statusLabel = aboutUpdateStatusLabel, let button = aboutUpdateButton else { return }
        let dim = NSColor.white.withAlphaComponent(0.55)
        let accent = NSColor(calibratedRed: 0.42, green: 0.66, blue: 0.98, alpha: 1.0)
        let warn = NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.45, alpha: 1.0)

        switch UpdateChecker.shared.state {
        case .idle:
            statusLabel.stringValue = ""
            statusLabel.textColor = dim
            button.isEnabled = true
        case .checking:
            statusLabel.stringValue = L10n.updateChecking
            statusLabel.textColor = dim
            button.isEnabled = false
        case .upToDate:
            statusLabel.stringValue = L10n.updateUpToDateStatus
            statusLabel.textColor = dim
            button.isEnabled = true
        case .available(let version):
            statusLabel.stringValue = L10n.updateNewVersionStatus(version)
            statusLabel.textColor = accent
            button.isEnabled = true
        case .downloading(_, let fraction):
            statusLabel.stringValue = L10n.updateDownloadingStatus(Int(fraction * 100))
            statusLabel.textColor = accent
            button.isEnabled = false
        case .installing:
            statusLabel.stringValue = L10n.updateInstallingStatus
            statusLabel.textColor = accent
            button.isEnabled = false
        case .failed:
            statusLabel.stringValue = L10n.updateFailedStatus
            statusLabel.textColor = warn
            button.isEnabled = true
        case .installFailed:
            statusLabel.stringValue = L10n.updateInstallFailedStatus
            statusLabel.textColor = warn
            button.isEnabled = true
        }
        statusLabel.isHidden = statusLabel.stringValue.isEmpty
        let accessibilityStatus = statusLabel.stringValue
        button.setAccessibilityLabel(
            accessibilityStatus.isEmpty
                ? L10n.aboutUpdateTitle
                : "\(L10n.aboutUpdateTitle) \(accessibilityStatus)"
        )
    }

    private func paneStack(spacing: CGFloat = 14) -> NSStackView {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = spacing
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }

    private func wrapPane(_ stack: NSStackView, topInset: CGFloat = 18) -> NSView {
        let host = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: host.topAnchor, constant: topInset),
            stack.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -28),
            stack.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -28),
        ])
        return host
    }

    // MARK: - Builders

    private static let settingsRowMinimumHeight: CGFloat = 52
    private static let aboutLinkRowHeight: CGFloat = 28

    private func generalCard() -> CardView {
        let card = CardView()
        card.showsTopBorder = false
        return card
    }

    private func constrainSettingsRowHeight(_ row: NSView) {
        row.heightAnchor.constraint(
            greaterThanOrEqualToConstant: Self.settingsRowMinimumHeight
        ).isActive = true
    }

    private func verticalInnerStack() -> NSStackView {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 0
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }

    private func rowDivider() -> NSView {
        let v = HairlineSeparatorView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    private func flexSpacer() -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.setContentHuggingPriority(.init(1), for: .horizontal)
        v.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        return v
    }

    private func primaryLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        l.textColor = SettingsPalette.primaryText
        return l
    }

    private func secondaryLabel(_ text: String, wrapping: Bool = false) -> NSTextField {
        let l = wrapping ? NSTextField(wrappingLabelWithString: text) : NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: 11)
        l.textColor = SettingsPalette.secondaryText
        if wrapping {
            l.preferredMaxLayoutWidth = 360
        }
        return l
    }

    private func pin(_ child: NSView, to parent: NSView, insets: NSEdgeInsets) {
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor, constant: insets.top),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: insets.left),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -insets.right),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -insets.bottom),
        ])
    }

    private struct ShortcutCardBuild {
        let card: CardView
        let title: NSTextField
        let field: NSTextField
        let setButton: NSButton
    }

    private func buildShortcutCard(
        title: String,
        setAction: Selector
    ) -> ShortcutCardBuild {
        let card = generalCard()
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 0
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        pin(inner, to: card, insets: NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = primaryLabel(title)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(flexSpacer())

        let field = NSTextField()
        field.isEditable = false
        field.isSelectable = false
        field.isBordered = false
        field.drawsBackground = false
        field.alignment = .center
        field.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        field.textColor = NSColor.white.withAlphaComponent(0.92)
        field.translatesAutoresizingMaskIntoConstraints = false

        let fieldBackground = NSView()
        fieldBackground.wantsLayer = true
        fieldBackground.layer?.cornerRadius = 8
        fieldBackground.layer?.cornerCurve = .continuous
        fieldBackground.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        fieldBackground.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
        fieldBackground.layer?.borderWidth = 1
        fieldBackground.translatesAutoresizingMaskIntoConstraints = false
        fieldBackground.addSubview(field)
        NSLayoutConstraint.activate([
            field.centerYAnchor.constraint(equalTo: fieldBackground.centerYAnchor),
            field.leadingAnchor.constraint(equalTo: fieldBackground.leadingAnchor, constant: 10),
            field.trailingAnchor.constraint(equalTo: fieldBackground.trailingAnchor, constant: -10),
            fieldBackground.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            fieldBackground.heightAnchor.constraint(equalToConstant: 34),
        ])
        row.addArrangedSubview(fieldBackground)

        let setButton = SettingsActionButton(
            title: L10n.shortcutSet,
            target: self,
            action: setAction
        )
        configureGeneralActionButton(setButton)
        row.addArrangedSubview(setButton)

        inner.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true
        constrainSettingsRowHeight(row)

        return ShortcutCardBuild(
            card: card,
            title: titleLabel,
            field: field,
            setButton: setButton
        )
    }

    private struct ActivationRowBuild {
        let row: NSView
        let title: NSTextField
        let subtitle: NSTextField?
        let picker: NSPopUpButton
    }

    private func makeActivationRow(
        title: String,
        subtitle: String?,
        isOn: Bool,
        identifier: String,
        action: Selector
    ) -> ActivationRowBuild {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = primaryLabel(title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(titleLabel)

        var subtitleLabel: NSTextField? = nil
        if let subtitle {
            let sub = secondaryLabel(subtitle, wrapping: true)
            textStack.addArrangedSubview(sub)
            subtitleLabel = sub
        }

        let picker = SettingsPopUpButton(frame: .zero, pullsDown: false)
        picker.identifier = NSUserInterfaceItemIdentifier(identifier)
        picker.target = self
        picker.action = action
        picker.controlSize = .small
        picker.font = NSFont.systemFont(ofSize: 12)
        constrainGeneralPopupWidth(picker)
        refreshActivationPicker(picker, isEnabled: isOn)

        row.addSubview(textStack)
        row.addSubview(picker)

        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            textStack.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -10),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: picker.leadingAnchor, constant: -12),

            picker.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            picker.centerYAnchor.constraint(equalTo: textStack.centerYAnchor),
        ])
        constrainSettingsRowHeight(row)

        return ActivationRowBuild(
            row: row,
            title: titleLabel,
            subtitle: subtitleLabel,
            picker: picker
        )
    }

    private func refreshActivationPicker(
        _ picker: NSPopUpButton?,
        isEnabled: Bool
    ) {
        guard let picker else { return }
        let selectedState = SettingsActivationState(isEnabled: isEnabled)
        picker.removeAllItems()
        for state in SettingsActivationState.allCases {
            picker.addItem(withTitle: state.localizedTitle)
            picker.lastItem?.representedObject = state.rawValue
        }
        if let selectedIndex = SettingsActivationState.allCases.firstIndex(of: selectedState) {
            picker.selectItem(at: selectedIndex)
        }
    }

    private func selectedActivationState(
        from picker: NSPopUpButton
    ) -> SettingsActivationState? {
        guard let rawValue = picker.selectedItem?.representedObject as? String else {
            return nil
        }
        return SettingsActivationState(rawValue: rawValue)
    }

    private struct RadioRowBuild {
        let row: NSView
        let title: NSTextField
        let subtitle: NSTextField?
        let button: NSButton
    }

    private func makeRadioRow(
        title: String,
        subtitle: String?,
        isOn: Bool,
        action: Selector
    ) -> RadioRowBuild {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = primaryLabel(title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(titleLabel)

        var subtitleLabel: NSTextField? = nil
        if let subtitle {
            let sub = secondaryLabel(subtitle, wrapping: true)
            textStack.addArrangedSubview(sub)
            subtitleLabel = sub
        }

        let button = NSButton(radioButtonWithTitle: "", target: self, action: action)
        button.state = isOn ? .on : .off
        button.controlSize = .small
        button.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(textStack)
        row.addSubview(button)

        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            textStack.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -10),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -12),

            button.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            button.centerYAnchor.constraint(equalTo: textStack.centerYAnchor),
        ])

        return RadioRowBuild(row: row, title: titleLabel, subtitle: subtitleLabel, button: button)
    }

    // MARK: - Permission polling

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshPermissionStatus()
        }
    }

    func refreshPermissionStatus() {
        let availability = AppPermissions.featureAvailability
        featurePermissionStatus?.configure(isAvailable: availability.isAvailable)
    }

    // MARK: - Actions

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        let cases = AppLanguage.allCases
        let index = sender.indexOfSelectedItem
        guard cases.indices.contains(index) else { return }
        Defaults.language = cases[index]
    }

    @objc private func recordingSaveFormatPreferenceChanged(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              let preference = RecordingSavePreference(rawValue: raw)
        else {
            return
        }
        Defaults.recordingSavePreference = preference
    }

    @objc private func screenshotQualityChanged(_ sender: NSPopUpButton) {
        guard let quality = selectedScreenshotQuality(from: sender) else { return }
        Defaults.screenshotQuality = quality
        refreshScreenshotQualityControls()
    }

    @objc private func screenshotOutputModeChanged(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              let mode = ScreenshotOutputMode(rawValue: raw)
        else {
            return
        }
        Defaults.screenshotOutputMode = mode
        refreshScreenshotOutputControls()
    }

    private func selectedScreenshotQuality(from sender: NSPopUpButton) -> ScreenshotImageQuality? {
        guard let raw = sender.selectedItem?.representedObject as? String else { return nil }
        return ScreenshotImageQuality(rawValue: raw)
    }

    @objc private func chooseRecordingSavePathClicked() {
        chooseSaveDirectory(
            title: L10n.chooseRecordingSavePathTitle,
            currentURL: Defaults.recordingSaveDirectory
        ) { url in
            Defaults.recordingSaveDirectory = url
            self.refreshSavePathControls()
        }
    }

    @objc private func chooseScreenshotSavePathClicked() {
        guard Defaults.screenshotOutputMode.savesToDirectory else { return }
        chooseSaveDirectory(
            title: L10n.chooseScreenshotSavePathTitle,
            currentURL: Defaults.screenshotSaveDirectory
        ) { url in
            Defaults.screenshotSaveDirectory = url
            self.refreshSavePathControls()
        }
    }

    @objc private func revealRecordingSavePathClicked() {
        revealSaveDirectory(Defaults.recordingSaveDirectory)
    }

    @objc private func revealScreenshotSavePathClicked() {
        guard Defaults.screenshotOutputMode.savesToDirectory else { return }
        revealSaveDirectory(Defaults.screenshotSaveDirectory)
    }

    private func chooseSaveDirectory(
        title: String,
        currentURL: URL,
        completion: @escaping (URL) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = L10n.savePathChoose
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = directoryURLForPanel(currentURL)

        let handle: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            completion(url)
        }

        if let window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            panel.begin(completionHandler: handle)
        }
    }

    private func directoryURLForPanel(_ url: URL) -> URL {
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        let parent = url.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: parent.path) {
            return parent
        }
        return Defaults.defaultScreenshotSaveDirectory.deletingLastPathComponent()
    }

    private func revealSaveDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func launchAtLoginStateChanged(_ sender: NSPopUpButton) {
        guard let state = selectedActivationState(from: sender) else { return }
        let enable = state.isEnabled
        let ok = LaunchAtLogin.setEnabled(enable)
        if !ok {
            refreshActivationPicker(sender, isEnabled: LaunchAtLogin.isEnabled)
        }
    }

    @objc private func demoModeStateChanged(_ sender: NSPopUpButton) {
        guard let state = selectedActivationState(from: sender) else { return }
        Defaults.demoMode = state.isEnabled
    }

    @objc private func automaticUpdateChecksStateChanged(_ sender: NSPopUpButton) {
        guard let state = selectedActivationState(from: sender) else { return }
        Defaults.automaticUpdateChecksEnabled = state.isEnabled
    }

    @objc private func menuBarStateChanged(_ sender: NSPopUpButton) {
        guard let state = selectedActivationState(from: sender) else { return }
        let visible = state.isEnabled
        Defaults.showMenuBar = visible
        onMenuBarToggle?(visible)
    }

    @objc private func featurePermissionHelpClicked() {
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

    private func removePermissionAlertOutsideClickMonitor() {
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

    private func refreshShortcutDisplay() {
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

    private func refreshSelectedImagePinShortcutDisplay() {
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

    private func refreshClipboardImagePinShortcutDisplay() {
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

    private func refreshClipboardTextPinShortcutDisplay() {
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

    private func refreshSelectedImageEditShortcutDisplay() {
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

    private func refreshClipboardImageEditShortcutDisplay() {
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

    private func refreshRecordShortcutDisplay() {
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

    private func refreshImageMergeShortcutDisplay() {
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

    private func refreshClipboardShortcutDisplay() {
        clipboardShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentClipboardDisplayString() {
            clipboardShortcutField?.stringValue = display
        } else {
            clipboardShortcutField?.stringValue = L10n.clipboardShortcutDefaultDisplay
        }
    }

    @objc private func detailResetClicked() {
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
        shortcutTitleLabel?.stringValue = L10n.shortcutHeader
        selectedImagePinShortcutTitleLabel?.stringValue = L10n.selectedImagePinShortcutHeader
        clipboardImagePinShortcutTitleLabel?.stringValue = L10n.clipboardImagePinShortcutHeader
        clipboardTextPinShortcutTitleLabel?.stringValue = L10n.clipboardTextPinShortcutHeader
        selectedImageEditShortcutTitleLabel?.stringValue = L10n.selectedImageEditShortcutHeader
        clipboardImageEditShortcutTitleLabel?.stringValue = L10n.clipboardImageEditShortcutHeader
        recordShortcutTitleLabel?.stringValue = L10n.recordShortcutHeader
        imageMergeShortcutTitleLabel?.stringValue = L10n.imageMergeShortcutHeader
        clipboardShortcutTitleLabel?.stringValue = L10n.clipboardShortcutHeader
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
        refreshShortcutDisplay()
        refreshSelectedImagePinShortcutDisplay()
        refreshClipboardImagePinShortcutDisplay()
        refreshClipboardTextPinShortcutDisplay()
        refreshSelectedImageEditShortcutDisplay()
        refreshClipboardImageEditShortcutDisplay()
        refreshRecordShortcutDisplay()
        refreshImageMergeShortcutDisplay()
        refreshClipboardShortcutDisplay()
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

enum SettingsPalette {
    static let accent = NSColor(calibratedRed: 0.34, green: 0.78, blue: 0.84, alpha: 1.0)
    static let sidebarBackground = NSColor(calibratedWhite: 0.155, alpha: 1.0)
    static let contentBackground = NSColor(calibratedWhite: 0.115, alpha: 1.0)
    static let primaryText = NSColor.white.withAlphaComponent(0.94)
    static let secondaryText = NSColor.white.withAlphaComponent(0.62)
    static let tertiaryText = NSColor.white.withAlphaComponent(0.38)
    static let separator = NSColor.white.withAlphaComponent(0.10)
}

// MARK: - Flipped view (top-aligned scroll content)

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Sidebar / detail panels

private final class SidebarPanel: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = SettingsPalette.sidebarBackground.cgColor
        layer?.borderColor = SettingsPalette.separator.cgColor
        layer?.borderWidth = 1
    }
}

private final class DetailPanel: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = SettingsPalette.contentBackground.cgColor
    }
}

// MARK: - Sidebar tab button

final class TabButton: NSControl {
    let tab: SettingsTab
    private let iconChip = NSView()
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet { applyAppearance() }
    }

    var isSelected: Bool = false {
        didSet { applyAppearance() }
    }

    init(tab: SettingsTab) {
        self.tab = tab
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(tab.title)
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.cornerCurve = .continuous

        iconChip.translatesAutoresizingMaskIntoConstraints = false
        iconChip.wantsLayer = true
        addSubview(iconChip)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: tab.iconName, accessibilityDescription: nil)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iconView.imageScaling = .scaleProportionallyDown
        iconChip.addSubview(iconView)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.stringValue = tab.title
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 42),

            iconChip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconChip.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconChip.widthAnchor.constraint(equalToConstant: 22),
            iconChip.heightAnchor.constraint(equalToConstant: 22),

            iconView.centerXAnchor.constraint(equalTo: iconChip.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconChip.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            label.leadingAnchor.constraint(equalTo: iconChip.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
        ])

        applyAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshTitle() {
        label.stringValue = tab.title
        setAccessibilityLabel(tab.title)
    }

    private func applyAppearance() {
        if isSelected {
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderWidth = 0
            label.textColor = SettingsPalette.accent
            iconChip.layer?.backgroundColor = NSColor.clear.cgColor
            iconView.contentTintColor = SettingsPalette.accent
        } else if isHovered {
            layer?.backgroundColor = SettingsPalette.contentBackground.withAlphaComponent(0.70).cgColor
            layer?.borderWidth = 0
            label.textColor = SettingsPalette.primaryText
            iconChip.layer?.backgroundColor = NSColor.clear.cgColor
            iconView.contentTintColor = SettingsPalette.primaryText
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderWidth = 0
            label.textColor = SettingsPalette.secondaryText
            iconChip.layer?.backgroundColor = NSColor.clear.cgColor
            iconView.contentTintColor = SettingsPalette.secondaryText
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }

    override var acceptsFirstResponder: Bool { true }
}

// MARK: - Card view

private final class HairlineSeparatorView: NSView {
    private let separatorLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        separatorLayer.backgroundColor = SettingsPalette.separator.cgColor
        layer?.addSublayer(separatorLayer)
    }

    override func layout() {
        super.layout()
        let hairline = 1 / (window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2)
        separatorLayer.frame = NSRect(
            x: 0,
            y: (bounds.height - hairline) / 2,
            width: bounds.width,
            height: hairline
        )
    }
}

private final class CardView: NSView {
    private let topBorder = CALayer()
    private let bottomBorder = CALayer()

    var showsTopBorder = true {
        didSet { topBorder.isHidden = !showsTopBorder }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        topBorder.backgroundColor = SettingsPalette.separator.cgColor
        bottomBorder.backgroundColor = SettingsPalette.separator.cgColor
        layer?.addSublayer(topBorder)
        layer?.addSublayer(bottomBorder)
    }

    override func layout() {
        super.layout()
        let hairline = 1 / (window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2)
        topBorder.frame = NSRect(x: 0, y: bounds.height - hairline, width: bounds.width, height: hairline)
        bottomBorder.frame = NSRect(x: 0, y: 0, width: bounds.width, height: hairline)
    }
}

// MARK: - Sidebar permission status

final class PermissionStatusIndicator: NSView {
    static let availableColor = NSColor(calibratedRed: 0.10, green: 0.52, blue: 0.24, alpha: 1.0)
    static let unavailableColor = NSColor.systemRed

    private(set) var titleLabel = NSTextField(labelWithString: "")
    private(set) var dotView = NSView()
    private(set) var stateLabel = NSTextField(labelWithString: "")
    private(set) var isAvailable = false
    private(set) var title: String

    init(title: String) {
        self.title = title
        super.init(frame: .zero)
        commonInit()
        refreshAppearance()
    }

    required init?(coder: NSCoder) {
        title = ""
        super.init(coder: coder)
        commonInit()
        refreshAppearance()
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 4
        dotView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dotView)

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = SettingsPalette.secondaryText
        titleLabel.alignment = .left
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(titleLabel)

        stateLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        stateLabel.alignment = .left
        stateLabel.translatesAutoresizingMaskIntoConstraints = false
        stateLabel.setContentHuggingPriority(.required, for: .horizontal)
        stateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(stateLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            dotView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            dotView.centerYAnchor.constraint(equalTo: centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 8),
            dotView.heightAnchor.constraint(equalToConstant: 8),

            stateLabel.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 6),
            stateLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            stateLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 18),
        ])
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setAccessibilityElement(true)
    }

    func setTitle(_ title: String) {
        self.title = title
        refreshAppearance()
    }

    func configure(isAvailable: Bool) {
        self.isAvailable = isAvailable
        refreshAppearance()
    }

    private func refreshAppearance() {
        let stateTitle = isAvailable ? L10n.permissionAvailable : L10n.permissionUnavailable
        let color = isAvailable ? Self.availableColor : Self.unavailableColor
        titleLabel.stringValue = title
        titleLabel.textColor = SettingsPalette.secondaryText
        stateLabel.stringValue = stateTitle
        stateLabel.textColor = color
        dotView.layer?.backgroundColor = color.cgColor
        setAccessibilityLabel("\(title) \(stateTitle)")
    }
}

// MARK: - Pointing-hand action button

final class SettingsOutlinedButton: NSButton {
    static let cornerRadius: CGFloat = 7
    static let restingBackgroundColor = NSColor.white.withAlphaComponent(0.055)
    static let hoveredBackgroundColor = NSColor.white.withAlphaComponent(0.085)
    static let pressedBackgroundColor = NSColor.white.withAlphaComponent(0.12)
    static let disabledBackgroundColor = NSColor.white.withAlphaComponent(0.025)
    static let restingBorderColor = NSColor.white.withAlphaComponent(0.16)
    static let focusedBorderColor = SettingsPalette.accent.withAlphaComponent(0.72)
    static let enabledContentColor = SettingsPalette.primaryText
    static let disabledContentColor = SettingsPalette.primaryText.withAlphaComponent(0.38)

    private var trackingArea: NSTrackingArea?
    private(set) var isHovered = false
    private var isPressed = false

    override var alignmentRectInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    override var title: String {
        didSet { applyContentAppearance() }
    }

    override var isEnabled: Bool {
        didSet {
            if !isEnabled {
                isHovered = false
                isPressed = false
            }
            applyAppearance()
            window?.invalidateCursorRects(for: self)
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        applyAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isBordered = false
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = Self.cornerRadius
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        (cell as? NSButtonCell)?.highlightsBy = []
        applyAppearance()
    }

    func setHovered(_ hovered: Bool) {
        isHovered = hovered && isEnabled
        applyAppearance()
    }

    private func applyAppearance() {
        let backgroundColor: NSColor
        if !isEnabled {
            backgroundColor = Self.disabledBackgroundColor
        } else if isPressed {
            backgroundColor = Self.pressedBackgroundColor
        } else if isHovered {
            backgroundColor = Self.hoveredBackgroundColor
        } else {
            backgroundColor = Self.restingBackgroundColor
        }

        layer?.backgroundColor = backgroundColor.cgColor
        layer?.borderColor = (
            window?.firstResponder === self
                ? Self.focusedBorderColor
                : Self.restingBorderColor
        ).cgColor
        contentTintColor = isEnabled ? Self.enabledContentColor : Self.disabledContentColor
        applyContentAppearance()
        needsDisplay = true
    }

    private func applyContentAppearance() {
        guard imagePosition != .imageOnly, !title.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: isEnabled ? Self.enabledContentColor : Self.disabledContentColor,
        ]
        let stableTitle = NSAttributedString(string: title, attributes: attributes)
        attributedTitle = stableTitle
        attributedAlternateTitle = stableTitle
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        applyAppearance()
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        applyAppearance()
        return resigned
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        setHovered(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovered(false)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = true
        applyAppearance()
        super.mouseDown(with: event)
        isPressed = false
        applyAppearance()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard isEnabled else { return }
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

final class SettingsActionButton: NSButton {
    static let restingBezelColor = NSColor.white.withAlphaComponent(0.09)
    static let hoveredBezelColor = NSColor.white.withAlphaComponent(0.16)
    static let pressedBezelColor = NSColor.white.withAlphaComponent(0.22)
    static let disabledBezelColor = NSColor.white.withAlphaComponent(0.05)
    static let enabledTitleColor = SettingsPalette.primaryText
    static let disabledTitleColor = SettingsPalette.primaryText.withAlphaComponent(0.38)

    private var trackingArea: NSTrackingArea?
    private(set) var isHovered = false
    private var isPressed = false
    private var hoverFeedbackEnabled = false

    override var title: String {
        didSet { applyTitleAppearance() }
    }

    override var isEnabled: Bool {
        didSet {
            if oldValue != isEnabled {
                if !isEnabled {
                    isHovered = false
                    isPressed = false
                }
                applyAppearance()
                window?.invalidateCursorRects(for: self)
            }
        }
    }

    func enableHoverFeedback() {
        hoverFeedbackEnabled = true
        updateTrackingAreas()
        applyAppearance()
    }

    func setHovered(_ hovered: Bool) {
        isHovered = hovered && isEnabled
        applyAppearance()
    }

    private func applyAppearance() {
        if !isEnabled {
            bezelColor = Self.disabledBezelColor
        } else if isPressed {
            bezelColor = Self.pressedBezelColor
        } else if isHovered {
            bezelColor = Self.hoveredBezelColor
        } else {
            bezelColor = Self.restingBezelColor
        }
        applyTitleAppearance()
        needsDisplay = true
    }

    private func applyTitleAppearance() {
        guard imagePosition != .imageOnly, !title.isEmpty else { return }
        let color = isEnabled ? Self.enabledTitleColor : Self.disabledTitleColor
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: color,
        ]
        let stableTitle = NSAttributedString(string: title, attributes: attributes)
        attributedTitle = stableTitle
        attributedAlternateTitle = stableTitle
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        guard hoverFeedbackEnabled else {
            trackingArea = nil
            return
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        setHovered(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovered(false)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = true
        applyAppearance()
        super.mouseDown(with: event)
        isPressed = false
        applyAppearance()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard isEnabled else { return }
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

// MARK: - Hover button (clickable permission row)

final class HoverButton: NSButton {
    var cornerRadius: CGFloat = 10 {
        didSet { layer?.cornerRadius = cornerRadius }
    }
    var showsHoverBackground = true {
        didSet {
            if !showsHoverBackground {
                layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }
    var interactiveContentView: NSView? {
        didSet {
            window?.invalidateCursorRects(for: self)
        }
    }
    private var trackingArea: NSTrackingArea?

    var interactiveBounds: NSRect {
        guard let interactiveContentView else { return bounds }
        let contentBounds = convert(interactiveContentView.bounds, from: interactiveContentView)
        return contentBounds
            .insetBy(dx: -6, dy: -4)
            .intersection(bounds)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.clear.cgColor
        (cell as? NSButtonCell)?.highlightsBy = []
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: interactiveBounds,
            options: [.mouseEnteredAndExited, .cursorUpdate, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func layout() {
        super.layout()
        guard interactiveContentView != nil else { return }
        updateTrackingAreas()
        window?.invalidateCursorRects(for: self)
    }

    override func mouseEntered(with event: NSEvent) {
        if isEnabled {
            NSCursor.pointingHand.set()
        }
        guard showsHoverBackground else { return }
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        guard showsHoverBackground else { return }
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func cursorUpdate(with event: NSEvent) {
        (isEnabled ? NSCursor.pointingHand : NSCursor.arrow).set()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard isEnabled else { return }
        addCursorRect(interactiveBounds, cursor: .pointingHand)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = superview.map { convert(point, from: $0) } ?? point
        guard isEnabled, interactiveBounds.contains(localPoint) else { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        if showsHoverBackground {
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor
        }
        super.mouseDown(with: event)
        if showsHoverBackground {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}
