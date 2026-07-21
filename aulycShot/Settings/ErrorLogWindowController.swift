import AppKit

/// Presents diagnostic logs in a focused child window instead of expanding the
/// About pane. The child relationship keeps the window attached to Settings and
/// prevents it from floating above unrelated apps.
final class ErrorLogWindowController: NSWindowController, NSWindowDelegate {
    private weak var parentWindow: NSWindow?
    private var entry: CrashLogReader.Entry?

    private let titleLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let textView = NSTextView()
    private let copyButton = NSButton()
    private let revealButton = NSButton()
    private let refreshButton = NSButton()
    private let clearButton = NSButton()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = SettingsPalette.contentBackground
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.minSize = NSSize(width: 560, height: 360)

        super.init(window: window)

        shouldCascadeWindows = false
        window.delegate = self
        window.contentView = buildContentView()
        refreshLocalizedText()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(relativeTo parent: NSWindow?) {
        reloadFromDisk()

        guard let window else { return }
        if let parent, window.parent !== parent {
            window.parent?.removeChildWindow(window)
            parent.addChildWindow(window, ordered: .above)
            parentWindow = parent
        }

        showWindow(nil)
        center(window, over: parent)
        window.makeKeyAndOrderFront(nil)
    }

    func refreshLocalizedText() {
        window?.title = L10n.aboutErrorLog
        titleLabel.stringValue = L10n.aboutErrorLog
        copyButton.title = L10n.aboutErrorLogCopy
        revealButton.title = L10n.aboutErrorLogReveal
        refreshButton.title = L10n.aboutErrorLogRefresh
        clearButton.title = L10n.aboutErrorLogClear
        renderEntry()
    }

    func windowWillClose(_ notification: Notification) {
        if let window {
            parentWindow?.removeChildWindow(window)
        }
        parentWindow = nil
    }

    private func buildContentView() -> NSView {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        root.wantsLayer = true
        root.layer?.backgroundColor = SettingsPalette.contentBackground.cgColor

        let iconChip = NSView()
        iconChip.translatesAutoresizingMaskIntoConstraints = false
        iconChip.wantsLayer = true
        iconChip.layer?.cornerRadius = 12
        iconChip.layer?.cornerCurve = .continuous
        iconChip.layer?.backgroundColor = SettingsPalette.accent.withAlphaComponent(0.14).cgColor

        let icon = NSImageView()
        icon.image = NSImage(
            systemSymbolName: "doc.text.magnifyingglass",
            accessibilityDescription: nil
        ) ?? NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 21, weight: .medium)
        icon.contentTintColor = SettingsPalette.accent
        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconChip.addSubview(icon)

        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = SettingsPalette.primaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = SettingsPalette.secondaryText
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let headerText = NSStackView(views: [titleLabel, statusLabel])
        headerText.orientation = .vertical
        headerText.alignment = .leading
        headerText.spacing = 4
        headerText.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        separator.layer?.backgroundColor = SettingsPalette.separator.cgColor

        let logContainer = NSView()
        logContainer.translatesAutoresizingMaskIntoConstraints = false
        logContainer.wantsLayer = true
        logContainer.layer?.cornerRadius = 10
        logContainer.layer?.cornerCurve = .continuous
        logContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.18).cgColor
        logContainer.layer?.borderWidth = 1
        logContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.07).cgColor

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .none
        scrollView.borderType = .noBorder

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = NSColor.white.withAlphaComponent(0.82)
        textView.font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        logContainer.addSubview(scrollView)

        configureButton(refreshButton, action: #selector(refreshLog))
        configureButton(revealButton, action: #selector(revealLog))
        configureButton(clearButton, action: #selector(clearLog))
        configureButton(copyButton, action: #selector(copyLog), prominent: true)
        clearButton.contentTintColor = NSColor(calibratedRed: 0.96, green: 0.42, blue: 0.40, alpha: 1)

        let bottomSeparator = NSView()
        bottomSeparator.translatesAutoresizingMaskIntoConstraints = false
        bottomSeparator.wantsLayer = true
        bottomSeparator.layer?.backgroundColor = SettingsPalette.separator.cgColor

        root.addSubview(iconChip)
        root.addSubview(headerText)
        root.addSubview(separator)
        root.addSubview(logContainer)
        root.addSubview(bottomSeparator)
        root.addSubview(refreshButton)
        root.addSubview(revealButton)
        root.addSubview(clearButton)
        root.addSubview(copyButton)

        NSLayoutConstraint.activate([
            iconChip.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            iconChip.topAnchor.constraint(equalTo: root.topAnchor, constant: 46),
            iconChip.widthAnchor.constraint(equalToConstant: 44),
            iconChip.heightAnchor.constraint(equalToConstant: 44),

            icon.centerXAnchor.constraint(equalTo: iconChip.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconChip.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 26),
            icon.heightAnchor.constraint(equalToConstant: 26),

            headerText.leadingAnchor.constraint(equalTo: iconChip.trailingAnchor, constant: 14),
            headerText.centerYAnchor.constraint(equalTo: iconChip.centerYAnchor),
            headerText.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -24),

            separator.topAnchor.constraint(equalTo: iconChip.bottomAnchor, constant: 20),
            separator.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            separator.heightAnchor.constraint(equalToConstant: 1),

            logContainer.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 16),
            logContainer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            logContainer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            logContainer.bottomAnchor.constraint(equalTo: bottomSeparator.topAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: logContainer.topAnchor, constant: 1),
            scrollView.leadingAnchor.constraint(equalTo: logContainer.leadingAnchor, constant: 1),
            scrollView.trailingAnchor.constraint(equalTo: logContainer.trailingAnchor, constant: -1),
            scrollView.bottomAnchor.constraint(equalTo: logContainer.bottomAnchor, constant: -1),

            bottomSeparator.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            bottomSeparator.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            bottomSeparator.bottomAnchor.constraint(equalTo: refreshButton.topAnchor, constant: -14),
            bottomSeparator.heightAnchor.constraint(equalToConstant: 1),

            refreshButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            refreshButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18),
            revealButton.leadingAnchor.constraint(equalTo: refreshButton.trailingAnchor, constant: 8),
            revealButton.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),

            copyButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            copyButton.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -8),
            clearButton.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),
        ])

        return root
    }

    private func configureButton(_ button: NSButton, action: Selector, prominent: Bool = false) {
        button.target = self
        button.action = action
        button.bezelStyle = prominent ? .texturedRounded : .rounded
        button.controlSize = .regular
        button.font = NSFont.systemFont(ofSize: 12.5, weight: prominent ? .semibold : .regular)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    private func reloadFromDisk() {
        entry = CrashLogReader.latestLogFile()
        renderEntry()
    }

    private func renderEntry() {
        if let entry {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            statusLabel.stringValue = L10n.aboutErrorLogLastCrash(formatter.string(from: entry.date))
            statusLabel.textColor = NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.45, alpha: 1)
            textView.string = CrashLogReader.readableText(at: entry.url)
            textView.textColor = NSColor.white.withAlphaComponent(0.82)
            copyButton.isEnabled = true
            revealButton.isEnabled = true
            clearButton.isEnabled = true
        } else {
            statusLabel.stringValue = L10n.aboutErrorLogNoCrash
            statusLabel.textColor = SettingsPalette.secondaryText
            textView.string = L10n.aboutErrorLogEmptyBody
            textView.textColor = NSColor.white.withAlphaComponent(0.48)
            copyButton.isEnabled = false
            revealButton.isEnabled = false
            clearButton.isEnabled = false
        }
    }

    @objc private func refreshLog() {
        reloadFromDisk()
    }

    @objc private func revealLog() {
        guard let url = entry?.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func copyLog() {
        guard entry != nil, !textView.string.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textView.string, forType: .string)

        copyButton.title = L10n.aboutErrorLogCopied
        copyButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.entry != nil else { return }
            self.copyButton.title = L10n.aboutErrorLogCopy
            self.copyButton.isEnabled = true
        }
    }

    @objc private func clearLog() {
        CrashLogReader.deleteAllLogs()
        reloadFromDisk()
    }

    private func center(_ window: NSWindow, over parent: NSWindow?) {
        guard let parent else {
            window.center()
            return
        }
        let parentFrame = parent.frame
        let windowFrame = window.frame
        let origin = NSPoint(
            x: parentFrame.midX - windowFrame.width / 2,
            y: parentFrame.midY - windowFrame.height / 2
        )
        window.setFrameOrigin(origin)
    }
}
