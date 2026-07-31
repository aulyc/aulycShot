import AppKit

struct UpdateAlertPresentation {
    let title: String
    let message: String
    let buttonTitles: [String]
}

/// Presents update results in an ordinary AppKit panel without entering an
/// application-modal event loop.
///
/// `NSAlert` only exposes modal and sheet presentation APIs. Ordering its
/// internal window directly can reveal AppKit's private help, suppression and
/// unused button controls. This dedicated panel creates only the controls the
/// update flow actually requested, while leaving the global screenshot
/// shortcut and WindowServer capture available.
final class UpdateAlertPresenter: NSObject {
    static let shared = UpdateAlertPresenter()

    private var sessions: [ObjectIdentifier: UpdateAlertSession] = [:]

    @discardableResult
    func present(
        _ presentation: UpdateAlertPresentation,
        completion: ((NSApplication.ModalResponse) -> Void)? = nil
    ) -> UpdateAlertPanel? {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.present(presentation, completion: completion)
            }
            return nil
        }

        guard !presentation.buttonTitles.isEmpty else { return nil }

        let session = UpdateAlertSession(
            presentation: presentation,
            completion: completion
        )
        let identifier = ObjectIdentifier(session)
        session.onFinish = { [weak self] finishedSession in
            self?.sessions.removeValue(forKey: ObjectIdentifier(finishedSession))
        }
        sessions[identifier] = session
        session.present()
        return session.panel
    }
}

final class UpdateAlertPanel: NSPanel {
    let actionButtons: [NSButton]
    var onCancel: (() -> Void)?

    init(presentation: UpdateAlertPresentation) {
        actionButtons = presentation.buttonTitles.enumerated().map { index, title in
            let button = NSButton(title: title, target: nil, action: nil)
            button.bezelStyle = .rounded
            button.controlSize = .large
            button.font = .systemFont(ofSize: 14, weight: index == 0 ? .semibold : .regular)
            button.tag = index
            button.translatesAutoresizingMaskIntoConstraints = false
            return button
        }

        let contentWidth: CGFloat = 340
        let buttonHeight: CGFloat = 36
        let buttonSpacing: CGFloat = 10
        let buttonsHeight = CGFloat(actionButtons.count) * buttonHeight
            + CGFloat(max(0, actionButtons.count - 1)) * buttonSpacing

        let titleLabel = NSTextField(labelWithString: presentation.title)
        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.maximumNumberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.preferredMaxLayoutWidth = contentWidth - 48
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let titleHeight = max(24, ceil(titleLabel.intrinsicContentSize.height))

        let messageLabel = NSTextField(wrappingLabelWithString: presentation.message)
        messageLabel.alignment = .center
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.maximumNumberOfLines = 0
        messageLabel.preferredMaxLayoutWidth = contentWidth - 48
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        let messageHeight = max(20, ceil(messageLabel.intrinsicContentSize.height))

        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let buttonStack = NSStackView(views: actionButtons)
        buttonStack.orientation = .vertical
        buttonStack.alignment = .centerX
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = buttonSpacing
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let contentHeight = 28 + 56 + 16 + titleHeight + 8 + messageHeight + 24 + buttonsHeight + 24
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        sharingType = .readWrite
        animationBehavior = .none
        isMovableByWindowBackground = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .windowBackgroundColor

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView = contentView
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(messageLabel)
        contentView.addSubview(buttonStack)

        for button in actionButtons {
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalTo: buttonStack.widthAnchor),
                button.heightAnchor.constraint(equalToConstant: buttonHeight),
            ])
        }

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 56),
            iconView.heightAnchor.constraint(equalToConstant: 56),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            buttonStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),
            buttonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
        ])
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

private final class UpdateAlertSession: NSObject {
    let panel: UpdateAlertPanel
    let completion: ((NSApplication.ModalResponse) -> Void)?
    var onFinish: ((UpdateAlertSession) -> Void)?

    private var closeObserver: NSObjectProtocol?
    private var isFinished = false

    init(
        presentation: UpdateAlertPresentation,
        completion: ((NSApplication.ModalResponse) -> Void)?
    ) {
        panel = UpdateAlertPanel(presentation: presentation)
        self.completion = completion
        super.init()
    }

    deinit {
        removeCloseObserver()
    }

    func present() {
        for button in panel.actionButtons {
            button.target = self
            button.action = #selector(buttonClicked(_:))
        }
        panel.actionButtons.first?.keyEquivalent = "\r"
        panel.onCancel = { [weak self] in
            self?.finish(response: .cancel, orderOut: true)
        }

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.finish(response: .cancel, orderOut: false)
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func buttonClicked(_ sender: NSButton) {
        let response = NSApplication.ModalResponse(
            rawValue: NSApplication.ModalResponse.alertFirstButtonReturn.rawValue + sender.tag
        )
        finish(response: response, orderOut: true)
    }

    private func finish(
        response: NSApplication.ModalResponse,
        orderOut: Bool
    ) {
        guard !isFinished else { return }
        isFinished = true
        removeCloseObserver()
        panel.onCancel = nil
        if orderOut {
            panel.orderOut(nil)
        }
        completion?(response)
        onFinish?(self)
    }

    private func removeCloseObserver() {
        guard let closeObserver else { return }
        NotificationCenter.default.removeObserver(closeObserver)
        self.closeObserver = nil
    }
}
