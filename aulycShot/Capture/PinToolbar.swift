import AppKit

// MARK: - Pin Toolbar

struct PinToolbarZoomLayout: Equatable {
    static let zoomOutSymbolName = "minus"
    static let zoomInSymbolName = "plus"
    static let buttonWidth: CGFloat = 24
    static let labelWidth: CGFloat = 44

    let zoomOutFrame: NSRect
    let labelFrame: NSRect
    let zoomInFrame: NSRect

    static func make(
        availableRect: NSRect,
        buttonY: CGFloat,
        buttonSide: CGFloat
    ) -> PinToolbarZoomLayout {
        let groupWidth = buttonWidth * 2 + labelWidth
        let groupX = availableRect.minX + max(0, (availableRect.width - groupWidth) / 2)
        let zoomOutFrame = NSRect(
            x: groupX,
            y: buttonY,
            width: buttonWidth,
            height: buttonSide
        )
        let labelFrame = NSRect(
            x: zoomOutFrame.maxX,
            y: buttonY + 5,
            width: labelWidth,
            height: buttonSide - 10
        )
        let zoomInFrame = NSRect(
            x: labelFrame.maxX,
            y: buttonY,
            width: buttonWidth,
            height: buttonSide
        )
        return PinToolbarZoomLayout(
            zoomOutFrame: zoomOutFrame,
            labelFrame: labelFrame,
            zoomInFrame: zoomInFrame
        )
    }
}

final class PinToolbarView: NSView {
    static let preferredWidth: CGFloat = 258
    static let minimumWidth: CGFloat = 220
    static let preferredHeight: CGFloat = 34

    var onEdit: (() -> Void)?
    var onMoveMouseDown: ((NSEvent) -> Void)?
    var onZoomOut: (() -> Void)?
    var onZoomIn: (() -> Void)?
    var onResetZoom: (() -> Void)?
    var onClose: (() -> Void)?
    var zoomScale: CGFloat = 1.0 {
        didSet {
            zoomLabel.setPercentage(Int(round(zoomScale * 100)))
        }
    }

    private let editButton = PinToolbarIconButton(symbolName: "pencil", accessibilityLabel: L10n.pinToolbarEdit)
    private let moveButton = PinToolbarMoveButton(symbolName: "arrow.up.and.down.and.arrow.left.and.right",
                                                  accessibilityLabel: "Move pinned image")
    private let zoomOutButton = PinToolbarIconButton(
        symbolName: PinToolbarZoomLayout.zoomOutSymbolName,
        accessibilityLabel: "Zoom out"
    )
    private let zoomLabel = PinToolbarZoomButton()
    private let zoomInButton = PinToolbarIconButton(
        symbolName: PinToolbarZoomLayout.zoomInSymbolName,
        accessibilityLabel: "Zoom in"
    )
    private let closeButton = PinToolbarIconButton(symbolName: "xmark",
                                                   accessibilityLabel: "Close pinned image")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false

        editButton.toolTip = L10n.pinToolbarEdit
        editButton.target = self
        editButton.action = #selector(editTapped)
        moveButton.onMouseDown = { [weak self] event in
            self?.onMoveMouseDown?(event)
        }

        zoomOutButton.target = self
        zoomOutButton.action = #selector(zoomOutTapped)
        zoomLabel.onClick = { [weak self] in
            self?.onResetZoom?()
        }
        zoomInButton.target = self
        zoomInButton.action = #selector(zoomInTapped)
        closeButton.target = self
        closeButton.action = #selector(closeTapped)

        zoomLabel.alignment = .center

        addSubview(moveButton)
        addSubview(editButton)
        addSubview(zoomOutButton)
        addSubview(zoomLabel)
        addSubview(zoomInButton)
        addSubview(closeButton)
    }

    override func layout() {
        super.layout()

        let buttonSide = min(28, max(22, bounds.height - 6))
        let buttonY = (bounds.height - buttonSide) / 2
        let horizontalInset: CGFloat = 4
        let gap: CGFloat = 8
        let buttonGap: CGFloat = 4

        closeButton.frame = NSRect(x: horizontalInset, y: buttonY, width: buttonSide, height: buttonSide)
        moveButton.frame = NSRect(
            x: bounds.width - horizontalInset - buttonSide,
            y: buttonY,
            width: buttonSide,
            height: buttonSide
        )
        editButton.frame = NSRect(
            x: moveButton.frame.minX - buttonGap - buttonSide,
            y: buttonY,
            width: buttonSide,
            height: buttonSide
        )
        let centerX = closeButton.frame.maxX + gap
        let centerWidth = max(76, editButton.frame.minX - gap - centerX)
        let zoomLayout = PinToolbarZoomLayout.make(
            availableRect: NSRect(x: centerX, y: 0, width: centerWidth, height: bounds.height),
            buttonY: buttonY,
            buttonSide: buttonSide
        )
        zoomOutButton.frame = zoomLayout.zoomOutFrame
        zoomLabel.frame = zoomLayout.labelFrame
        zoomInButton.frame = zoomLayout.zoomInFrame
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                                xRadius: bounds.height / 2,
                                yRadius: bounds.height / 2)
        AdaptiveChrome.toolbarBackground.setFill()
        path.fill()

        AdaptiveChrome.border.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }

    override func magnify(with event: NSEvent) {
        nextResponder?.magnify(with: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {}

    override func mouseDragged(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {}

    @objc private func editTapped() {
        onEdit?()
    }

    @objc private func zoomOutTapped() {
        onZoomOut?()
    }

    @objc private func zoomInTapped() {
        onZoomIn?()
    }

    @objc private func closeTapped() {
        onClose?()
    }
}

private final class PinToolbarZoomButton: NSButton {
    var onClick: (() -> Void)?

    init() {
        super.init(frame: .zero)
        isBordered = false
        bezelStyle = .regularSquare
        focusRingType = .exterior
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(clicked)
        setPercentage(100)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func setPercentage(_ percentage: Int) {
        let value = "\(percentage)%"
        attributedTitle = NSAttributedString(
            string: value,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.labelColor,
            ]
        )
        setAccessibilityLabel(value)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }

    override func magnify(with event: NSEvent) {
        nextResponder?.magnify(with: event)
    }

    @objc private func clicked() {
        onClick?()
    }
}

private class PinToolbarIconButton: NSButton {
    var isActive = false {
        didSet { updateAppearance() }
    }

    init(symbolName: String, accessibilityLabel: String) {
        super.init(frame: .zero)
        title = ""
        isBordered = false
        imagePosition = .imageOnly
        bezelStyle = .regularSquare
        focusRingType = .none
        wantsLayer = true
        layer?.masksToBounds = true
        setAccessibilityLabel(accessibilityLabel)

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityLabel) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            self.image = image.withSymbolConfiguration(config)
        }
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { false }

    override func layout() {
        super.layout()
        layer?.cornerRadius = min(bounds.width, bounds.height) / 2
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }

    override func magnify(with event: NSEvent) {
        nextResponder?.magnify(with: event)
    }

    private func updateAppearance() {
        contentTintColor = isActive ? .white : .labelColor
        layer?.backgroundColor = (isActive
            ? accentGreen.withAlphaComponent(0.86)
            : NSColor.clear
        ).cgColor
    }
}

private final class PinToolbarMoveButton: PinToolbarIconButton {
    var onMouseDown: ((NSEvent) -> Void)?

    override func mouseDown(with event: NSEvent) {
        onMouseDown?(event)
    }
}

final class TextPinToolbarView: NSView {
    static let preferredWidth: CGFloat = 106
    static let preferredHeight: CGFloat = 34

    var onClose: (() -> Void)?
    var onEdit: (() -> Void)?
    var onEditText: (() -> Void)?
    var onPointerEvent: ((NSEvent) -> Void)?

    private let closeButton = PinToolbarIconButton(symbolName: "xmark", accessibilityLabel: L10n.imageMergeClose)
    private let textEditButton = PinToolbarIconButton(symbolName: "textformat", accessibilityLabel: L10n.pinToolbarEditText)
    private let editButton = PinToolbarIconButton(symbolName: "pencil", accessibilityLabel: L10n.pinToolbarEdit)
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false

        closeButton.toolTip = L10n.imageMergeClose
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        textEditButton.toolTip = L10n.pinToolbarEditText
        textEditButton.target = self
        textEditButton.action = #selector(editTextTapped)
        editButton.toolTip = L10n.pinToolbarEdit
        editButton.target = self
        editButton.action = #selector(editTapped)

        addSubview(closeButton)
        addSubview(textEditButton)
        addSubview(editButton)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
            self.trackingArea = nil
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func layout() {
        super.layout()

        let buttonSide = min(28, max(22, bounds.height - 6))
        let buttonY = (bounds.height - buttonSide) / 2
        let horizontalInset: CGFloat = 4
        let gap = max(4, (bounds.width - horizontalInset * 2 - buttonSide * 3) / 2)

        closeButton.frame = NSRect(
            x: horizontalInset,
            y: buttonY,
            width: buttonSide,
            height: buttonSide
        )
        textEditButton.frame = NSRect(
            x: closeButton.frame.maxX + gap,
            y: buttonY,
            width: buttonSide,
            height: buttonSide
        )
        editButton.frame = NSRect(
            x: textEditButton.frame.maxX + gap,
            y: buttonY,
            width: buttonSide,
            height: buttonSide
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: bounds.height / 2,
            yRadius: bounds.height / 2
        )
        AdaptiveChrome.toolbarBackground.setFill()
        path.fill()

        AdaptiveChrome.border.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onPointerEvent?(event)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onPointerEvent?(event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onPointerEvent?(event)
    }

    override func mouseDown(with event: NSEvent) {
        onPointerEvent?(event)
    }

    override func mouseDragged(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {}

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func editTextTapped() {
        onEditText?()
    }

    @objc private func editTapped() {
        onEdit?()
    }
}
