import AppKit
import Carbon

/// App-drawn settings dropdown matching the visual language used by aulycMail.
///
/// The selected value, target/action wiring, represented objects, and item API
/// still come from `NSPopUpButton`; only the closed control and expanded list
/// are rendered by the app.
final class SettingsPopUpButton: NSPopUpButton {
    private static let minimumWidth: CGFloat = 120
    private static let controlHeight: CGFloat = 34
    private static let optionHeight: CGFloat = 36
    private static let menuPadding: CGFloat = 4

    private var hoverTrackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet {
            if oldValue != isHovered {
                needsDisplay = true
            }
        }
    }

    private var dropdownPanel: SettingsDropdownPanel?
    private var optionViews: [SettingsDropdownOptionView] = []
    private var scrollBoundsObserver: NSObjectProtocol?
    private var anchorMouseDownMonitor: Any?

    override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        super.init(frame: buttonFrame, pullsDown: flag)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        dismissDropdown(restoreFocus: false)
    }

    private func commonInit() {
        isBordered = false
        focusRingType = .none
        wantsLayer = true
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    override var intrinsicContentSize: NSSize {
        let nativeSize = super.intrinsicContentSize
        return NSSize(
            width: max(Self.minimumWidth, nativeSize.width),
            height: Self.controlHeight
        )
    }

    override var isEnabled: Bool {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { isEnabled }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        needsDisplay = true
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        needsDisplay = true
        return resigned
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        hoverTrackingArea = area
        addTrackingArea(area)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        window?.makeFirstResponder(self)
        toggleDropdown()
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        switch Int(event.keyCode) {
        case kVK_Return, kVK_Space, kVK_DownArrow, kVK_UpArrow:
            showDropdown()
        case kVK_Escape:
            dismissDropdown(restoreFocus: true)
        default:
            super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        toggleDropdown()
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let isFocused = window?.firstResponder === self
        let backgroundAlpha: CGFloat
        if !isEnabled {
            backgroundAlpha = 0.025
        } else if dropdownPanel?.isVisible == true || isHovered {
            backgroundAlpha = 0.085
        } else {
            backgroundAlpha = 0.055
        }

        let background = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        NSColor.white.withAlphaComponent(backgroundAlpha).setFill()
        background.fill()

        (isFocused ? SettingsPalette.accent.withAlphaComponent(0.72) : NSColor.white.withAlphaComponent(0.16)).setStroke()
        background.lineWidth = isFocused ? 1.25 : 1
        background.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = .left
        let textColor = isEnabled
            ? SettingsPalette.primaryText
            : SettingsPalette.primaryText.withAlphaComponent(0.38)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: textColor,
            .paragraphStyle: paragraph,
        ]
        let title = titleOfSelectedItem ?? ""
        let titleSize = (title as NSString).size(withAttributes: attributes)
        let titleRect = NSRect(
            x: rect.minX + 12,
            y: floor(rect.midY - titleSize.height / 2),
            width: max(0, rect.width - 42),
            height: ceil(titleSize.height)
        )
        (title as NSString).draw(in: titleRect, withAttributes: attributes)

        drawChevron(
            center: NSPoint(x: rect.maxX - 15, y: rect.midY),
            color: textColor.withAlphaComponent(0.62)
        )
    }

    private func drawChevron(center: NSPoint, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x - 4, y: center.y + 2))
        path.line(to: NSPoint(x: center.x, y: center.y - 2))
        path.line(to: NSPoint(x: center.x + 4, y: center.y + 2))
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        color.setStroke()
        path.stroke()
    }

    private func toggleDropdown() {
        if dropdownPanel?.isVisible == true {
            dismissDropdown(restoreFocus: true)
        } else {
            showDropdown()
        }
    }

    private func showDropdown() {
        guard isEnabled, let parentWindow = window else { return }
        dismissDropdown(restoreFocus: false)

        let visibleItems = itemArray.enumerated().filter { _, item in
            !item.isSeparatorItem && !item.isHidden
        }
        guard !visibleItems.isEmpty else { return }

        let panelWidth = max(bounds.width, Self.minimumWidth)
        let panelHeight = Self.menuPadding * 2 + Self.optionHeight * CGFloat(visibleItems.count)
        let panelSize = NSSize(width: panelWidth, height: panelHeight)

        let panel = SettingsDropdownPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            owner: self
        )
        panel.appearance = effectiveAppearance

        let content = NSView(frame: NSRect(origin: .zero, size: panelSize))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(calibratedWhite: 0.145, alpha: 0.99).cgColor
        content.layer?.cornerRadius = 8
        content.layer?.cornerCurve = .continuous
        content.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        content.layer?.borderWidth = 1
        content.layer?.masksToBounds = true
        panel.contentView = content

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        optionViews = visibleItems.map { index, item in
            let option = SettingsDropdownOptionView(
                title: item.title,
                itemIndex: index,
                isChosen: indexOfSelectedItem == index,
                owner: self
            )
            option.isEnabled = item.isEnabled
            stack.addArrangedSubview(option)
            option.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            option.heightAnchor.constraint(equalToConstant: Self.optionHeight).isActive = true
            return option
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Self.menuPadding),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.menuPadding),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Self.menuPadding),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Self.menuPadding),
        ])

        dropdownPanel = panel
        positionDropdown(panel, size: panelSize, relativeTo: parentWindow)
        startObservingScrollPosition()
        startMonitoringAnchorClicks()
        parentWindow.addChildWindow(panel, ordered: .above)
        panel.makeKeyAndOrderFront(nil)
        if let selected = optionViews.first(where: { $0.itemIndex == indexOfSelectedItem && $0.isEnabled })
            ?? optionViews.first(where: \.isEnabled)
        {
            panel.makeFirstResponder(selected)
        }
        needsDisplay = true
    }

    private func startObservingScrollPosition() {
        stopObservingScrollPosition()
        guard let clipView = enclosingScrollView?.contentView else { return }
        clipView.postsBoundsChangedNotifications = true
        scrollBoundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            self?.updateDropdownPositionAfterScroll()
        }
    }

    private func stopObservingScrollPosition() {
        guard let scrollBoundsObserver else { return }
        NotificationCenter.default.removeObserver(scrollBoundsObserver)
        self.scrollBoundsObserver = nil
    }

    private func startMonitoringAnchorClicks() {
        stopMonitoringAnchorClicks()
        anchorMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self,
                  self.dropdownPanel?.isVisible == true,
                  event.window === self.window
            else {
                return event
            }
            let point = self.convert(event.locationInWindow, from: nil)
            guard self.bounds.contains(point) else { return event }
            self.dismissDropdown(restoreFocus: true)
            return nil
        }
    }

    private func stopMonitoringAnchorClicks() {
        guard let anchorMouseDownMonitor else { return }
        NSEvent.removeMonitor(anchorMouseDownMonitor)
        self.anchorMouseDownMonitor = nil
    }

    private func updateDropdownPositionAfterScroll() {
        guard let panel = dropdownPanel, let parentWindow = window else {
            dismissDropdown(restoreFocus: false)
            return
        }
        guard isVisibleInEnclosingScrollView else {
            dismissDropdown(restoreFocus: false)
            return
        }
        positionDropdown(panel, size: panel.frame.size, relativeTo: parentWindow)
    }

    private var isVisibleInEnclosingScrollView: Bool {
        guard let scrollView = enclosingScrollView,
              let documentView = scrollView.documentView
        else {
            return !isHiddenOrHasHiddenAncestor
        }
        let controlRect = convert(bounds, to: documentView)
        return controlRect.intersects(scrollView.contentView.bounds)
    }

    private func positionDropdown(_ panel: NSPanel, size panelSize: NSSize, relativeTo parentWindow: NSWindow) {
        let controlRect = parentWindow.convertToScreen(convert(bounds, to: nil))
        let visibleFrame = (parentWindow.screen ?? NSScreen.main)?.visibleFrame ?? controlRect
        var origin = NSPoint(
            x: controlRect.minX,
            y: controlRect.minY - panelSize.height - 4
        )
        if origin.y < visibleFrame.minY + 8 {
            origin.y = controlRect.maxY + 4
        }
        origin.x = min(max(origin.x, visibleFrame.minX + 8), visibleFrame.maxX - panelSize.width - 8)
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
    }

    fileprivate func selectDropdownItem(at index: Int) {
        guard itemArray.indices.contains(index), itemArray[index].isEnabled else { return }
        selectItem(at: index)
        dismissDropdown(restoreFocus: true)
        needsDisplay = true
        sendAction(action, to: target)
    }

    fileprivate func moveDropdownFocus(from itemIndex: Int, direction: Int) {
        guard let current = optionViews.firstIndex(where: { $0.itemIndex == itemIndex }),
              !optionViews.isEmpty,
              let panel = dropdownPanel
        else {
            return
        }

        var next = current
        for _ in optionViews.indices {
            next = (next + direction + optionViews.count) % optionViews.count
            if optionViews[next].isEnabled {
                panel.makeFirstResponder(optionViews[next])
                return
            }
        }
    }

    fileprivate func cancelDropdown() {
        dismissDropdown(restoreFocus: true)
    }

    fileprivate func dropdownPanelDidResign(_ panel: SettingsDropdownPanel) {
        guard dropdownPanel === panel else { return }
        dismissDropdown(restoreFocus: false)
    }

    private func dismissDropdown(restoreFocus: Bool) {
        stopObservingScrollPosition()
        stopMonitoringAnchorClicks()
        guard let panel = dropdownPanel else { return }
        dropdownPanel = nil
        optionViews.removeAll()
        panel.prepareToClose()
        let parentWindow = panel.parent
        parentWindow?.removeChildWindow(panel)
        panel.orderOut(nil)
        if restoreFocus {
            parentWindow?.makeKey()
            parentWindow?.makeFirstResponder(self)
        }
        needsDisplay = true
    }
}

private final class SettingsDropdownPanel: NSPanel {
    private weak var owner: SettingsPopUpButton?
    private var isClosing = false

    init(contentRect: NSRect, owner: SettingsPopUpButton) {
        self.owner = owner
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.transient, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        guard !isClosing else { return }
        owner?.dropdownPanelDidResign(self)
    }

    override func cancelOperation(_ sender: Any?) {
        owner?.cancelDropdown()
    }

    func prepareToClose() {
        isClosing = true
        owner = nil
    }
}

private final class SettingsDropdownOptionView: NSControl {
    let itemIndex: Int

    private weak var owner: SettingsPopUpButton?
    private let titleLabel = NSTextField(labelWithString: "")
    private let checkView = NSImageView()
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet { applyAppearance() }
    }
    private let isChosen: Bool

    init(title: String, itemIndex: Int, isChosen: Bool, owner: SettingsPopUpButton) {
        self.itemIndex = itemIndex
        self.isChosen = isChosen
        self.owner = owner
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.cornerCurve = .continuous

        setAccessibilityElement(true)
        setAccessibilityRole(.menuItem)
        setAccessibilityLabel(title)
        setAccessibilitySelected(isChosen)

        titleLabel.stringValue = title
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        checkView.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        checkView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        checkView.imageScaling = .scaleProportionallyDown
        checkView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkView.leadingAnchor, constant: -8),

            checkView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            checkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkView.widthAnchor.constraint(equalToConstant: 14),
            checkView.heightAnchor.constraint(equalToConstant: 14),
        ])

        applyAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { isEnabled }

    override var isEnabled: Bool {
        didSet { applyAppearance() }
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
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        hoverTrackingArea = area
        addTrackingArea(area)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        owner?.selectDropdownItem(at: itemIndex)
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        switch Int(event.keyCode) {
        case kVK_Return, kVK_Space:
            owner?.selectDropdownItem(at: itemIndex)
        case kVK_DownArrow:
            owner?.moveDropdownFocus(from: itemIndex, direction: 1)
        case kVK_UpArrow:
            owner?.moveDropdownFocus(from: itemIndex, direction: -1)
        case kVK_Escape:
            owner?.cancelDropdown()
        default:
            super.keyDown(with: event)
        }
    }

    private func applyAppearance() {
        let isFocused = window?.firstResponder === self
        let highlighted = isEnabled && (isHovered || isFocused || isChosen)
        layer?.backgroundColor = highlighted
            ? NSColor.white.withAlphaComponent(isChosen ? 0.10 : 0.075).cgColor
            : NSColor.clear.cgColor
        alphaValue = isEnabled ? 1 : 0.42
        titleLabel.textColor = SettingsPalette.primaryText
        checkView.contentTintColor = SettingsPalette.primaryText
        checkView.isHidden = !isChosen
    }
}
