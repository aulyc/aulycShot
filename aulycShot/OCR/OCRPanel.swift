import AppKit

/// Floating OCR result panel shown after recognizing a selected screenshot.
final class OCRPanel: NSPanel {
    private static var current: OCRPanel?
    private static let topMargin: CGFloat = 24

    private let screenshot: NSImage
    private let anchorScreen: NSScreen
    private let panelWidth: CGFloat
    private let previewView: OCRPanelPreviewView
    private let textView = NSTextView()
    private let copyButton = NSButton()
    private let pinButton = OCRPanelPinButton()
    private var recognizedText = ""
    private var isReady = false
    private var keyMonitor: Any?
    private var outsideClickLocalMonitor: Any?
    private var outsideClickGlobalMonitor: Any?
    private var isPinned = false {
        didSet { pinButton.setPinned(isPinned) }
    }

    static func present(image: NSImage, anchorRect: NSRect, screen: NSScreen) {
        current?.dismiss()
        let panel = OCRPanel(image: image, anchorRect: anchorRect, screen: screen)
        current = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.runOCR()
    }

    private init(image: NSImage, anchorRect: NSRect, screen: NSScreen) {
        screenshot = image
        anchorScreen = screen
        panelWidth = min(max(anchorRect.width, 360), 500)
        previewView = OCRPanelPreviewView(image: image)

        let initialFrame = Self.topCenteredFrame(width: panelWidth, height: 420, on: screen)
        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .none

        buildUI()
        installEventMonitors()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private func buildUI() {
        let root = AdaptiveChromeSurfaceView(style: .panel, cornerRadius: 12, borderWidth: 1)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView = root

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        pinButton.translatesAutoresizingMaskIntoConstraints = false
        pinButton.target = self
        pinButton.action = #selector(pinTapped)
        root.addSubview(pinButton)

        let size = screenshot.size
        let aspect = size.width > 0 ? size.height / size.width : 0.5
        let previewHeight = min(max((panelWidth - 28) * aspect, 64), 260)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.heightAnchor.constraint(equalToConstant: previewHeight).isActive = true
        previewView.onSelectText = { [weak self] text, isFinal in
            guard isFinal else { return }
            self?.copyRecognizedText(text)
        }
        stack.addArrangedSubview(previewView)
        previewView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let card = AdaptiveChromeSurfaceView(style: .card, cornerRadius: 10, borderWidth: 1)
        card.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let resultStack = NSStackView()
        resultStack.orientation = .vertical
        resultStack.alignment = .leading
        resultStack.spacing = 8
        resultStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(resultStack)

        let title = NSTextField(labelWithString: L10n.ocrTextHeader)
        title.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        title.textColor = .labelColor

        copyButton.title = L10n.ocrCopy
        copyButton.bezelStyle = .rounded
        copyButton.controlSize = .small
        copyButton.font = NSFont.systemFont(ofSize: 11)
        copyButton.target = self
        copyButton.action = #selector(copyTapped)
        copyButton.isEnabled = false

        let header = NSStackView(views: [title, flexibleSpacer(), copyButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        resultStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: resultStack.widthAnchor).isActive = true

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = AdaptiveChrome.cardBackground
        scrollView.borderType = .noBorder
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 6
        scrollView.layer?.cornerCurve = .continuous
        scrollView.layer?.masksToBounds = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(equalToConstant: 116).isActive = true

        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.textColor = .secondaryLabelColor
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.string = L10n.ocrRecognizing
        scrollView.documentView = textView
        resultStack.addArrangedSubview(scrollView)
        scrollView.widthAnchor.constraint(equalTo: resultStack.widthAnchor).isActive = true

        NSLayoutConstraint.activate([
            root.widthAnchor.constraint(equalToConstant: panelWidth),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),
            resultStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            resultStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            resultStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            resultStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            pinButton.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            pinButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -8),
            pinButton.widthAnchor.constraint(equalToConstant: 24),
            pinButton.heightAnchor.constraint(equalToConstant: 24),
        ])

        root.layoutSubtreeIfNeeded()
        refreshHeight(for: stack.fittingSize.height + 28)
    }

    private func runOCR() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let lines = await OCRService.recognizeLines(image: screenshot)
            recognizedText = lines.map(\.text).joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            previewView.lines = lines
            previewView.isSelectionEnabled = !lines.isEmpty
            isReady = true
            copyButton.isEnabled = !recognizedText.isEmpty
            if recognizedText.isEmpty {
                textView.string = L10n.ocrNoText
                textView.textColor = .secondaryLabelColor
            } else {
                textView.string = recognizedText
                textView.textColor = .labelColor
            }
        }
    }

    @objc private func pinTapped() {
        isPinned.toggle()
    }

    @objc private func copyTapped() {
        guard isReady else { return }
        if previewView.copySelectedTextToClipboard() {
            flashCopyButton()
            return
        }
        copyRecognizedText(recognizedText)
    }

    private func copyRecognizedText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(trimmed, forType: .string)
        flashCopyButton()
    }

    private func flashCopyButton() {
        copyButton.title = L10n.ocrCopied
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.copyButton.title = L10n.ocrCopy
        }
    }

    private func installEventMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self else { return event }
            if event.keyCode == 53 {
                dismiss()
                return nil
            }
            guard !(firstResponder is NSTextView),
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command else {
                return event
            }
            switch event.charactersIgnoringModifiers {
            case "a":
                return previewView.selectAllText() ? nil : event
            case "c":
                guard previewView.copySelectedTextToClipboard() else { return event }
                flashCopyButton()
                return nil
            default:
                return event
            }
        }

        let mouseMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseMask) { [weak self] event in
            self?.dismissForOutsideClick(event)
            return event
        }
        outsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseMask) { [weak self] event in
            self?.dismissForOutsideClick(event)
        }
    }

    private func dismissForOutsideClick(_ event: NSEvent) {
        guard !isPinned, isVisible else { return }
        if event.window === self || event.windowNumber == windowNumber { return }
        if let eventWindow = event.window, eventWindow.contentView is SelectionView {
            let screenPoint = eventWindow.convertPoint(toScreen: event.locationInWindow)
            if frame.insetBy(dx: -24, dy: -24).contains(screenPoint) { return }
        }
        dismiss()
    }

    func dismiss() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        if let outsideClickLocalMonitor {
            NSEvent.removeMonitor(outsideClickLocalMonitor)
            self.outsideClickLocalMonitor = nil
        }
        if let outsideClickGlobalMonitor {
            NSEvent.removeMonitor(outsideClickGlobalMonitor)
            self.outsideClickGlobalMonitor = nil
        }
        orderOut(nil)
        if Self.current === self { Self.current = nil }
    }

    private func refreshHeight(for contentHeight: CGFloat) {
        let visible = anchorScreen.visibleFrame
        let maximum = min(700, visible.height - Self.topMargin - 16)
        let height = max(180, min(contentHeight, maximum))
        setFrame(Self.topCenteredFrame(width: panelWidth, height: height, on: anchorScreen), display: true)
    }

    private static func topCenteredFrame(width: CGFloat, height: CGFloat, on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let originX = min(max(visible.midX - width / 2, visible.minX), visible.maxX - width)
        let originY = max(visible.maxY - topMargin - height, visible.minY)
        return NSRect(x: originX, y: originY, width: width, height: height)
    }

    private func flexibleSpacer() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.init(1), for: .horizontal)
        view.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        return view
    }
}

private final class OCRPanelPreviewView: NSView {
    private let imageView = NSImageView()
    private let overlay: OCRLineSelectionOverlayView

    var lines: [RecognizedTextLine] = [] {
        didSet { overlay.lines = lines }
    }

    var isSelectionEnabled = false {
        didSet {
            overlay.showsLineBoxes = isSelectionEnabled
            overlay.isHidden = !isSelectionEnabled
        }
    }

    var onSelectText: ((String, Bool) -> Void)? {
        didSet {
            overlay.onSelectText = { [weak self] text, _, isFinal in
                self?.onSelectText?(text, isFinal)
            }
        }
    }

    init(image: NSImage) {
        overlay = OCRLineSelectionOverlayView(imageSize: image.size)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.26).cgColor
        layer?.borderWidth = 1

        imageView.image = image
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        addSubview(imageView)

        overlay.frame = bounds
        overlay.autoresizingMask = [.width, .height]
        overlay.isHidden = true
        addSubview(overlay)
        applyAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
    }

    func copySelectedTextToClipboard() -> Bool {
        overlay.copySelectedTextToClipboard()
    }

    func selectAllText() -> Bool {
        overlay.selectAllText()
    }

    private func applyAppearance() {
        layer?.borderColor = AdaptiveChrome.resolvedCGColor(AdaptiveChrome.border, for: effectiveAppearance)
    }
}

private final class OCRPanelPinButton: NSButton {
    private let pinSymbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title = ""
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        isBordered = false
        bezelStyle = .regularSquare
        focusRingType = .none
        wantsLayer = true
        layer?.borderWidth = 1.2
        setPinned(false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { false }

    override func layout() {
        super.layout()
        layer?.cornerRadius = min(bounds.width, bounds.height) / 2
    }

    func setPinned(_ pinned: Bool) {
        let label = pinned ? "Unpin dialog" : "Pin dialog"
        image = NSImage(systemSymbolName: pinned ? "pin.fill" : "pin", accessibilityDescription: label)?
            .withSymbolConfiguration(pinSymbolConfiguration)
        contentTintColor = pinned ? .white : .labelColor
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(
            pinned ? accentGreen.withAlphaComponent(0.96) : AdaptiveChrome.floatingBackground,
            for: effectiveAppearance
        )
        layer?.borderColor = AdaptiveChrome.resolvedCGColor(AdaptiveChrome.border, for: effectiveAppearance)
        toolTip = label
        setAccessibilityLabel(label)
    }
}
