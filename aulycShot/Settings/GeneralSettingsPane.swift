import AppKit
import Carbon

extension SettingsView {
func buildGeneralPane() -> NSView {
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

    func refreshSavePathControls() {
        recordingSavePathValueLabel?.stringValue = SaveDestination.displayPath(Defaults.recordingSaveDirectory)
        let screenshotState = ScreenshotSavePathControlState(
            directory: Defaults.screenshotSaveDirectory,
            outputMode: Defaults.screenshotOutputMode
        )
        screenshotSavePathValueLabel?.stringValue = SaveDestination.displayPath(screenshotState.directory)
        applyScreenshotSavePathControlState(screenshotState)
        refreshRecordingSaveFormatPopup()
    }

    func refreshScreenshotQualityControls() {
        let quality = Defaults.screenshotQuality
        refreshScreenshotQualityPopup(screenshotQualityPopup, selected: quality)
        screenshotQualityHintLabel?.stringValue = quality.localizedHint
    }

    func refreshScreenshotOutputControls() {
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

    func refreshRecordingSaveFormatPopup() {
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

    func constrainGeneralPopupWidth(_ popup: NSPopUpButton) {
        popup.translatesAutoresizingMaskIntoConstraints = false
        let constraint = popup.widthAnchor.constraint(equalToConstant: preferredGeneralPopupWidth())
        constraint.isActive = true
        generalPopupWidthConstraints.append(constraint)
    }

    func refreshGeneralPopupWidths() {
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

    func configureGeneralActionButton(_ button: NSButton) {
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
}
