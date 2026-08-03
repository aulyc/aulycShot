import AppKit

final class ImageMergeDropdownButton: NSButton {
    private(set) var optionTitles: [String] = []
    private(set) var selectedIndex = 0
    var opensUpward = false
    var onSelection: ((Int) -> Void)?

    private static weak var expandedDropdown: ImageMergeDropdownButton?

    private var controlAccessibilityLabel = ""
    private let valueLabel = NSTextField(labelWithString: "")
    private let chevronView = NSImageView()
    private var dropdownPanel: NSPanel?
    private var dismissalMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    convenience init() {
        self.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        MainActor.assumeIsolated {
            closeDropdownPanel()
        }
    }

    func configure(options: [String], accessibilityLabel: String) {
        optionTitles = options
        controlAccessibilityLabel = accessibilityLabel
        selectedIndex = min(selectedIndex, max(options.count - 1, 0))
        setAccessibilityLabel(accessibilityLabel)
        updateTitle()
    }

    func selectItem(at index: Int) {
        guard optionTitles.indices.contains(index) else { return }
        selectedIndex = index
        updateTitle()
    }

    func dismissDropdown() {
        closeDropdownPanel()
    }

    func dropdownPanelFrame(
        buttonScreenFrame: NSRect,
        optionCount: Int
    ) -> NSRect {
        let rowHeight: CGFloat = 38
        let rowSpacing: CGFloat = 2
        let verticalPadding: CGFloat = 12
        let rowsHeight = CGFloat(optionCount) * rowHeight
        let spacingHeight = CGFloat(max(optionCount - 1, 0)) * rowSpacing
        let panelHeight = rowsHeight + spacingHeight + verticalPadding
        let panelY = opensUpward
            ? buttonScreenFrame.maxY + 6
            : buttonScreenFrame.minY - panelHeight - 6
        return NSRect(
            x: buttonScreenFrame.minX,
            y: panelY,
            width: buttonScreenFrame.width,
            height: panelHeight
        )
    }

    func makeDropdownPanel(buttonScreenFrame: NSRect) -> NSPanel {
        let panelFrame = dropdownPanelFrame(
            buttonScreenFrame: buttonScreenFrame,
            optionCount: optionTitles.count
        )
        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.transient, .fullScreenAuxiliary]

        let content = dropdownPanelContent()
        content.frame = NSRect(origin: .zero, size: panelFrame.size)
        content.autoresizingMask = [.width, .height]
        panel.contentView = content

        // Assigning a content view can let its intrinsic width influence the
        // borderless panel. Reapply the requested frame so the menu remains
        // exactly as wide as its selector.
        panel.setFrame(panelFrame, display: false)
        panel.contentView?.frame = NSRect(origin: .zero, size: panelFrame.size)
        return panel
    }

    var usesDownwardChevron: Bool {
        true
    }

    var selectorFont: NSFont? {
        valueLabel.font
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        controlSize = .small
        title = ""
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .systemFont(ofSize: 12, weight: .medium)
        valueLabel.textColor = .labelColor
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.maximumNumberOfLines = 1
        addSubview(valueLabel)

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.image = NSImage(
            systemSymbolName: "chevron.down",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        )
        chevronView.contentTintColor = .secondaryLabelColor
        chevronView.imageScaling = .scaleProportionallyDown
        addSubview(chevronView)

        NSLayoutConstraint.activate([
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronView.leadingAnchor, constant: -6),
            chevronView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            chevronView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 10),
            chevronView.heightAnchor.constraint(equalToConstant: 10),
        ])

        target = self
        action = #selector(toggleDropdownPanel)
        updateAppearance()
    }

    private func updateTitle() {
        guard optionTitles.indices.contains(selectedIndex) else {
            valueLabel.stringValue = ""
            return
        }
        let selectedTitle = optionTitles[selectedIndex]
        valueLabel.stringValue = selectedTitle
        toolTip = nil
        setAccessibilityValue(selectedTitle)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            closeDropdownPanel()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    private func updateAppearance() {
        let fill = dropdownPanel == nil
            ? AdaptiveChrome.subtleFill
            : NSColor.controlAccentColor.withAlphaComponent(0.18)
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(
            fill,
            for: effectiveAppearance
        )
    }

    @objc private func toggleDropdownPanel() {
        if dropdownPanel != nil {
            closeDropdownPanel()
        } else {
            showDropdownPanel()
        }
    }

    private func showDropdownPanel() {
        guard !optionTitles.isEmpty,
              let hostWindow = window
        else {
            return
        }

        Self.expandedDropdown?.closeDropdownPanel()

        let buttonFrameInWindow = convert(bounds, to: nil)
        let buttonScreenFrame = hostWindow.convertToScreen(buttonFrameInWindow)
        let panel = makeDropdownPanel(buttonScreenFrame: buttonScreenFrame)
        panel.level = NSWindow.Level(rawValue: hostWindow.level.rawValue + 1)
        panel.appearance = effectiveAppearance

        dropdownPanel = panel
        Self.expandedDropdown = self
        hostWindow.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        installDismissalMonitor()
        updateAppearance()
    }

    private func dropdownPanelContent() -> NSView {
        let content = ImageMergeDropdownPanelView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        for (index, optionTitle) in optionTitles.enumerated() {
            let row = ImageMergeDropdownOptionButton(
                title: optionTitle,
                index: index,
                selected: index == selectedIndex
            )
            row.onSelect = { [weak self] selectedIndex in
                self?.selectDropdownItem(at: selectedIndex)
            }
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -6),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -6),
        ])
        return content
    }

    private func installDismissalMonitor() {
        dismissalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                closeDropdownPanel()
                return nil
            }
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                let location = NSEvent.mouseLocation
                let insidePanel = dropdownPanel?.frame.contains(location) == true
                let insideButton = currentButtonScreenFrame()?.contains(location) == true
                if !insidePanel, !insideButton {
                    closeDropdownPanel()
                }
            }
            return event
        }
    }

    private func currentButtonScreenFrame() -> NSRect? {
        guard let hostWindow = window else { return nil }
        return hostWindow.convertToScreen(convert(bounds, to: nil))
    }

    private func closeDropdownPanel() {
        if let monitor = dismissalMonitor {
            NSEvent.removeMonitor(monitor)
            dismissalMonitor = nil
        }
        if let panel = dropdownPanel {
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
            dropdownPanel = nil
        }
        if Self.expandedDropdown === self {
            Self.expandedDropdown = nil
        }
        updateAppearance()
    }

    private func selectDropdownItem(at index: Int) {
        selectItem(at: index)
        onSelection?(selectedIndex)
        closeDropdownPanel()
    }
}

private final class ImageMergeDropdownPanelView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.masksToBounds = true
        updateAppearance()
    }

    private func updateAppearance() {
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(
            AdaptiveChrome.popoverBackground,
            for: effectiveAppearance
        )
        layer?.borderColor = AdaptiveChrome.resolvedCGColor(
            .separatorColor,
            for: effectiveAppearance
        )
    }
}

private final class ImageMergeDropdownOptionButton: NSButton {
    let optionIndex: Int
    var onSelect: ((Int) -> Void)?

    private let optionLabel: NSTextField
    private let checkmarkView = NSImageView()
    private let isCurrentSelection: Bool
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    init(title: String, index: Int, selected: Bool) {
        optionIndex = index
        optionLabel = NSTextField(labelWithString: title)
        isCurrentSelection = selected
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        title = ""
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        target = self
        action = #selector(clicked)

        optionLabel.translatesAutoresizingMaskIntoConstraints = false
        optionLabel.font = .systemFont(ofSize: 12, weight: .medium)
        optionLabel.textColor = .labelColor
        optionLabel.lineBreakMode = .byTruncatingTail
        addSubview(optionLabel)

        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.image = NSImage(
            systemSymbolName: "checkmark",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        )
        checkmarkView.contentTintColor = .labelColor
        checkmarkView.imageScaling = .scaleProportionallyDown
        checkmarkView.isHidden = !isCurrentSelection
        addSubview(checkmarkView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 38),
            optionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            optionLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            optionLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkView.leadingAnchor, constant: -8),
            checkmarkView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            checkmarkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 14),
            checkmarkView.heightAnchor.constraint(equalToConstant: 14),
        ])
        updateAppearance()
    }

    private func updateAppearance() {
        let fill: NSColor
        if isCurrentSelection {
            fill = AdaptiveChrome.subtleFill
        } else if isHovered {
            fill = NSColor.labelColor.withAlphaComponent(0.08)
        } else {
            fill = .clear
        }
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(
            fill,
            for: effectiveAppearance
        )
    }

    @objc private func clicked() {
        onSelect?(optionIndex)
    }
}
