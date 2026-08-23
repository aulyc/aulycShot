import AppKit

@MainActor
final class RecordingSavePanel: NSPanel, NSTextFieldDelegate {
    static let contentWidth: CGFloat = 333
    static let contentHeight: CGFloat = 292

    let appIconView = NSImageView()
    let headingLabel = NSTextField(labelWithString: L10n.recordingFormatChoiceTitle)
    let headerStack = NSStackView()
    let formatLabel = NSTextField(labelWithString: L10n.recordingFormatLabel)
    let formatPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let nameLabel = NSTextField(labelWithString: L10n.recordingFileNameLabel)
    let nameField = NSTextField(string: "")
    let nameExtensionLabel = NSTextField(labelWithString: "")
    let defaultPathCheckbox = NSButton(
        checkboxWithTitle: L10n.recordingUseDefaultSavePath,
        target: nil,
        action: nil
    )
    let locationLabel = NSTextField(labelWithString: L10n.recordingSaveLocationLabel)
    let pathValue = NSTextField(labelWithString: "")
    let choosePathButton = NSButton(title: "", target: nil, action: nil)
    let cancelButton = NSButton(title: L10n.shortcutCancel, target: nil, action: nil)
    let saveButton = NSButton(title: L10n.saveRecordingPrompt, target: nil, action: nil)
    let actionStack = NSStackView()

    private let fallbackFormat: ScreenRecordingFormat
    private let defaultFileNameStem: String
    private var pathSelection: RecordingSavePathSelection

    var selectedFormat: ScreenRecordingFormat {
        guard let raw = formatPopup.selectedItem?.representedObject as? String,
              let format = ScreenRecordingFormat(rawValue: raw)
        else {
            return fallbackFormat
        }
        return format
    }

    var selectedDirectory: URL {
        pathSelection.selectedDirectory
    }

    var selectedFileName: String {
        let stem = normalizedFileNameStem ?? defaultFileNameStem
        return "\(stem).\(selectedFormat.fileExtension)"
    }

    var usesDefaultDirectory: Bool {
        pathSelection.usesDefaultDirectory
    }

    var customDirectory: URL {
        pathSelection.customDirectory
    }

    init(
        initialFormat: ScreenRecordingFormat,
        allowsFormatSelection: Bool,
        defaultDirectory: URL,
        lastCustomDirectory: URL?
    ) {
        fallbackFormat = initialFormat
        let defaultFileName = OutputFilename.recordingFileName(
            fileExtension: initialFormat.fileExtension
        )
        defaultFileNameStem = (defaultFileName as NSString).deletingPathExtension
        pathSelection = RecordingSavePathSelection(
            defaultDirectory: defaultDirectory,
            customDirectory: lastCustomDirectory
        )

        super.init(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Self.contentWidth,
                height: Self.contentHeight
            ),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        configureWindow()
        configureControls(
            initialFormat: initialFormat,
            allowsFormatSelection: allowsFormatSelection
        )
        buildLayout()
        refreshFileNameControls()
        refreshPathControls()
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        finish(with: .cancel)
    }

    func presentModally() -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        center()
        makeKeyAndOrderFront(nil)
        makeFirstResponder(nameField)
        nameField.selectText(nil)
        let response = NSApp.runModal(for: self)
        orderOut(nil)
        return response
    }

    private func configureWindow() {
        isReleasedWhenClosed = false
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        sharingType = .readWrite
        animationBehavior = .alertPanel
        isMovableByWindowBackground = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .windowBackgroundColor

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    private func configureControls(
        initialFormat: ScreenRecordingFormat,
        allowsFormatSelection: Bool
    ) {
        appIconView.image = NSApp.applicationIconImage
        appIconView.imageScaling = .scaleProportionallyUpOrDown
        appIconView.translatesAutoresizingMaskIntoConstraints = false

        headingLabel.alignment = .left
        headingLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        headingLabel.textColor = .labelColor
        headingLabel.translatesAutoresizingMaskIntoConstraints = false

        configureFormLabel(formatLabel)
        configureFormLabel(nameLabel)
        configureFormLabel(locationLabel)

        formatPopup.translatesAutoresizingMaskIntoConstraints = false
        for format in ScreenRecordingFormat.allCases {
            formatPopup.addItem(withTitle: format.displayName)
            formatPopup.lastItem?.representedObject = format.rawValue
        }
        formatPopup.selectItem(withTitle: initialFormat.displayName)
        formatPopup.isEnabled = allowsFormatSelection
        formatPopup.target = self
        formatPopup.action = #selector(formatSelectionDidChange)

        nameField.stringValue = defaultFileNameStem
        nameField.placeholderString = L10n.recordingFileNamePlaceholder
        nameField.delegate = self
        nameField.lineBreakMode = .byTruncatingMiddle
        nameField.cell?.usesSingleLineMode = true
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        nameExtensionLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        nameExtensionLabel.textColor = .secondaryLabelColor
        nameExtensionLabel.alignment = .right
        nameExtensionLabel.translatesAutoresizingMaskIntoConstraints = false
        nameExtensionLabel.setContentHuggingPriority(.required, for: .horizontal)
        nameExtensionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        defaultPathCheckbox.translatesAutoresizingMaskIntoConstraints = false
        defaultPathCheckbox.target = self
        defaultPathCheckbox.action = #selector(defaultPathSelectionDidChange)
        defaultPathCheckbox.state = .on
        defaultPathCheckbox.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        (defaultPathCheckbox.cell as? NSButtonCell)?.lineBreakMode = .byTruncatingTail

        pathValue.translatesAutoresizingMaskIntoConstraints = false
        pathValue.lineBreakMode = .byTruncatingMiddle
        pathValue.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        choosePathButton.image = NSImage(
            systemSymbolName: "folder",
            accessibilityDescription: L10n.savePathChoose
        )?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        choosePathButton.imagePosition = .imageOnly
        choosePathButton.imageScaling = .scaleProportionallyDown
        choosePathButton.bezelStyle = .rounded
        choosePathButton.toolTip = L10n.savePathChoose
        choosePathButton.setAccessibilityLabel(L10n.savePathChoose)
        choosePathButton.target = self
        choosePathButton.action = #selector(choosePath)
        choosePathButton.translatesAutoresizingMaskIntoConstraints = false

        configureActionButton(cancelButton, isPrimary: false)
        configureActionButton(saveButton, isPrimary: true)
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        saveButton.keyEquivalent = "\r"
    }

    private func configureFormLabel(_ label: NSTextField) {
        label.alignment = .left
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureActionButton(_ button: NSButton, isPrimary: Bool) {
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.font = .systemFont(ofSize: 14, weight: isPrimary ? .semibold : .regular)
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    private func buildLayout() {
        let rootView = NSView(
            frame: NSRect(x: 0, y: 0, width: Self.contentWidth, height: Self.contentHeight)
        )
        contentView = rootView

        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 10
        headerStack.addArrangedSubview(appIconView)
        headerStack.addArrangedSubview(headingLabel)
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        actionStack.orientation = .horizontal
        actionStack.alignment = .centerY
        actionStack.spacing = 10
        actionStack.addArrangedSubview(cancelButton)
        actionStack.addArrangedSubview(saveButton)
        actionStack.translatesAutoresizingMaskIntoConstraints = false

        [
            headerStack,
            formatLabel,
            formatPopup,
            nameLabel,
            nameField,
            nameExtensionLabel,
            defaultPathCheckbox,
            locationLabel,
            pathValue,
            choosePathButton,
            actionStack,
        ].forEach(rootView.addSubview)

        NSLayoutConstraint.activate([
            headerStack.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            headerStack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 24),
            headerStack.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: 28),
            headerStack.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -28),

            appIconView.widthAnchor.constraint(equalToConstant: 30),
            appIconView.heightAnchor.constraint(equalToConstant: 30),

            formatLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 28),
            formatLabel.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 22),
            formatLabel.widthAnchor.constraint(equalToConstant: 36),

            formatPopup.leadingAnchor.constraint(equalTo: formatLabel.trailingAnchor, constant: 8),
            formatPopup.trailingAnchor.constraint(equalTo: choosePathButton.trailingAnchor),
            formatPopup.centerYAnchor.constraint(equalTo: formatLabel.centerYAnchor),
            formatPopup.heightAnchor.constraint(equalToConstant: 26),

            nameLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 28),
            nameLabel.topAnchor.constraint(equalTo: formatPopup.bottomAnchor, constant: 14),
            nameLabel.widthAnchor.constraint(equalToConstant: 36),

            nameField.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            nameField.trailingAnchor.constraint(equalTo: nameExtensionLabel.leadingAnchor, constant: -6),
            nameField.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            nameField.heightAnchor.constraint(equalToConstant: 26),

            nameExtensionLabel.trailingAnchor.constraint(equalTo: choosePathButton.trailingAnchor),
            nameExtensionLabel.centerYAnchor.constraint(equalTo: nameField.centerYAnchor),

            locationLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 28),
            locationLabel.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 14),
            locationLabel.widthAnchor.constraint(equalToConstant: 36),

            pathValue.leadingAnchor.constraint(equalTo: locationLabel.trailingAnchor, constant: 8),
            pathValue.trailingAnchor.constraint(equalTo: choosePathButton.leadingAnchor, constant: -8),
            pathValue.centerYAnchor.constraint(equalTo: choosePathButton.centerYAnchor),

            choosePathButton.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -28),
            choosePathButton.centerYAnchor.constraint(equalTo: locationLabel.centerYAnchor),
            choosePathButton.widthAnchor.constraint(equalToConstant: 34),
            choosePathButton.heightAnchor.constraint(equalToConstant: 28),

            defaultPathCheckbox.leadingAnchor.constraint(equalTo: formatPopup.leadingAnchor),
            defaultPathCheckbox.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -28),
            defaultPathCheckbox.topAnchor.constraint(equalTo: choosePathButton.bottomAnchor, constant: 14),

            cancelButton.widthAnchor.constraint(equalToConstant: 92),
            cancelButton.heightAnchor.constraint(equalToConstant: 32),
            saveButton.widthAnchor.constraint(equalToConstant: 92),
            saveButton.heightAnchor.constraint(equalToConstant: 32),

            actionStack.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            actionStack.topAnchor.constraint(equalTo: defaultPathCheckbox.bottomAnchor, constant: 22),
            actionStack.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -22),
        ])
    }

    func controlTextDidChange(_ notification: Notification) {
        guard notification.object as? NSTextField === nameField else { return }
        refreshFileNameControls()
    }

    @objc private func formatSelectionDidChange() {
        refreshFileNameControls()
    }

    private var normalizedFileNameStem: String? {
        var stem = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stem.isEmpty,
              !stem.contains("/"),
              stem.rangeOfCharacter(from: .controlCharacters) == nil
        else {
            return nil
        }

        for format in ScreenRecordingFormat.allCases {
            let suffix = ".\(format.fileExtension)"
            if stem.count > suffix.count, stem.lowercased().hasSuffix(suffix) {
                stem.removeLast(suffix.count)
                break
            }
        }

        let normalized = stem.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func refreshFileNameControls() {
        nameExtensionLabel.stringValue = ".\(selectedFormat.fileExtension)"
        saveButton.isEnabled = normalizedFileNameStem != nil
    }

    @objc private func defaultPathSelectionDidChange() {
        pathSelection.usesDefaultDirectory = defaultPathCheckbox.state == .on
        refreshPathControls()
    }

    @objc private func choosePath() {
        let panel = NSOpenPanel()
        panel.title = L10n.chooseRecordingSavePathTitle
        panel.prompt = L10n.savePathChoose
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = existingDirectoryForPanel(pathSelection.customDirectory)

        panel.beginSheetModal(for: self) { [weak self] response in
            guard response == .OK, let directory = panel.url else { return }
            self?.pathSelection.selectCustomDirectory(directory)
            self?.refreshPathControls()
        }
    }

    private func refreshPathControls() {
        let usesDefaultPath = pathSelection.usesDefaultDirectory
        let directory = pathSelection.selectedDirectory
        pathValue.stringValue = SaveDestination.displayPath(directory)
        pathValue.toolTip = directory.path
        locationLabel.isEnabled = !usesDefaultPath
        pathValue.isEnabled = !usesDefaultPath
        choosePathButton.isEnabled = !usesDefaultPath
    }

    private func existingDirectoryForPanel(_ directory: URL) -> URL {
        if FileManager.default.fileExists(atPath: directory.path) {
            return directory
        }
        let parent = directory.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: parent.path) {
            return parent
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    @objc private func cancelClicked() {
        finish(with: .cancel)
    }

    @objc private func saveClicked() {
        guard normalizedFileNameStem != nil else {
            NSSound.beep()
            makeFirstResponder(nameField)
            return
        }
        finish(with: .OK)
    }

    private func finish(with response: NSApplication.ModalResponse) {
        NSApp.stopModal(withCode: response)
    }
}
