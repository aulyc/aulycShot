import AppKit
import Carbon
import PermissionFlow

// MARK: - Tab model

enum SettingsTab: CaseIterable {
    case general
    case shortcuts
    case toolbar
    case permissions
    case about

    var title: String {
        switch self {
        case .general: return L10n.settingsTabGeneral
        case .shortcuts: return L10n.settingsTabShortcuts
        case .toolbar: return L10n.settingsTabToolbar
        case .permissions: return L10n.settingsTabPermissions
        case .about: return L10n.settingsTabAbout
        }
    }

    var iconName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .shortcuts: return "keyboard"
        case .toolbar: return "slider.horizontal.3"
        case .permissions: return "lock.shield.fill"
        case .about: return "info.circle.fill"
        }
    }

    var iconTint: NSColor {
        switch self {
        case .general: return NSColor(calibratedRed: 0.62, green: 0.66, blue: 0.72, alpha: 1.0)
        case .shortcuts: return NSColor(calibratedRed: 0.36, green: 0.66, blue: 0.98, alpha: 1.0)
        case .toolbar: return NSColor(calibratedRed: 0.95, green: 0.54, blue: 0.62, alpha: 1.0)
        case .permissions: return NSColor(calibratedRed: 0.36, green: 0.78, blue: 0.50, alpha: 1.0)
        case .about: return NSColor(calibratedRed: 0.70, green: 0.56, blue: 0.96, alpha: 1.0)
        }
    }

    var description: String {
        switch self {
        case .general: return L10n.settingsTabGeneralDescription
        case .shortcuts: return L10n.settingsTabShortcutsDescription
        case .toolbar: return L10n.settingsTabToolbarDescription
        case .permissions: return L10n.settingsTabPermissionsDescription
        case .about: return L10n.settingsTabAboutDescription
        }
    }
}

enum RequiredPermission: Equatable {
    case accessibility
    case screenRecording

    var flowPane: PermissionFlowPane {
        switch self {
        case .accessibility: return .accessibility
        case .screenRecording: return .screenRecording
        }
    }
}

class SettingsView: NSView {

    var onMenuBarToggle: ((Bool) -> Void)?
    var onPermissionSettingsRequest: ((RequiredPermission, NSView) -> Void)?

    // Switches
    private var menuBarSwitch: NSSwitch!
    private var launchAtLoginSwitch: NSSwitch!
    private var demoModeSwitch: NSSwitch!

    // Picker & slider
    private var langPicker: NSPopUpButton!

    // Window-capture shadow card
    private var windowShadowPicker: NSPopUpButton!
    private var windowShadowPreviewButton: NSButton!
    private var windowShadowPreview: ShadowPreviewView?
    private var windowShadowPreviewPopover: NSPopover?
    private var windowShadowTitleLabel: NSTextField!
    private var windowShadowSubtitleLabel: NSTextField?
    private var windowShadowLevelHintLabel: NSTextField?

    // Screenshot shortcut card
    private var shortcutTitleLabel: NSTextField!
    private var shortcutField: NSTextField!
    private var shortcutSetButton: NSButton!
    private var shortcutRestoreButton: NSButton!
    private var shortcutRecordingMonitor: Any?

    // Pin selected image shortcut card
    private var selectedImagePinShortcutTitleLabel: NSTextField!
    private var selectedImagePinShortcutField: NSTextField!
    private var selectedImagePinShortcutSetButton: NSButton!
    private var selectedImagePinShortcutRestoreButton: NSButton!
    private var selectedImagePinShortcutRecordingMonitor: Any?

    // Pin clipboard image shortcut card
    private var clipboardImagePinShortcutTitleLabel: NSTextField!
    private var clipboardImagePinShortcutField: NSTextField!
    private var clipboardImagePinShortcutSetButton: NSButton!
    private var clipboardImagePinShortcutRestoreButton: NSButton!
    private var clipboardImagePinShortcutRecordingMonitor: Any?

    // Pin clipboard text shortcut card
    private var clipboardTextPinShortcutTitleLabel: NSTextField!
    private var clipboardTextPinShortcutField: NSTextField!
    private var clipboardTextPinShortcutSetButton: NSButton!
    private var clipboardTextPinShortcutRestoreButton: NSButton!
    private var clipboardTextPinShortcutRecordingMonitor: Any?

    // Edit selected image shortcut card
    private var selectedImageEditShortcutTitleLabel: NSTextField!
    private var selectedImageEditShortcutField: NSTextField!
    private var selectedImageEditShortcutSetButton: NSButton!
    private var selectedImageEditShortcutRestoreButton: NSButton!
    private var selectedImageEditShortcutRecordingMonitor: Any?

    // Edit clipboard image shortcut card
    private var clipboardImageEditShortcutTitleLabel: NSTextField!
    private var clipboardImageEditShortcutField: NSTextField!
    private var clipboardImageEditShortcutSetButton: NSButton!
    private var clipboardImageEditShortcutRestoreButton: NSButton!
    private var clipboardImageEditShortcutRecordingMonitor: Any?

    // Recording shortcut card
    private var recordShortcutTitleLabel: NSTextField!
    private var recordShortcutField: NSTextField!
    private var recordShortcutSetButton: NSButton!
    private var recordShortcutRestoreButton: NSButton!
    private var recordShortcutRecordingMonitor: Any?

    // Image Merge shortcut card
    private var imageMergeShortcutTitleLabel: NSTextField!
    private var imageMergeShortcutField: NSTextField!
    private var imageMergeShortcutSetButton: NSButton!
    private var imageMergeShortcutRestoreButton: NSButton!
    private var imageMergeShortcutRecordingMonitor: Any?

    // Copy-to-clipboard (editor confirm) shortcut card
    private var clipboardShortcutTitleLabel: NSTextField!
    private var clipboardShortcutField: NSTextField!
    private var clipboardShortcutSetButton: NSButton!
    private var clipboardShortcutRestoreButton: NSButton!
    private var clipboardShortcutRecordingMonitor: Any?

    // Save-to-file shortcut card (default ⌘S)
    private var fileSaveShortcutTitleLabel: NSTextField!
    private var fileSaveShortcutField: NSTextField!
    private var fileSaveShortcutSetButton: NSButton!
    private var fileSaveShortcutRestoreButton: NSButton!
    private var fileSaveShortcutRecordingMonitor: Any?

    private var shortcutResetButton: NSButton?

    // Permission badges
    private var accessibilityBadge: StatusBadge!
    private var screenRecordingBadge: StatusBadge!

    // Sidebar availability status
    private var availabilityDotView: NSView?
    private var availabilityStatusLabel: NSTextField?

    // Labels (kept for language switching)
    private var menuBarTitleLabel: NSTextField!
    private var launchAtLoginTitleLabel: NSTextField!
    private var demoModeTitleLabel: NSTextField!
    private var demoModeSubtitleLabel: NSTextField!
    private var langTitleLabel: NSTextField!
    private var permHeaderSubtitleLabel: NSTextField?
    private var accessibilityNameLabel: NSTextField!
    private var accessibilityDescLabel: NSTextField!
    private var screenRecordingNameLabel: NSTextField!
    private var screenRecordingDescLabel: NSTextField!
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
    private var detailScrollView: NSScrollView!
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

    private var refreshTimer: Timer?
    private lazy var permissionFlowController = PermissionFlow.makeController(
        configuration: PermissionFlowConfiguration(
            requiredAppURLs: [Bundle.main.bundleURL],
            localeIdentifier: Defaults.language.lprojName
        )
    )

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
        cancelShortcutRecording()
        cancelSelectedImagePinShortcutRecording()
        cancelClipboardImagePinShortcutRecording()
        cancelClipboardTextPinShortcutRecording()
        cancelSelectedImageEditShortcutRecording()
        cancelClipboardImageEditShortcutRecording()
        cancelRecordShortcutRecording()
        cancelImageMergeShortcutRecording()
        cancelClipboardShortcutRecording()
        cancelFileSaveShortcutRecording()
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
        paneViews[.permissions] = buildPermissionsPane()
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
        refreshFileSaveShortcutDisplay()
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
        version.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        version.textColor = SettingsPalette.secondaryText
        version.alignment = .center
        version.translatesAutoresizingMaskIntoConstraints = false
        sidebarVersionLabel = version

        let statusDot = NSView()
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 4
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        availabilityDotView = statusDot

        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        availabilityStatusLabel = statusLabel

        let statusRow = NSStackView(views: [statusDot, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 6

        let footerStack = NSStackView(views: [version, statusRow])
        footerStack.orientation = .vertical
        footerStack.alignment = .centerX
        footerStack.spacing = 7
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

            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),

            footerStack.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            footerStack.leadingAnchor.constraint(greaterThanOrEqualTo: panel.leadingAnchor, constant: 16),
            footerStack.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor, constant: -16),
            footerStack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -18),
        ])

        return panel
    }

    private func aboutVersionString() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return L10n.aboutVersion(short, build: build)
    }

    @objc private func tabClicked(_ sender: TabButton) {
        selectTab(sender.tab)
    }

    private func selectTab(_ tab: SettingsTab) {
        selectedTab = tab
        for btn in tabButtons {
            btn.isSelected = (btn.tab == tab)
        }
        detailTitleLabel?.stringValue = tab.description
        let hidesDetailHeader = tab == .about
        detailTitleLabel?.isHidden = hidesDetailHeader
        detailHeaderDivider?.isHidden = hidesDetailHeader
        if let withHeader = detailScrollWithHeaderConstraint,
           let withoutHeader = detailScrollWithoutHeaderConstraint {
            NSLayoutConstraint.deactivate([withHeader, withoutHeader])
            (hidesDetailHeader ? withoutHeader : withHeader).isActive = true
        }
        shortcutResetButton?.isHidden = tab != .shortcuts

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
            action: #selector(shortcutsResetClicked)
        )
        configureGeneralActionButton(resetButton)
        resetButton.isHidden = true
        panel.addSubview(resetButton)
        shortcutResetButton = resetButton

        let headerDivider = NSView()
        headerDivider.wantsLayer = true
        headerDivider.layer?.backgroundColor = SettingsPalette.separator.cgColor
        headerDivider.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(headerDivider)
        detailHeaderDivider = headerDivider

        let scroll = NSScrollView()
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

        let scrollWithHeader = scroll.topAnchor.constraint(equalTo: headerDivider.bottomAnchor)
        let scrollWithoutHeader = scroll.topAnchor.constraint(equalTo: panel.topAnchor)
        detailScrollWithHeaderConstraint = scrollWithHeader
        detailScrollWithoutHeaderConstraint = scrollWithoutHeader
        scrollWithHeader.isActive = true

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: panel.topAnchor, constant: 22),
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
            scroll.bottomAnchor.constraint(equalTo: panel.bottomAnchor),

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

        // Toggles card
        let togglesCard = generalCard()
        let togglesInner = verticalInnerStack()
        togglesCard.addSubview(togglesInner)
        pin(togglesInner, to: togglesCard, insets: NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))

        let menuBar = makeToggleRow(
            title: L10n.showMenuBarIcon,
            subtitle: nil,
            isOn: Defaults.showMenuBar,
            action: #selector(menuBarSwitchToggled(_:))
        )
        menuBarTitleLabel = menuBar.title
        menuBarSwitch = menuBar.toggle
        togglesInner.addArrangedSubview(menuBar.row)
        menuBar.row.widthAnchor.constraint(equalTo: togglesInner.widthAnchor).isActive = true
        togglesInner.addArrangedSubview(rowDivider())

        let login = makeToggleRow(
            title: L10n.launchAtLogin,
            subtitle: nil,
            isOn: LaunchAtLogin.isEnabled,
            action: #selector(launchAtLoginToggled(_:))
        )
        launchAtLoginTitleLabel = login.title
        launchAtLoginSwitch = login.toggle
        togglesInner.addArrangedSubview(login.row)
        login.row.widthAnchor.constraint(equalTo: togglesInner.widthAnchor).isActive = true

        stack.addArrangedSubview(togglesCard)
        togglesCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        buildWindowShadowCard(into: stack)

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

        let demo = makeToggleRow(
            title: L10n.demoMode,
            subtitle: L10n.demoModeHint,
            isOn: Defaults.demoMode,
            action: #selector(demoModeToggled(_:))
        )
        demoModeTitleLabel = demo.title
        demoModeSubtitleLabel = demo.subtitle
        demoModeSwitch = demo.toggle
        inner.addArrangedSubview(demo.row)
        demo.row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    /// Window-capture shadow setting with an on-demand preview popover.
    private func buildWindowShadowCard(into stack: NSStackView) {
        let card = generalCard()
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 0
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        pin(inner, to: card, insets: NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))

        let optionRow = NSStackView()
        optionRow.orientation = .horizontal
        optionRow.alignment = .centerY
        optionRow.spacing = 10
        optionRow.translatesAutoresizingMaskIntoConstraints = false

        let labelStack = NSStackView()
        labelStack.orientation = .vertical
        labelStack.alignment = .leading
        labelStack.spacing = 3

        windowShadowTitleLabel = primaryLabel(L10n.windowShadowLabel)
        windowShadowSubtitleLabel = secondaryLabel(L10n.windowShadowHint, wrapping: true)
        labelStack.addArrangedSubview(windowShadowTitleLabel)
        if let windowShadowSubtitleLabel {
            labelStack.addArrangedSubview(windowShadowSubtitleLabel)
        }
        optionRow.addArrangedSubview(labelStack)
        labelStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        optionRow.addArrangedSubview(flexSpacer())

        windowShadowPreviewButton = SettingsActionButton(
            title: L10n.windowShadowPreviewButton,
            target: self,
            action: #selector(windowShadowPreviewClicked(_:))
        )
        configureGeneralActionButton(windowShadowPreviewButton)
        optionRow.addArrangedSubview(windowShadowPreviewButton)

        windowShadowPicker = SettingsPopUpButton(frame: .zero, pullsDown: false)
        windowShadowPicker.controlSize = .small
        windowShadowPicker.font = NSFont.systemFont(ofSize: 12)
        windowShadowPicker.target = self
        windowShadowPicker.action = #selector(windowShadowLevelChanged(_:))
        constrainGeneralPopupWidth(windowShadowPicker)
        optionRow.addArrangedSubview(windowShadowPicker)
        constrainSettingsRowHeight(optionRow)

        inner.addArrangedSubview(optionRow)
        optionRow.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        refreshWindowShadowControls()

        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func refreshWindowShadowControls() {
        let level = Defaults.windowShadowLevel
        windowShadowPicker?.removeAllItems()
        for option in WindowShadowLevel.allCases {
            windowShadowPicker?.addItem(withTitle: option.localizedTitle)
            windowShadowPicker?.lastItem?.representedObject = option.rawValue
        }
        if let index = WindowShadowLevel.allCases.firstIndex(of: level) {
            windowShadowPicker?.selectItem(at: index)
        }
        windowShadowPreview?.shadowSize = CGFloat(level.shadowSize)
        windowShadowPreview?.isEffectEnabled = level.isEnabled
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
            setAction: #selector(shortcutSetClicked),
            restoreAction: #selector(shortcutRestoreClicked)
        )
        shortcutTitleLabel = shortcut.title
        shortcutField = shortcut.field
        shortcutSetButton = shortcut.setButton
        shortcutRestoreButton = shortcut.restoreButton
        stack.addArrangedSubview(shortcut.card)
        shortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Copy-to-clipboard (editor confirm) shortcut card
        let clipboardShortcut = buildShortcutCard(
            title: L10n.clipboardShortcutHeader,
            setAction: #selector(clipboardShortcutSetClicked),
            restoreAction: #selector(clipboardShortcutRestoreClicked)
        )
        clipboardShortcutTitleLabel = clipboardShortcut.title
        clipboardShortcutField = clipboardShortcut.field
        clipboardShortcutSetButton = clipboardShortcut.setButton
        clipboardShortcutRestoreButton = clipboardShortcut.restoreButton
        stack.addArrangedSubview(clipboardShortcut.card)
        clipboardShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Save-to-file shortcut card (default ⌘S)
        let fileSaveShortcut = buildShortcutCard(
            title: L10n.fileSaveShortcutHeader,
            setAction: #selector(fileSaveShortcutSetClicked),
            restoreAction: #selector(fileSaveShortcutRestoreClicked)
        )
        fileSaveShortcutTitleLabel = fileSaveShortcut.title
        fileSaveShortcutField = fileSaveShortcut.field
        fileSaveShortcutSetButton = fileSaveShortcut.setButton
        fileSaveShortcutRestoreButton = fileSaveShortcut.restoreButton
        stack.addArrangedSubview(fileSaveShortcut.card)
        fileSaveShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Edit selected image shortcut card
        let selectedImageEditShortcut = buildShortcutCard(
            title: L10n.selectedImageEditShortcutHeader,
            setAction: #selector(selectedImageEditShortcutSetClicked),
            restoreAction: #selector(selectedImageEditShortcutRestoreClicked)
        )
        selectedImageEditShortcutTitleLabel = selectedImageEditShortcut.title
        selectedImageEditShortcutField = selectedImageEditShortcut.field
        selectedImageEditShortcutSetButton = selectedImageEditShortcut.setButton
        selectedImageEditShortcutRestoreButton = selectedImageEditShortcut.restoreButton
        stack.addArrangedSubview(selectedImageEditShortcut.card)
        selectedImageEditShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Edit clipboard image shortcut card
        let clipboardImageEditShortcut = buildShortcutCard(
            title: L10n.clipboardImageEditShortcutHeader,
            setAction: #selector(clipboardImageEditShortcutSetClicked),
            restoreAction: #selector(clipboardImageEditShortcutRestoreClicked)
        )
        clipboardImageEditShortcutTitleLabel = clipboardImageEditShortcut.title
        clipboardImageEditShortcutField = clipboardImageEditShortcut.field
        clipboardImageEditShortcutSetButton = clipboardImageEditShortcut.setButton
        clipboardImageEditShortcutRestoreButton = clipboardImageEditShortcut.restoreButton
        stack.addArrangedSubview(clipboardImageEditShortcut.card)
        clipboardImageEditShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Pin selected image shortcut card
        let selectedImagePinShortcut = buildShortcutCard(
            title: L10n.selectedImagePinShortcutHeader,
            setAction: #selector(selectedImagePinShortcutSetClicked),
            restoreAction: #selector(selectedImagePinShortcutRestoreClicked)
        )
        selectedImagePinShortcutTitleLabel = selectedImagePinShortcut.title
        selectedImagePinShortcutField = selectedImagePinShortcut.field
        selectedImagePinShortcutSetButton = selectedImagePinShortcut.setButton
        selectedImagePinShortcutRestoreButton = selectedImagePinShortcut.restoreButton
        selectedImagePinShortcutRestoreButton.toolTip = L10n.selectedImagePinShortcutClear
        stack.addArrangedSubview(selectedImagePinShortcut.card)
        selectedImagePinShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Pin clipboard image shortcut card
        let clipboardImagePinShortcut = buildShortcutCard(
            title: L10n.clipboardImagePinShortcutHeader,
            setAction: #selector(clipboardImagePinShortcutSetClicked),
            restoreAction: #selector(clipboardImagePinShortcutRestoreClicked)
        )
        clipboardImagePinShortcutTitleLabel = clipboardImagePinShortcut.title
        clipboardImagePinShortcutField = clipboardImagePinShortcut.field
        clipboardImagePinShortcutSetButton = clipboardImagePinShortcut.setButton
        clipboardImagePinShortcutRestoreButton = clipboardImagePinShortcut.restoreButton
        clipboardImagePinShortcutRestoreButton.toolTip = L10n.clipboardImagePinShortcutClear
        stack.addArrangedSubview(clipboardImagePinShortcut.card)
        clipboardImagePinShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Recording shortcut card
        let recordShortcut = buildShortcutCard(
            title: L10n.recordShortcutHeader,
            setAction: #selector(recordShortcutSetClicked),
            restoreAction: #selector(recordShortcutRestoreClicked)
        )
        recordShortcutTitleLabel = recordShortcut.title
        recordShortcutField = recordShortcut.field
        recordShortcutSetButton = recordShortcut.setButton
        recordShortcutRestoreButton = recordShortcut.restoreButton
        stack.addArrangedSubview(recordShortcut.card)
        recordShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Image Merge shortcut card
        let imageMergeShortcut = buildShortcutCard(
            title: L10n.imageMergeShortcutHeader,
            setAction: #selector(imageMergeShortcutSetClicked),
            restoreAction: #selector(imageMergeShortcutRestoreClicked)
        )
        imageMergeShortcutTitleLabel = imageMergeShortcut.title
        imageMergeShortcutField = imageMergeShortcut.field
        imageMergeShortcutSetButton = imageMergeShortcut.setButton
        imageMergeShortcutRestoreButton = imageMergeShortcut.restoreButton
        stack.addArrangedSubview(imageMergeShortcut.card)
        imageMergeShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Pin clipboard text shortcut card
        let clipboardTextPinShortcut = buildShortcutCard(
            title: L10n.clipboardTextPinShortcutHeader,
            setAction: #selector(clipboardTextPinShortcutSetClicked),
            restoreAction: #selector(clipboardTextPinShortcutRestoreClicked)
        )
        clipboardTextPinShortcutTitleLabel = clipboardTextPinShortcut.title
        clipboardTextPinShortcutField = clipboardTextPinShortcut.field
        clipboardTextPinShortcutSetButton = clipboardTextPinShortcut.setButton
        clipboardTextPinShortcutRestoreButton = clipboardTextPinShortcut.restoreButton
        clipboardTextPinShortcutRestoreButton.toolTip = L10n.clipboardTextPinShortcutClear
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

        let chooseButton = SettingsActionButton(
            title: L10n.savePathChoose,
            target: self,
            action: chooseAction
        )
        configureGeneralActionButton(chooseButton)
        row.addArrangedSubview(chooseButton)

        let revealButton = SettingsActionButton(
            title: L10n.savePathReveal,
            target: self,
            action: revealAction
        )
        configureGeneralActionButton(revealButton)
        row.addArrangedSubview(revealButton)
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
    }

    private func preferredGeneralPopupWidth() -> CGFloat {
        let titles = AppLanguage.allCases.map(\.displayName)
            + WindowShadowLevel.allCases.map(\.localizedTitle)
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

    private func buildToolbarPane() -> NSView {
        let host = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        let pane = ToolbarSettingsPane()
        host.addSubview(pane)
        NSLayoutConstraint.activate([
            pane.topAnchor.constraint(equalTo: host.topAnchor),
            pane.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            pane.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            pane.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
        return host
    }

    private func buildPermissionsPane() -> NSView {
        let stack = paneStack(spacing: 0)

        let permCard = generalCard()
        let permInner = verticalInnerStack()
        permCard.addSubview(permInner)
        pin(
            permInner,
            to: permCard,
            insets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        )

        let acc = makePermissionRow(
            name: L10n.accessibilityPermission,
            description: L10n.accessibilityDescription,
            action: #selector(openAccessibilitySettings(_:))
        )
        accessibilityNameLabel = acc.name
        accessibilityDescLabel = acc.desc
        accessibilityBadge = acc.badge
        permInner.addArrangedSubview(acc.row)
        acc.row.widthAnchor.constraint(equalTo: permInner.widthAnchor).isActive = true
        permInner.addArrangedSubview(rowDivider())

        let sc = makePermissionRow(
            name: L10n.screenRecordingPermission,
            description: L10n.screenRecordingDescription,
            action: #selector(openScreenRecordingSettings(_:))
        )
        screenRecordingNameLabel = sc.name
        screenRecordingDescLabel = sc.desc
        screenRecordingBadge = sc.badge
        permInner.addArrangedSubview(sc.row)
        sc.row.widthAnchor.constraint(equalTo: permInner.widthAnchor).isActive = true

        stack.addArrangedSubview(permCard)
        permCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        return wrapPane(stack, topInset: 0)
    }

    private func buildAboutPane() -> NSView {
        let stack = paneStack(spacing: 0)
        stack.alignment = .centerX

        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 22
        iconView.layer?.cornerCurve = .continuous
        iconView.layer?.masksToBounds = true
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 96),
            iconView.heightAnchor.constraint(equalToConstant: 96),
        ])

        let nameLabel = NSTextField(labelWithString: "aulycShot")
        nameLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        nameLabel.textColor = SettingsPalette.primaryText
        nameLabel.alignment = .center

        let versionLabel = NSTextField(labelWithString: aboutVersionString())
        versionLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        versionLabel.textColor = SettingsPalette.secondaryText
        versionLabel.alignment = .center
        aboutVersionLabel = versionLabel

        let identityStack = NSStackView(views: [iconView, nameLabel, versionLabel])
        identityStack.orientation = .vertical
        identityStack.alignment = .centerX
        identityStack.spacing = 8
        identityStack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(identityStack)

        let identityGap = NSView()
        identityGap.translatesAutoresizingMaskIntoConstraints = false
        identityGap.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stack.addArrangedSubview(identityGap)

        let links = verticalInnerStack()
        links.spacing = 8
        links.translatesAutoresizingMaskIntoConstraints = false
        links.widthAnchor.constraint(equalToConstant: Self.aboutListWidth).isActive = true
        stack.addArrangedSubview(links)

        let updateRow = makeUpdateRow()
        links.addArrangedSubview(updateRow)
        updateRow.widthAnchor.constraint(equalTo: links.widthAnchor).isActive = true

        let license = makeAboutActionRow(
            title: L10n.aboutLicense,
            symbolName: "doc.text",
            action: #selector(openLicense)
        )
        aboutLicenseTitleLabel = license.title
        links.addArrangedSubview(license.row)
        license.row.widthAnchor.constraint(equalTo: links.widthAnchor).isActive = true

        let repo = makeAboutActionRow(
            title: L10n.aboutSourceCode,
            symbolName: "chevron.left.forwardslash.chevron.right",
            action: #selector(openSourceRepo)
        )
        aboutSourceTitleLabel = repo.title
        links.addArrangedSubview(repo.row)
        repo.row.widthAnchor.constraint(equalTo: links.widthAnchor).isActive = true

        let star = makeAboutActionRow(
            title: L10n.aboutStarOnGitHub,
            symbolName: "star",
            action: #selector(openStarOnGitHub)
        )
        aboutStarTitleLabel = star.title
        links.addArrangedSubview(star.row)
        star.row.widthAnchor.constraint(equalTo: links.widthAnchor).isActive = true

        let featureRequest = makeAboutActionRow(
            title: L10n.aboutFeatureRequest,
            symbolName: "lightbulb",
            action: #selector(openFeatureRequest)
        )
        aboutFeatureRequestTitleLabel = featureRequest.title
        links.addArrangedSubview(featureRequest.row)
        featureRequest.row.widthAnchor.constraint(equalTo: links.widthAnchor).isActive = true

        let bugReport = makeAboutActionRow(
            title: L10n.aboutBugReport,
            symbolName: "ladybug",
            action: #selector(openBugReport)
        )
        aboutBugReportTitleLabel = bugReport.title
        links.addArrangedSubview(bugReport.row)
        bugReport.row.widthAnchor.constraint(equalTo: links.widthAnchor).isActive = true

        let errorLog = makeAboutActionRow(
            title: L10n.aboutErrorLog,
            symbolName: "doc.text.magnifyingglass",
            action: #selector(showErrorLogWindow)
        )
        errorLogTitleLabel = errorLog.title
        links.addArrangedSubview(errorLog.row)
        errorLog.row.widthAnchor.constraint(equalTo: links.widthAnchor).isActive = true

        return wrapAboutPane(stack)
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

    /// Compact icon-and-label link matching the centered aulycMail About page.
    private func makeAboutActionRow(
        title: String,
        symbolName: String,
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
            link.cornerRadius = 6
            link.showsHoverBackground = false
            link.setAccessibilityLabel(title)
            row = link
            button = link
        } else {
            let staticRow = NSView()
            staticRow.translatesAutoresizingMaskIntoConstraints = false
            row = staticRow
            button = nil
        }
        row.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "circle", accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        icon.contentTintColor = SettingsPalette.accent
        icon.imageScaling = .scaleProportionallyDown
        icon.setAccessibilityElement(false)
        icon.setAccessibilityHidden(true)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = SettingsPalette.accent
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = SettingsPalette.secondaryText
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.isHidden = detail.isEmpty

        let contentStack = NSStackView(views: [icon, titleLabel, detailLabel])
        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(contentStack)
        button?.interactiveContentView = contentStack
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: Self.aboutLinkRowHeight),
            contentStack.centerXAnchor.constraint(equalTo: row.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: row.leadingAnchor, constant: 10),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -10),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
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
            symbolName: "arrow.triangle.2.circlepath",
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

    private func wrapAboutPane(_ stack: NSStackView) -> NSView {
        let host = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: host.topAnchor, constant: 36),
            stack.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: host.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: host.trailingAnchor, constant: -28),
            stack.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -28),
        ])
        return host
    }

    // MARK: - Builders

    private static let settingsRowMinimumHeight: CGFloat = 52
    private static let aboutListWidth: CGFloat = 440
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
        let restoreButton: NSButton
    }

    private func buildShortcutCard(
        title: String,
        setAction: Selector,
        restoreAction: Selector
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

        let restoreButton = SettingsActionButton(
            image: NSImage(
                systemSymbolName: "arrow.counterclockwise.circle.fill",
                accessibilityDescription: L10n.shortcutRestore
            ) ?? NSImage(),
            target: self,
            action: restoreAction
        )
        restoreButton.imagePosition = .imageOnly
        restoreButton.contentTintColor = NSColor.white.withAlphaComponent(0.62)
        restoreButton.toolTip = L10n.shortcutRestore
        configureGeneralActionButton(restoreButton)
        restoreButton.widthAnchor.constraint(equalToConstant: 34).isActive = true
        row.addArrangedSubview(restoreButton)

        inner.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true
        constrainSettingsRowHeight(row)

        return ShortcutCardBuild(
            card: card,
            title: titleLabel,
            field: field,
            setButton: setButton,
            restoreButton: restoreButton
        )
    }

    private struct ToggleRowBuild {
        let row: NSView
        let title: NSTextField
        let subtitle: NSTextField?
        let toggle: NSSwitch
    }

    private func makeToggleRow(
        title: String,
        subtitle: String?,
        isOn: Bool,
        action: Selector
    ) -> ToggleRowBuild {
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

        let sw = NSSwitch()
        sw.state = isOn ? .on : .off
        sw.target = self
        sw.action = action
        sw.controlSize = .small
        sw.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(textStack)
        row.addSubview(sw)

        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            textStack.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -10),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: sw.leadingAnchor, constant: -12),

            sw.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            sw.centerYAnchor.constraint(equalTo: textStack.centerYAnchor),
        ])
        constrainSettingsRowHeight(row)

        return ToggleRowBuild(row: row, title: titleLabel, subtitle: subtitleLabel, toggle: sw)
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

    private struct PermissionRowBuild {
        let row: NSView
        let name: NSTextField
        let desc: NSTextField
        let badge: StatusBadge
    }

    private func makePermissionRow(
        name: String,
        description: String,
        action: Selector
    ) -> PermissionRowBuild {
        let button = HoverButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = action
        button.title = ""
        button.isBordered = false
        button.cornerRadius = 10

        let nameLbl = primaryLabel(name)
        nameLbl.translatesAutoresizingMaskIntoConstraints = false

        let badge = StatusBadge()
        badge.translatesAutoresizingMaskIntoConstraints = false

        let topLine = NSStackView(views: [nameLbl, badge])
        topLine.orientation = .horizontal
        topLine.alignment = .centerY
        topLine.spacing = 8
        topLine.translatesAutoresizingMaskIntoConstraints = false

        let descLbl = secondaryLabel(description, wrapping: true)
        descLbl.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(topLine)
        textStack.addArrangedSubview(descLbl)

        let chevron = NSTextField(labelWithString: "\u{203A}")
        chevron.font = NSFont.systemFont(ofSize: 18, weight: .regular)
        chevron.textColor = NSColor.white.withAlphaComponent(0.32)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        button.addSubview(textStack)
        button.addSubview(chevron)
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: button.topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -10),
            textStack.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -10),

            chevron.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
        ])
        constrainSettingsRowHeight(button)

        return PermissionRowBuild(row: button, name: nameLbl, desc: descLbl, badge: badge)
    }

    func showPermissionsTab() {
        selectTab(.permissions)
    }

    // MARK: - Permission polling

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshPermissionStatus()
        }
    }

    func refreshPermissionStatus() {
        let accessibilityGranted = AppPermissions.accessibilityGranted
        let screenRecordingGranted = AppPermissions.screenRecordingGranted

        accessibilityBadge?.configure(granted: accessibilityGranted)
        screenRecordingBadge?.configure(granted: screenRecordingGranted)
        refreshAvailabilityStatus()
    }

    private func refreshAvailabilityStatus() {
        let color: NSColor
        let title: String
        switch AppPermissions.availabilityState {
        case .unavailable:
            color = .systemRed
            title = L10n.appStatusUnavailable
        case .partiallyAvailable:
            color = .systemYellow
            title = L10n.appStatusPartiallyAvailable
        case .normallyAvailable:
            color = .systemGreen
            title = L10n.appStatusNormallyAvailable
        }

        availabilityDotView?.layer?.backgroundColor = color.cgColor
        availabilityStatusLabel?.stringValue = title
        availabilityStatusLabel?.textColor = color
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

    @objc private func windowShadowPreviewClicked(_ sender: NSButton) {
        if let popover = windowShadowPreviewPopover, popover.isShown {
            popover.performClose(sender)
            return
        }

        let contentSize = NSSize(width: 520, height: 166)
        let contentView = NSView(frame: NSRect(origin: .zero, size: contentSize))

        let preview = ShadowPreviewView()
        preview.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(preview)

        let hintLabel = secondaryLabel(L10n.windowShadowLevelHint, wrapping: true)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            preview.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            preview.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            preview.heightAnchor.constraint(equalToConstant: 120),

            hintLabel.topAnchor.constraint(equalTo: preview.bottomAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            hintLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            hintLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10),
        ])

        let contentController = NSViewController()
        contentController.view = contentView

        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.animates = true
        popover.contentSize = contentSize
        popover.contentViewController = contentController

        windowShadowPreview = preview
        windowShadowLevelHintLabel = hintLabel
        windowShadowPreviewPopover = popover
        refreshWindowShadowControls()

        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    @objc private func windowShadowLevelChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let level = WindowShadowLevel(rawValue: rawValue)
        else {
            return
        }
        Defaults.windowShadowLevel = level
        refreshWindowShadowControls()
    }

    @objc private func launchAtLoginToggled(_ sender: NSSwitch) {
        let enable = sender.state == .on
        let ok = LaunchAtLogin.setEnabled(enable)
        if !ok {
            sender.state = LaunchAtLogin.isEnabled ? .on : .off
        }
    }

    @objc private func demoModeToggled(_ sender: NSSwitch) {
        Defaults.demoMode = sender.state == .on
    }

    @objc private func menuBarSwitchToggled(_ sender: NSSwitch) {
        let visible = sender.state == .on
        Defaults.showMenuBar = visible
        onMenuBarToggle?(visible)
    }

    @objc private func openAccessibilitySettings(_ sender: NSButton) {
        startPermissionFlow(.accessibility, from: sender)
    }

    @objc private func openScreenRecordingSettings(_ sender: NSButton) {
        startPermissionFlow(.screenRecording, from: sender)
    }

    private func startPermissionFlow(_ permission: RequiredPermission, from sourceView: NSView) {
        if let onPermissionSettingsRequest {
            onPermissionSettingsRequest(permission, sourceView)
            return
        }

        permissionFlowController.setLocaleIdentifier(Defaults.language.lprojName)
        permissionFlowController.authorize(
            pane: permission.flowPane,
            suggestedAppURLs: [Bundle.main.bundleURL],
            sourceFrameInScreen: sourceFrameInScreen(for: sourceView)
        )
    }

    private func sourceFrameInScreen(for view: NSView) -> CGRect? {
        guard let window = view.window else { return nil }
        let frameInWindow = view.convert(view.bounds, to: nil)
        return window.convertToScreen(frameInWindow)
    }

    func closePermissionFlowPanel() {
        permissionFlowController.closePanel()
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
        if slot != .fileSave, fileSaveShortcutRecordingMonitor != nil {
            cancelFileSaveShortcutRecording()
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
        shortcutRestoreButton.isHidden = true

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

    @objc private func shortcutRestoreClicked() {
        if shortcutRecordingMonitor != nil {
            cancelShortcutRecording()
        }
        Defaults.clearScreenshotHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshShortcutDisplay()
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
            shortcutRestoreButton?.isHidden = false
        } else {
            shortcutField?.stringValue = L10n.shortcutDefaultDisplay
            shortcutRestoreButton?.isHidden = true
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
        selectedImagePinShortcutRestoreButton.isHidden = true

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

    @objc private func selectedImagePinShortcutRestoreClicked() {
        if selectedImagePinShortcutRecordingMonitor != nil {
            cancelSelectedImagePinShortcutRecording()
        }
        Defaults.clearSelectedImagePinHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshSelectedImagePinShortcutDisplay()
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
            selectedImagePinShortcutRestoreButton?.isHidden = false
        } else {
            selectedImagePinShortcutField?.stringValue = L10n.selectedImagePinShortcutDefaultDisplay
            selectedImagePinShortcutRestoreButton?.isHidden = true
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
        clipboardImagePinShortcutRestoreButton.isHidden = true

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

    @objc private func clipboardImagePinShortcutRestoreClicked() {
        if clipboardImagePinShortcutRecordingMonitor != nil {
            cancelClipboardImagePinShortcutRecording()
        }
        Defaults.clearClipboardImagePinHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshClipboardImagePinShortcutDisplay()
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
            clipboardImagePinShortcutRestoreButton?.isHidden = false
        } else {
            clipboardImagePinShortcutField?.stringValue = L10n.clipboardImagePinShortcutDefaultDisplay
            clipboardImagePinShortcutRestoreButton?.isHidden = true
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
        clipboardTextPinShortcutRestoreButton.isHidden = true

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

    @objc private func clipboardTextPinShortcutRestoreClicked() {
        if clipboardTextPinShortcutRecordingMonitor != nil {
            cancelClipboardTextPinShortcutRecording()
        }
        Defaults.clearClipboardTextPinHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshClipboardTextPinShortcutDisplay()
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
            clipboardTextPinShortcutRestoreButton?.isHidden = false
        } else {
            clipboardTextPinShortcutField?.stringValue = L10n.clipboardTextPinShortcutDefaultDisplay
            clipboardTextPinShortcutRestoreButton?.isHidden = true
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
        selectedImageEditShortcutRestoreButton.isHidden = true

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

    @objc private func selectedImageEditShortcutRestoreClicked() {
        if selectedImageEditShortcutRecordingMonitor != nil {
            cancelSelectedImageEditShortcutRecording()
        }
        Defaults.clearSelectedImageEditHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshSelectedImageEditShortcutDisplay()
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
            selectedImageEditShortcutRestoreButton?.isHidden = false
        } else {
            selectedImageEditShortcutField?.stringValue = L10n.selectedImageEditShortcutDefaultDisplay
            selectedImageEditShortcutRestoreButton?.isHidden = true
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
        clipboardImageEditShortcutRestoreButton.isHidden = true

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

    @objc private func clipboardImageEditShortcutRestoreClicked() {
        if clipboardImageEditShortcutRecordingMonitor != nil {
            cancelClipboardImageEditShortcutRecording()
        }
        Defaults.clearClipboardImageEditHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshClipboardImageEditShortcutDisplay()
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
            clipboardImageEditShortcutRestoreButton?.isHidden = false
        } else {
            clipboardImageEditShortcutField?.stringValue = L10n.clipboardImageEditShortcutDefaultDisplay
            clipboardImageEditShortcutRestoreButton?.isHidden = true
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
        recordShortcutRestoreButton.isHidden = true

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

    @objc private func recordShortcutRestoreClicked() {
        if recordShortcutRecordingMonitor != nil {
            cancelRecordShortcutRecording()
        }
        Defaults.clearRecordHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshRecordShortcutDisplay()
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
            recordShortcutRestoreButton?.isHidden = false
        } else {
            recordShortcutField?.stringValue = L10n.recordShortcutDefaultDisplay
            recordShortcutRestoreButton?.isHidden = true
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
        imageMergeShortcutRestoreButton.isHidden = true

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

    @objc private func imageMergeShortcutRestoreClicked() {
        if imageMergeShortcutRecordingMonitor != nil {
            cancelImageMergeShortcutRecording()
        }
        Defaults.clearImageMergeHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshImageMergeShortcutDisplay()
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
            imageMergeShortcutRestoreButton?.isHidden = false
        } else {
            imageMergeShortcutField?.stringValue = L10n.imageMergeShortcutDefaultDisplay
            imageMergeShortcutRestoreButton?.isHidden = true
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
        clipboardShortcutRestoreButton.isHidden = true

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

    @objc private func clipboardShortcutRestoreClicked() {
        if clipboardShortcutRecordingMonitor != nil {
            cancelClipboardShortcutRecording()
        }
        Defaults.clearClipboardHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshClipboardShortcutDisplay()
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
            clipboardShortcutRestoreButton?.isHidden = false
        } else {
            clipboardShortcutField?.stringValue = L10n.clipboardShortcutDefaultDisplay
            clipboardShortcutRestoreButton?.isHidden = true
        }
    }

    @objc private func fileSaveShortcutSetClicked() {
        if fileSaveShortcutRecordingMonitor != nil {
            cancelFileSaveShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .fileSave)
        HotkeyManager.shared.beginRecording()
        fileSaveShortcutSetButton.title = L10n.shortcutCancel
        fileSaveShortcutField.stringValue = L10n.shortcutWaiting
        fileSaveShortcutRestoreButton.isHidden = true

        fileSaveShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelFileSaveShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .fileSave) {
                self.cancelFileSaveShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.fileSaveHotkeyKeyCode = Int(keyCode)
            Defaults.fileSaveHotkeyModifiers = Int(carbonMods)
            self.finishFileSaveShortcutRecording()
            return nil
        }
    }

    @objc private func fileSaveShortcutRestoreClicked() {
        if fileSaveShortcutRecordingMonitor != nil {
            cancelFileSaveShortcutRecording()
        }
        Defaults.clearFileSaveHotkey()
        refreshFileSaveShortcutDisplay()
    }

    private func finishFileSaveShortcutRecording() {
        if let m = fileSaveShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            fileSaveShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshFileSaveShortcutDisplay()
    }

    func cancelFileSaveShortcutRecording() {
        guard fileSaveShortcutRecordingMonitor != nil else { return }
        if let m = fileSaveShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            fileSaveShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshFileSaveShortcutDisplay()
    }

    private func refreshFileSaveShortcutDisplay() {
        fileSaveShortcutSetButton?.title = L10n.shortcutSet
        fileSaveShortcutField?.stringValue = HotkeyManager.currentFileSaveDisplayString()
        fileSaveShortcutRestoreButton?.isHidden = !Defaults.hasCustomFileSaveHotkey
    }

    @objc private func shortcutsResetClicked() {
        cancelShortcutRecording()
        cancelSelectedImagePinShortcutRecording()
        cancelClipboardImagePinShortcutRecording()
        cancelClipboardTextPinShortcutRecording()
        cancelSelectedImageEditShortcutRecording()
        cancelClipboardImageEditShortcutRecording()
        cancelRecordShortcutRecording()
        cancelImageMergeShortcutRecording()
        cancelClipboardShortcutRecording()
        cancelFileSaveShortcutRecording()
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
        refreshFileSaveShortcutDisplay()
    }

    @objc private func updateLocalization() {
        permissionFlowController.setLocaleIdentifier(Defaults.language.lprojName)
        menuBarTitleLabel?.stringValue = L10n.showMenuBarIcon
        launchAtLoginTitleLabel?.stringValue = L10n.launchAtLogin
        demoModeTitleLabel?.stringValue = L10n.demoMode
        demoModeSubtitleLabel?.stringValue = L10n.demoModeHint
        langTitleLabel?.stringValue = L10n.languageHeader
        windowShadowPreviewButton?.title = L10n.windowShadowPreviewButton
        screenshotOutputActionTitleLabel?.stringValue = L10n.screenshotOutputActionLabel
        refreshScreenshotOutputControls()
        screenshotQualityTitleLabel?.stringValue = L10n.screenshotQualityLabel
        refreshScreenshotQualityControls()
        recordingSavePathTitleLabel?.stringValue = L10n.recordingSavePathLabel
        recordingSaveFormatTitleLabel?.stringValue = L10n.recordingSaveFormatSettingLabel
        screenshotSavePathTitleLabel?.stringValue = L10n.screenshotSavePathLabel
        recordingSavePathChooseButton?.title = L10n.savePathChoose
        recordingSavePathRevealButton?.title = L10n.savePathReveal
        screenshotSavePathChooseButton?.title = L10n.savePathChoose
        screenshotSavePathRevealButton?.title = L10n.savePathReveal
        refreshSavePathControls()
        accessibilityNameLabel?.stringValue = L10n.accessibilityPermission
        accessibilityDescLabel?.stringValue = L10n.accessibilityDescription
        screenRecordingNameLabel?.stringValue = L10n.screenRecordingPermission
        screenRecordingDescLabel?.stringValue = L10n.screenRecordingDescription
        windowShadowTitleLabel?.stringValue = L10n.windowShadowLabel
        windowShadowSubtitleLabel?.stringValue = L10n.windowShadowHint
        windowShadowLevelHintLabel?.stringValue = L10n.windowShadowLevelHint
        refreshWindowShadowControls()
        refreshGeneralPopupWidths()
        shortcutTitleLabel?.stringValue = L10n.shortcutHeader
        shortcutRestoreButton?.toolTip = L10n.shortcutRestore
        selectedImagePinShortcutTitleLabel?.stringValue = L10n.selectedImagePinShortcutHeader
        selectedImagePinShortcutRestoreButton?.toolTip = L10n.selectedImagePinShortcutClear
        clipboardImagePinShortcutTitleLabel?.stringValue = L10n.clipboardImagePinShortcutHeader
        clipboardImagePinShortcutRestoreButton?.toolTip = L10n.clipboardImagePinShortcutClear
        clipboardTextPinShortcutTitleLabel?.stringValue = L10n.clipboardTextPinShortcutHeader
        clipboardTextPinShortcutRestoreButton?.toolTip = L10n.clipboardTextPinShortcutClear
        selectedImageEditShortcutTitleLabel?.stringValue = L10n.selectedImageEditShortcutHeader
        selectedImageEditShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        clipboardImageEditShortcutTitleLabel?.stringValue = L10n.clipboardImageEditShortcutHeader
        clipboardImageEditShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        recordShortcutTitleLabel?.stringValue = L10n.recordShortcutHeader
        recordShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        imageMergeShortcutTitleLabel?.stringValue = L10n.imageMergeShortcutHeader
        imageMergeShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        clipboardShortcutTitleLabel?.stringValue = L10n.clipboardShortcutHeader
        clipboardShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        fileSaveShortcutTitleLabel?.stringValue = L10n.fileSaveShortcutHeader
        fileSaveShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        shortcutResetButton?.title = L10n.toolbarSettingsReset
        aboutVersionLabel?.stringValue = aboutVersionString()
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
        refreshFileSaveShortcutDisplay()
        refreshAvailabilityStatus()
        accessibilityBadge?.refreshTitle()
        screenRecordingBadge?.refreshTitle()
        for btn in tabButtons { btn.refreshTitle() }
        sidebarTitleLabel?.stringValue = L10n.settings
        sidebarVersionLabel?.stringValue = aboutVersionString()
        detailTitleLabel?.stringValue = selectedTab.description
        window?.title = L10n.settingsTitle
    }
}

enum SettingsPalette {
    static let accent = NSColor(calibratedRed: 0.34, green: 0.78, blue: 0.84, alpha: 1.0)
    static let sidebarBackground = NSColor(calibratedWhite: 0.155, alpha: 1.0)
    static let contentBackground = NSColor(calibratedWhite: 0.115, alpha: 1.0)
    static let primaryText = NSColor.white.withAlphaComponent(0.94)
    static let secondaryText = NSColor.white.withAlphaComponent(0.62)
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

/// Live preview of the window-capture shadow: a small window-like card
/// floating on a desktop-like backdrop. The shadow scales with `shadowSize`
/// so the user sees how high the captured window will appear to float.
private final class ShadowPreviewView: NSView {
    var shadowSize: CGFloat = 22 { didSet { needsDisplay = true } }
    var isEffectEnabled: Bool = true { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let backdrop = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        backdrop.addClip()

        // Desktop-like light backdrop so the dark shadow stays visible
        // (the settings UI itself is dark).
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.74, green: 0.78, blue: 0.85, alpha: 1),
            NSColor(calibratedRed: 0.60, green: 0.64, blue: 0.72, alpha: 1)
        ])
        gradient?.draw(in: bounds, angle: -90)

        // Window card geometry, centered; floats higher as the shadow grows.
        let cardW = min(bounds.width * 0.56, 210)
        let cardH: CGFloat = 64
        let lift = isEffectEnabled ? min(shadowSize, 60) * 0.10 : 0
        let cardRect = NSRect(
            x: ((bounds.width - cardW) / 2).rounded(),
            y: ((bounds.height - cardH) / 2 + lift).rounded(),
            width: cardW,
            height: cardH
        )
        let radius: CGFloat = 9
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: radius, yRadius: radius)

        guard let ctx = NSGraphicsContext.current else { return }

        // Shadow pass. Scaled down relative to the real export — the preview
        // card is tiny — but proportional, so the slider's effect reads.
        ctx.saveGraphicsState()
        if isEffectEnabled, shadowSize > 0 {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.42)
            shadow.shadowBlurRadius = shadowSize * 0.62
            shadow.shadowOffset = NSSize(width: 0, height: -shadowSize * 0.30)
            shadow.set()
        }
        NSColor.white.setFill()
        cardPath.fill()
        ctx.restoreGraphicsState()

        // Title-bar strip + traffic-light dots, clipped to the card.
        ctx.saveGraphicsState()
        cardPath.addClip()
        NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(
            x: cardRect.minX, y: cardRect.maxY - 16,
            width: cardRect.width, height: 16
        )).fill()
        let dotColors: [NSColor] = [
            NSColor(calibratedRed: 1.00, green: 0.37, blue: 0.35, alpha: 1),
            NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.18, alpha: 1),
            NSColor(calibratedRed: 0.31, green: 0.79, blue: 0.31, alpha: 1)
        ]
        for (i, color) in dotColors.enumerated() {
            color.setFill()
            let d: CGFloat = 7
            NSBezierPath(ovalIn: NSRect(
                x: cardRect.minX + 9 + CGFloat(i) * 12,
                y: cardRect.maxY - 11.5, width: d, height: d
            )).fill()
        }
        ctx.restoreGraphicsState()

        // Hairline border for crispness.
        NSColor.black.withAlphaComponent(0.08).setStroke()
        cardPath.lineWidth = 1
        cardPath.stroke()
    }
}

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

// MARK: - Status badge

final class StatusBadge: NSView {
    private let label = NSTextField(labelWithString: "")
    private var granted: Bool = false

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
        layer?.cornerRadius = 4
        layer?.cornerCurve = .continuous
        label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
        ])
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    func configure(granted: Bool) {
        self.granted = granted
        refreshTitle()
    }

    func refreshTitle() {
        let color: NSColor = granted ? .systemGreen : .systemOrange
        label.stringValue = granted ? L10n.permissionGranted : L10n.permissionNotGranted
        label.textColor = color
        layer?.backgroundColor = color.withAlphaComponent(0.18).cgColor
    }
}

// MARK: - Pointing-hand action button

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
        guard isEnabled, interactiveBounds.contains(point) else { return nil }
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
