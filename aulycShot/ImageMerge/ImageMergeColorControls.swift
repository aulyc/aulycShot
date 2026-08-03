import AppKit

final class ImageMergeColorPaletteButton: NSButton {
    static let paletteColumns = 6
    static let editIconSymbolName = "square.and.pencil"
    static let editIconPointSize: CGFloat = 10
    static let paletteHexColors = [
        "#7A1711", "#7A4400", "#7A6000", "#135E26", "#005E59", "#00377A",
        "#BE2921", "#BE6D00", "#BE9700", "#249340", "#00938C", "#0059BE",
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#007AFF",
        "#FF8373", "#FFB771", "#FFDD7A", "#81D98D", "#7AD9D1", "#64A6FF",
        "#FFC4B9", "#FFDCBB", "#FFEFC1", "#C3EDC6", "#C1ECE8", "#B2D4FF",
        "#000000", "#48484A", "#8E8E93", "#C7C7CC", "#E5E5EA", "#FFFFFF",
    ]
    static let paletteColors: [NSColor] = paletteHexColors.compactMap(
        ImageMergeDocument.color(fromHex:)
    )

    private static weak var expandedPalette: ImageMergeColorPaletteButton?
    private static let swatchSize: CGFloat = 22
    private static let swatchSpacing: CGFloat = 4
    private static let panelPadding: CGFloat = 10
    private static let panelGap: CGFloat = 8

    private(set) var selectedColor: NSColor = .white
    var onSelection: ((NSColor) -> Void)?

    private var palettePanel: NSPanel?
    private var dismissalMonitor: Any?

    override var isEnabled: Bool {
        didSet {
            if !isEnabled {
                closePalettePanel()
            }
            alphaValue = 1
            updateAppearance()
        }
    }

    override var alignmentRectInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

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
            closePalettePanel()
        }
    }

    func configure(color: NSColor, accessibilityLabel: String) {
        setAccessibilityLabel(accessibilityLabel)
        toolTip = nil
        selectColor(color)
    }

    func selectColor(_ color: NSColor) {
        selectedColor = Self.nearestPaletteColor(to: color)
        setAccessibilityValue(
            ImageMergeDocument.hexString(from: selectedColor)
        )
        updateAppearance()
    }

    func selectPaletteColor(at index: Int) {
        guard Self.paletteColors.indices.contains(index) else { return }
        selectedColor = Self.paletteColors[index]
        setAccessibilityValue(
            ImageMergeDocument.hexString(from: selectedColor)
        )
        updateAppearance()
        onSelection?(selectedColor)
        closePalettePanel()
    }

    func dismissPalette() {
        closePalettePanel()
    }

    func palettePanelFrame(buttonScreenFrame: NSRect) -> NSRect {
        let rows = Int(
            ceil(Double(Self.paletteColors.count) / Double(Self.paletteColumns))
        )
        let width = Self.panelPadding * 2
            + CGFloat(Self.paletteColumns) * Self.swatchSize
            + CGFloat(Self.paletteColumns - 1) * Self.swatchSpacing
        let height = Self.panelPadding * 2
            + CGFloat(rows) * Self.swatchSize
            + CGFloat(max(rows - 1, 0)) * Self.swatchSpacing
        return NSRect(
            x: buttonScreenFrame.midX - width / 2,
            y: buttonScreenFrame.maxY + Self.panelGap,
            width: width,
            height: height
        )
    }

    func makePalettePanel(buttonScreenFrame: NSRect) -> NSPanel {
        let panelFrame = palettePanelFrame(buttonScreenFrame: buttonScreenFrame)
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

        let content = palettePanelContent()
        content.frame = NSRect(origin: .zero, size: panelFrame.size)
        content.autoresizingMask = [.width, .height]
        panel.contentView = content
        panel.setFrame(panelFrame, display: false)
        panel.contentView?.frame = NSRect(origin: .zero, size: panelFrame.size)
        return panel
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        title = ""
        isBordered = false
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        image = NSImage(
            systemSymbolName: Self.editIconSymbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(
                pointSize: Self.editIconPointSize,
                weight: .medium
            )
        )
        contentTintColor = .secondaryLabelColor
        toolTip = nil
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.cornerCurve = .continuous
        target = self
        action = #selector(togglePalettePanel)
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            closePalettePanel()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    @objc private func togglePalettePanel() {
        if palettePanel == nil {
            showPalettePanel()
        } else {
            closePalettePanel()
        }
    }

    private func showPalettePanel() {
        guard isEnabled, let hostWindow = window else { return }

        Self.expandedPalette?.closePalettePanel()

        let buttonFrameInWindow = convert(bounds, to: nil)
        let buttonScreenFrame = hostWindow.convertToScreen(buttonFrameInWindow)
        let panel = makePalettePanel(buttonScreenFrame: buttonScreenFrame)
        if let visibleFrame = hostWindow.screen?.visibleFrame {
            var panelFrame = panel.frame
            panelFrame.origin.x = min(
                max(panelFrame.minX, visibleFrame.minX + 8),
                visibleFrame.maxX - panelFrame.width - 8
            )
            panelFrame.origin.y = min(
                max(panelFrame.minY, visibleFrame.minY + 8),
                visibleFrame.maxY - panelFrame.height - 8
            )
            panel.setFrame(panelFrame, display: false)
        }
        panel.level = NSWindow.Level(rawValue: hostWindow.level.rawValue + 1)
        panel.appearance = effectiveAppearance

        palettePanel = panel
        Self.expandedPalette = self
        hostWindow.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        installDismissalMonitor()
        updateAppearance()
    }

    private func palettePanelContent() -> NSView {
        let content = ImageMergeColorPalettePanelView()
        let grid = NSStackView()
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.distribution = .fillEqually
        grid.spacing = Self.swatchSpacing
        grid.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(grid)

        for rowStart in stride(
            from: 0,
            to: Self.paletteColors.count,
            by: Self.paletteColumns
        ) {
            let rowEnd = min(
                rowStart + Self.paletteColumns,
                Self.paletteColors.count
            )
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.distribution = .fillEqually
            row.spacing = Self.swatchSpacing
            for index in rowStart..<rowEnd {
                let swatch = ImageMergeColorSwatchButton(
                    color: Self.paletteColors[index],
                    selected: Self.colorsMatch(
                        Self.paletteColors[index],
                        selectedColor
                    )
                )
                swatch.onSelect = { [weak self] in
                    self?.selectPaletteColor(at: index)
                }
                row.addArrangedSubview(swatch)
                NSLayoutConstraint.activate([
                    swatch.widthAnchor.constraint(
                        equalToConstant: Self.swatchSize
                    ),
                    swatch.heightAnchor.constraint(
                        equalToConstant: Self.swatchSize
                    ),
                ])
            }
            grid.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(
                equalTo: content.topAnchor,
                constant: Self.panelPadding
            ),
            grid.leadingAnchor.constraint(
                equalTo: content.leadingAnchor,
                constant: Self.panelPadding
            ),
            grid.trailingAnchor.constraint(
                equalTo: content.trailingAnchor,
                constant: -Self.panelPadding
            ),
            grid.bottomAnchor.constraint(
                equalTo: content.bottomAnchor,
                constant: -Self.panelPadding
            ),
        ])
        return content
    }

    private func installDismissalMonitor() {
        dismissalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                closePalettePanel()
                return nil
            }
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                let location = NSEvent.mouseLocation
                let insidePanel = palettePanel?.frame.contains(location) == true
                let insideButton = currentButtonScreenFrame()?.contains(location) == true
                if !insidePanel, !insideButton {
                    closePalettePanel()
                }
            }
            return event
        }
    }

    private func currentButtonScreenFrame() -> NSRect? {
        guard let hostWindow = window else { return nil }
        return hostWindow.convertToScreen(convert(bounds, to: nil))
    }

    private func closePalettePanel() {
        if let dismissalMonitor {
            NSEvent.removeMonitor(dismissalMonitor)
            self.dismissalMonitor = nil
        }
        if let palettePanel {
            palettePanel.parent?.removeChildWindow(palettePanel)
            palettePanel.orderOut(nil)
            self.palettePanel = nil
        }
        if Self.expandedPalette === self {
            Self.expandedPalette = nil
        }
        updateAppearance()
    }

    private func updateAppearance() {
        let fill = isEnabled ? selectedColor : NSColor.clear
        contentTintColor = isEnabled
            ? Self.editIconColor(for: selectedColor)
            : .disabledControlTextColor
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(
            fill,
            for: effectiveAppearance
        )
    }

    private static func editIconColor(for color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return .white }

        func linearized(_ component: CGFloat) -> CGFloat {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        let luminance =
            0.2126 * linearized(rgb.redComponent)
            + 0.7152 * linearized(rgb.greenComponent)
            + 0.0722 * linearized(rgb.blueComponent)
        return luminance > 0.18 ? .black : .white
    }

    private static func nearestPaletteColor(to color: NSColor) -> NSColor {
        paletteColors.min {
            colorDistance($0, color) < colorDistance($1, color)
        } ?? .white
    }

    private static func colorsMatch(_ lhs: NSColor, _ rhs: NSColor) -> Bool {
        colorDistance(lhs, rhs) < 0.0001
    }

    private static func colorDistance(_ lhs: NSColor, _ rhs: NSColor) -> CGFloat {
        guard let left = lhs.usingColorSpace(.sRGB),
              let right = rhs.usingColorSpace(.sRGB)
        else {
            return .greatestFiniteMagnitude
        }
        let red = left.redComponent - right.redComponent
        let green = left.greenComponent - right.greenComponent
        let blue = left.blueComponent - right.blueComponent
        return red * red + green * green + blue * blue
    }
}

final class ImageMergeColorSwatchButton: NSButton {
    static let selectionSymbolName = "checkmark"

    let swatchColor: NSColor
    let isCurrentSelection: Bool
    var onSelect: (() -> Void)?

    init(color: NSColor, selected: Bool) {
        swatchColor = color
        isCurrentSelection = selected
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var alignmentRectInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        title = ""
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = swatchColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        if isCurrentSelection {
            image = NSImage(
                systemSymbolName: Self.selectionSymbolName,
                accessibilityDescription: nil
            )?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize: 12,
                    weight: .bold
                )
            )
            imagePosition = .imageOnly
            imageScaling = .scaleProportionallyDown
            contentTintColor = .black
        }
        target = self
        action = #selector(clicked)
        setAccessibilityLabel(
            ImageMergeDocument.hexString(from: swatchColor)
        )
        toolTip = nil
    }

    @objc private func clicked() {
        onSelect?()
    }
}

private final class ImageMergeColorPalettePanelView: NSView {
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
