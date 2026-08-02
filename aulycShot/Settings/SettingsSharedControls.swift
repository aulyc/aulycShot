import AppKit

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

final class HairlineSeparatorView: NSView {
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

final class CardView: NSView {
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
