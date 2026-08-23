import AppKit

@MainActor
final class RecordingSavePanel: NSPanel {
    static let contentWidth: CGFloat = 333
    static let contentHeight: CGFloat = 252

    let appIconView = NSImageView()
    let headingLabel = NSTextField(labelWithString: L10n.recordingFormatChoiceTitle)
    let formatLabel = NSTextField(labelWithString: L10n.recordingFormatLabel)
    let formatPopup = NSPopUpButton(frame: .zero, pullsDown: false)
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
        configureFormLabel(locationLabel)

        formatPopup.translatesAutoresizingMaskIntoConstraints = false
        for format in ScreenRecordingFormat.allCases {
            formatPopup.addItem(withTitle: format.displayName)
            formatPopup.lastItem?.representedObject = format.rawValue
        }
        formatPopup.selectItem(withTitle: initialFormat.displayName)
        formatPopup.isEnabled = allowsFormatSelection

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

        actionStack.orientation = .horizontal
        actionStack.alignment = .centerY
        actionStack.spacing = 10
        actionStack.addArrangedSubview(cancelButton)
        actionStack.addArrangedSubview(saveButton)
        actionStack.translatesAutoresizingMaskIntoConstraints = false

        [
            appIconView,
            headingLabel,
            formatLabel,
            formatPopup,
            defaultPathCheckbox,
            locationLabel,
            pathValue,
            choosePathButton,
            actionStack,
        ].forEach(rootView.addSubview)

        NSLayoutConstraint.activate([
            appIconView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 28),
            appIconView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 24),
            appIconView.widthAnchor.constraint(equalToConstant: 30),
            appIconView.heightAnchor.constraint(equalToConstant: 30),

            headingLabel.leadingAnchor.constraint(equalTo: appIconView.trailingAnchor, constant: 10),
            headingLabel.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -28),
            headingLabel.centerYAnchor.constraint(equalTo: appIconView.centerYAnchor),

            formatLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 28),
            formatLabel.topAnchor.constraint(equalTo: appIconView.bottomAnchor, constant: 22),
            formatLabel.widthAnchor.constraint(equalToConstant: 36),

            formatPopup.leadingAnchor.constraint(equalTo: formatLabel.trailingAnchor, constant: 8),
            formatPopup.trailingAnchor.constraint(equalTo: choosePathButton.trailingAnchor),
            formatPopup.centerYAnchor.constraint(equalTo: formatLabel.centerYAnchor),
            formatPopup.heightAnchor.constraint(equalToConstant: 26),

            locationLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 28),
            locationLabel.topAnchor.constraint(equalTo: formatPopup.bottomAnchor, constant: 14),
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
        finish(with: .OK)
    }

    private func finish(with response: NSApplication.ModalResponse) {
        NSApp.stopModal(withCode: response)
    }
}
