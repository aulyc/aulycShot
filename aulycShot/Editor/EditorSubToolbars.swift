import AppKit

// MARK: - Color + Size Sub-toolbar

enum ShapeStrokePreviewShape {
    case rectangle
    case ellipse
}

class ColorSizeSubToolbar: NSView {
    var currentColor: NSColor = EditorStyleDefaults.primaryColor
    var currentSize: CGFloat = 3.0
    var currentArrowStyle: ArrowStyle?
    var currentShapeFillMode: ShapeFillMode?
    var currentShapeStrokeStyle: ShapeStrokeStyle?
    var onColorChanged: ((NSColor) -> Void)?
    var onSizeBegan: (() -> Void)?
    var onSizeChanged: ((CGFloat) -> Void)?
    var onSizeEnded: (() -> Void)?
    var onArrowStyleChanged: ((ArrowStyle) -> Void)?
    var onShapeFillModeChanged: ((ShapeFillMode) -> Void)?
    var onShapeStrokeStyleChanged: ((ShapeStrokeStyle) -> Void)?

    private var sizeSlider: HUDSlider?
    private var colorButtons: [NSView] = []
    private var arrowStyleButtons: [ArrowStyleButtonView] = []
    private var shapeFillModeControl: ShapeFillModeSegmentedControl?
    private var shapeStrokeStyleButtons: [ShapeStrokeStyleButtonView] = []

    private let sizes: [CGFloat]
    private let sizeMinValue: CGFloat
    private let sizeMaxValue: CGFloat
    private let showsShapeFillModes: Bool
    private let showsShapeStrokeStyles: Bool
    private let shapeStrokePreviewShape: ShapeStrokePreviewShape
    private let colors: [NSColor] = EditorStyleDefaults.paletteColors

    private static let leadingPad: CGFloat = 12
    private static let sizeSliderWidth: CGFloat = 136
    private static let swatchSize: CGFloat = 18
    private static let swatchGap: CGFloat = 5
    private static let separatorGap: CGFloat = 6
    private static let arrowStyleGap: CGFloat = 8
    private static let arrowStyleButtonWidth: CGFloat = 27
    private static let arrowStyleButtonHeight: CGFloat = 20
    private static let arrowStyleButtonGap: CGFloat = 4
    private static let shapeButtonWidth: CGFloat = 27
    private static let shapeButtonHeight: CGFloat = 20
    private static let trailingPad: CGFloat = 12
    private static var baseColorCount: CGFloat { CGFloat(EditorStyleDefaults.paletteColors.count) }

    static func preferredWidth(
        sizes: [CGFloat],
        showsShapeFillModes: Bool,
        showsArrowStyles: Bool = false,
        showsShapeStrokeStyles: Bool = false,
        shapeStrokePreviewShape: ShapeStrokePreviewShape = .rectangle
    ) -> CGFloat {
        var x = leadingPad
        if !sizes.isEmpty {
            x += sizeSliderWidth
            x += 8 + 1 + 9
        }

        let colorCount = baseColorCount
        x += colorCount * swatchSize + max(colorCount - 1, 0) * swatchGap

        if showsArrowStyles {
            let styleCount = CGFloat(ArrowStyle.allCases.count)
            x += separatorGap + 1 + arrowStyleGap
            x += styleCount * arrowStyleButtonWidth + max(styleCount - 1, 0) * arrowStyleButtonGap
        }

        if showsShapeFillModes {
            x += separatorGap + 1 + arrowStyleGap
            x += ShapeFillModeSegmentedControl.preferredWidth()
        }

        if showsShapeStrokeStyles {
            let styleCount = CGFloat(shapeStrokeStyles(for: shapeStrokePreviewShape).count)
            x += separatorGap + 1 + arrowStyleGap
            x += styleCount * shapeButtonWidth + max(styleCount - 1, 0) * arrowStyleButtonGap
        }

        return ceil(x + trailingPad)
    }

    private static func shapeStrokeStyles(for previewShape: ShapeStrokePreviewShape) -> [ShapeStrokeStyle] {
        switch previewShape {
        case .rectangle:
            return ShapeStrokeStyle.allCases
        case .ellipse:
            return ShapeStrokeStyle.allCases.filter { $0 != .rounded }
        }
    }

    init(
        frame: NSRect,
        sizes: [CGFloat] = [2, 4, 6],
        currentColor: NSColor = .red,
        currentSize: CGFloat = 3.0,
        sizeMinValue: CGFloat = CGFloat(Defaults.editorLineWidthMin),
        sizeMaxValue: CGFloat = CGFloat(Defaults.editorLineWidthMax),
        shapeFillMode: ShapeFillMode? = nil,
        shapeStrokeStyle: ShapeStrokeStyle? = nil,
        shapeStrokePreviewShape: ShapeStrokePreviewShape = .rectangle,
        arrowStyle: ArrowStyle? = nil
    ) {
        self.sizes = sizes
        self.sizeMinValue = sizeMinValue
        self.sizeMaxValue = max(sizeMinValue, sizeMaxValue)
        self.currentColor = currentColor
        self.currentSize = min(max(currentSize, sizeMinValue), max(sizeMinValue, sizeMaxValue))
        self.currentShapeFillMode = shapeFillMode
        self.currentShapeStrokeStyle = shapeStrokeStyle
        self.currentArrowStyle = arrowStyle
        self.showsShapeFillModes = shapeFillMode != nil
        self.showsShapeStrokeStyles = shapeStrokeStyle != nil
        self.shapeStrokePreviewShape = shapeStrokePreviewShape
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func setup() {
        var x: CGFloat = 12
        let midY = bounds.midY

        if !sizes.isEmpty {
            let slider = HUDSlider(
                value: Double(currentSize),
                minValue: Double(sizeMinValue),
                maxValue: Double(sizeMaxValue),
                target: self,
                action: #selector(sizeSliderChanged(_:))
            )
            slider.isContinuous = true
            slider.frame = NSRect(
                x: x,
                y: midY - HUDSlider.preferredHeight / 2,
                width: Self.sizeSliderWidth,
                height: HUDSlider.preferredHeight
            )
            slider.onEditingBegan = { [weak self] in self?.onSizeBegan?() }
            slider.onEditingEnded = { [weak self] in self?.onSizeEnded?() }
            addSubview(slider)
            sizeSlider = slider
            x += Self.sizeSliderWidth
        }

        // Separator only when there's a size section to separate from.
        if !sizes.isEmpty {
            x += 8
            let sep = AdaptiveSeparatorView(frame: NSRect(x: x, y: 6, width: 1, height: bounds.height - 12))
            addSubview(sep)
            x += 9
        }

        // Color swatches.
        let swatchSize: CGFloat = ColorSizeSubToolbar.swatchSize
        for (i, color) in colors.enumerated() {
            let swatch = ColorSwatchView(
                frame: NSRect(x: x, y: midY - swatchSize/2, width: swatchSize, height: swatchSize),
                color: color,
                isSelected: colorsMatch(color, currentColor)
            )
            swatch.itemIndex = i
            let click = NSClickGestureRecognizer(target: self, action: #selector(colorTapped(_:)))
            swatch.addGestureRecognizer(click)
            addSubview(swatch)
            colorButtons.append(swatch)
            x += swatchSize + ColorSizeSubToolbar.swatchGap
        }

        var lastSectionRightEdge = x - ColorSizeSubToolbar.swatchGap

        if currentArrowStyle != nil {
            let styleSepX = lastSectionRightEdge + ColorSizeSubToolbar.separatorGap
            let styleSep = AdaptiveSeparatorView(frame: NSRect(x: styleSepX, y: 6, width: 1, height: bounds.height - 12))
            addSubview(styleSep)

            x = styleSepX + 1 + ColorSizeSubToolbar.arrowStyleGap
            for style in ArrowStyle.allCases {
                let button = ArrowStyleButtonView(
                    frame: NSRect(
                        x: x,
                        y: midY - ColorSizeSubToolbar.arrowStyleButtonHeight / 2,
                        width: ColorSizeSubToolbar.arrowStyleButtonWidth,
                        height: ColorSizeSubToolbar.arrowStyleButtonHeight
                    ),
                    style: style,
                    isSelected: currentArrowStyle == style
                )
                let click = NSClickGestureRecognizer(target: self, action: #selector(arrowStyleTapped(_:)))
                button.addGestureRecognizer(click)
                addSubview(button)
                arrowStyleButtons.append(button)
                x += ColorSizeSubToolbar.arrowStyleButtonWidth + ColorSizeSubToolbar.arrowStyleButtonGap
            }
            lastSectionRightEdge = x - ColorSizeSubToolbar.arrowStyleButtonGap
        }

        if showsShapeFillModes {
            let fillSepX = lastSectionRightEdge + ColorSizeSubToolbar.separatorGap
            let fillSep = AdaptiveSeparatorView(frame: NSRect(x: fillSepX, y: 6, width: 1, height: bounds.height - 12))
            addSubview(fillSep)

            x = fillSepX + 1 + ColorSizeSubToolbar.arrowStyleGap
            let controlWidth = ShapeFillModeSegmentedControl.preferredWidth()
            let control = ShapeFillModeSegmentedControl(
                frame: NSRect(
                    x: x,
                    y: midY - ShapeFillModeSegmentedControl.preferredHeight / 2,
                    width: controlWidth,
                    height: ShapeFillModeSegmentedControl.preferredHeight
                ),
                selectedMode: currentShapeFillMode ?? .none
            )
            control.onSelect = { [weak self] mode in
                self?.currentShapeFillMode = mode
                self?.onShapeFillModeChanged?(mode)
            }
            addSubview(control)
            shapeFillModeControl = control
            lastSectionRightEdge = control.frame.maxX
        }

        if showsShapeStrokeStyles {
            let styleSepX = lastSectionRightEdge + ColorSizeSubToolbar.separatorGap
            let styleSep = AdaptiveSeparatorView(frame: NSRect(x: styleSepX, y: 6, width: 1, height: bounds.height - 12))
            addSubview(styleSep)

            x = styleSepX + 1 + ColorSizeSubToolbar.arrowStyleGap
            for style in Self.shapeStrokeStyles(for: shapeStrokePreviewShape) {
                let button = ShapeStrokeStyleButtonView(
                    frame: NSRect(
                        x: x,
                        y: midY - ColorSizeSubToolbar.shapeButtonHeight / 2,
                        width: ColorSizeSubToolbar.shapeButtonWidth,
                        height: ColorSizeSubToolbar.shapeButtonHeight
                    ),
                    style: style,
                    previewShape: shapeStrokePreviewShape,
                    isSelected: currentShapeStrokeStyle == style
                )
                let click = NSClickGestureRecognizer(target: self, action: #selector(shapeStrokeStyleTapped(_:)))
                button.addGestureRecognizer(click)
                addSubview(button)
                shapeStrokeStyleButtons.append(button)
                x += ColorSizeSubToolbar.shapeButtonWidth + ColorSizeSubToolbar.arrowStyleButtonGap
            }
        }
    }

    @objc private func sizeSliderChanged(_ sender: HUDSlider) {
        currentSize = min(max(CGFloat(sender.doubleValue), sizeMinValue), sizeMaxValue)
        onSizeChanged?(currentSize)
    }

    @objc private func colorTapped(_ gesture: NSGestureRecognizer) {
        guard let view = gesture.view as? ColorSwatchView else { return }
        let index = view.itemIndex
        let paletteColors = colors
        guard index < paletteColors.count else { return }
        currentColor = paletteColors[index]
        onColorChanged?(currentColor)
        updateColorSelection()
    }

    @objc private func arrowStyleTapped(_ gesture: NSGestureRecognizer) {
        guard let view = gesture.view as? ArrowStyleButtonView else { return }
        currentArrowStyle = view.style
        onArrowStyleChanged?(view.style)
        updateArrowStyleSelection()
    }

    @objc private func shapeStrokeStyleTapped(_ gesture: NSGestureRecognizer) {
        guard let view = gesture.view as? ShapeStrokeStyleButtonView else { return }
        currentShapeStrokeStyle = view.style
        onShapeStrokeStyleChanged?(view.style)
        updateShapeStrokeStyleSelection()
    }

    private func updateColorSelection() {
        let paletteColors = colors
        for (i, view) in colorButtons.enumerated() where i < paletteColors.count {
            (view as? ColorSwatchView)?.isSelected = colorsMatch(paletteColors[i], currentColor)
        }
    }

    private func updateArrowStyleSelection() {
        for view in arrowStyleButtons {
            view.isSelected = view.style == currentArrowStyle
        }
    }

    private func updateShapeFillModeSelection() {
        shapeFillModeControl?.selectedMode = currentShapeFillMode ?? .none
    }

    private func updateShapeStrokeStyleSelection() {
        for view in shapeStrokeStyleButtons {
            view.isSelected = view.style == currentShapeStrokeStyle
        }
    }

    private func colorsMatch(_ a: NSColor, _ b: NSColor) -> Bool {
        guard let ac = a.usingColorSpace(.deviceRGB), let bc = b.usingColorSpace(.deviceRGB) else { return false }
        return abs(ac.redComponent - bc.redComponent) < 0.01 &&
               abs(ac.greenComponent - bc.greenComponent) < 0.01 &&
               abs(ac.blueComponent - bc.blueComponent) < 0.01
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        AdaptiveChrome.toolbarBackground.setFill()
        path.fill()
    }
}

// MARK: - Mosaic Sub-toolbar

class MosaicSubToolbar: NSView {
    var currentBlockSize: CGFloat
    var onBlockSizeBegan: (() -> Void)?
    var onBlockSizeChanged: ((CGFloat) -> Void)?
    var onBlockSizeEnded: (() -> Void)?

    private var slider: HUDSlider!

    static let preferredWidth: CGFloat = 178
    private static let leadingPad: CGFloat = 12
    private static let sliderWidth: CGFloat = 154

    init(frame: NSRect, currentBlockSize: CGFloat) {
        self.currentBlockSize = Self.clampedBlockSize(currentBlockSize)
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func setup() {
        let x = Self.leadingPad
        let midY = bounds.midY

        let s = HUDSlider(
            value: Double(currentBlockSize),
            minValue: Defaults.mosaicBlockSizeMin,
            maxValue: Defaults.mosaicBlockSizeMax,
            target: self,
            action: #selector(sliderChanged(_:))
        )
        s.isContinuous = true
        s.frame = NSRect(
            x: x,
            y: midY - HUDSlider.preferredHeight / 2,
            width: Self.sliderWidth,
            height: HUDSlider.preferredHeight
        )
        s.toolTip = L10n.mosaicGranularity
        s.onEditingBegan = { [weak self] in self?.onBlockSizeBegan?() }
        s.onEditingEnded = { [weak self] in self?.onBlockSizeEnded?() }
        addSubview(s)
        slider = s
    }

    @objc private func sliderChanged(_ sender: HUDSlider) {
        let clamped = Self.clampedBlockSize(CGFloat(sender.doubleValue))
        currentBlockSize = clamped
        onBlockSizeChanged?(clamped)
    }

    private static func clampedBlockSize(_ size: CGFloat) -> CGFloat {
        max(
            CGFloat(Defaults.mosaicBlockSizeMin),
            min(CGFloat(Defaults.mosaicBlockSizeMax), size)
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        AdaptiveChrome.toolbarBackground.setFill()
        path.fill()
    }
}

// MARK: - Text Sub-toolbar

/// Text-tool sub-toolbar — color swatches plus a 10–100 font-size slider.
class TextSubToolbar: NSView {
    var currentColor: NSColor = .red
    var currentFontSize: CGFloat = CGFloat(Defaults.lastTextFontSize)
    var strokeEnabled: Bool = false
    var calloutEnabled: Bool = false
    var onColorChanged: ((NSColor) -> Void)?
    /// Fired when the user grabs the slider thumb (mouseDown phase).
    var onFontSizeBegan: (() -> Void)?
    /// Fired on every slider tick during a drag.
    var onFontSizeChanged: ((CGFloat) -> Void)?
    /// Fired when the user releases the slider (mouseUp phase).
    var onFontSizeEnded: (() -> Void)?
    /// Fired when the outline checkbox is toggled.
    var onStrokeChanged: ((Bool) -> Void)?
    /// Fired when the callout checkbox is toggled.
    var onCalloutChanged: ((Bool) -> Void)?

    private var colorButtons: [NSView] = []
    private var slider: HUDSlider!
    private var strokeCheckbox: HUDCheckboxButton!
    private var calloutCheckbox: HUDCheckboxButton!

    private let colors: [NSColor] = EditorStyleDefaults.paletteColors

    // Layout metrics, shared between `setup()` and `preferredWidth` so the
    // view is always wide enough for everything it lays out.
    private static let leadingPad: CGFloat = 12
    private static let sliderWidth: CGFloat = 150
    private static let swatchSize: CGFloat = 18
    private static let swatchGap: CGFloat = 5
    private static let separatorGap: CGFloat = 6
    private static let checkboxGap: CGFloat = 8
    private static let trailingPad: CGFloat = 12
    private static var baseColorCount: CGFloat { CGFloat(EditorStyleDefaults.paletteColors.count) }

    /// Right edge of the last color swatch — the swatch row's extent.
    private static var swatchRowEnd: CGFloat {
        let colorCount = baseColorCount
        return leadingPad + sliderWidth + 8 + 1 + 9
            + colorCount * swatchSize + max(colorCount - 1, 0) * swatchGap
    }

    private static func checkboxWidth(title: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let textWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
        return 16 + 8 + textWidth
    }

    private static var strokeCheckboxWidth: CGFloat {
        checkboxWidth(title: L10n.textStrokeEffect)
    }

    private static var calloutCheckboxWidth: CGFloat {
        checkboxWidth(title: L10n.textCalloutEffect)
    }

    static var preferredWidth: CGFloat {
        swatchRowEnd
            + separatorGap + 1 + checkboxGap
            + strokeCheckboxWidth + checkboxGap + calloutCheckboxWidth
            + trailingPad
    }

    init(
        frame: NSRect,
        currentColor: NSColor,
        currentFontSize: CGFloat,
        strokeEnabled: Bool,
        calloutEnabled: Bool
    ) {
        self.currentColor = currentColor
        self.currentFontSize = currentFontSize
        self.strokeEnabled = strokeEnabled
        self.calloutEnabled = calloutEnabled
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func setup() {
        var x: CGFloat = 12
        let midY = bounds.midY

        // Font-size slider.
        let s = HUDSlider(
            value: Double(currentFontSize),
            minValue: Defaults.textFontSizeMin,
            maxValue: Defaults.textFontSizeMax,
            target: self,
            action: #selector(sliderChanged(_:))
        )
        s.isContinuous = true
        s.frame = NSRect(
            x: x,
            y: midY - HUDSlider.preferredHeight / 2,
            width: TextSubToolbar.sliderWidth,
            height: HUDSlider.preferredHeight
        )
        s.onEditingBegan = { [weak self] in self?.onFontSizeBegan?() }
        s.onEditingEnded = { [weak self] in self?.onFontSizeEnded?() }
        addSubview(s)
        slider = s
        x += TextSubToolbar.sliderWidth + 8

        // Vertical separator between size controls and color swatches.
        let sep = AdaptiveSeparatorView(frame: NSRect(x: x, y: 6, width: 1, height: bounds.height - 12))
        addSubview(sep)
        x += 1 + 9

        // Color swatches.
        let swatchSize: CGFloat = TextSubToolbar.swatchSize
        for (i, color) in colors.enumerated() {
            let swatch = ColorSwatchView(
                frame: NSRect(x: x, y: midY - swatchSize / 2, width: swatchSize, height: swatchSize),
                color: color,
                isSelected: colorsMatch(color, currentColor)
            )
            swatch.itemIndex = i
            let click = NSClickGestureRecognizer(target: self, action: #selector(colorTapped(_:)))
            swatch.addGestureRecognizer(click)
            addSubview(swatch)
            colorButtons.append(swatch)
            x += swatchSize + TextSubToolbar.swatchGap
        }

        // Vertical separator between color swatches and the outline checkbox.
        let lastSwatchRightEdge = x - TextSubToolbar.swatchGap
        let strokeSepX = lastSwatchRightEdge + TextSubToolbar.separatorGap
        let strokeSep = AdaptiveSeparatorView(frame: NSRect(x: strokeSepX, y: 6, width: 1, height: bounds.height - 12))
        addSubview(strokeSep)

        // Outline checkbox.
        let checkboxHeight: CGFloat = 20
        let checkbox = HUDCheckboxButton(
            frame: NSRect(
                x: strokeSepX + 1 + TextSubToolbar.checkboxGap,
                y: midY - checkboxHeight / 2,
                width: TextSubToolbar.strokeCheckboxWidth,
                height: checkboxHeight
            ),
            title: L10n.textStrokeEffect,
            target: self,
            action: #selector(strokeCheckboxChanged(_:))
        )
        checkbox.state = strokeEnabled ? .on : .off
        addSubview(checkbox)
        strokeCheckbox = checkbox

        let calloutX = checkbox.frame.maxX + TextSubToolbar.checkboxGap
        let calloutCheckbox = HUDCheckboxButton(
            frame: NSRect(
                x: calloutX,
                y: midY - checkboxHeight / 2,
                width: TextSubToolbar.calloutCheckboxWidth,
                height: checkboxHeight
            ),
            title: L10n.textCalloutEffect,
            target: self,
            action: #selector(calloutCheckboxChanged(_:))
        )
        calloutCheckbox.state = calloutEnabled ? .on : .off
        addSubview(calloutCheckbox)
        self.calloutCheckbox = calloutCheckbox

    }

    @objc private func strokeCheckboxChanged(_ sender: HUDCheckboxButton) {
        strokeEnabled = sender.state == .on
        onStrokeChanged?(strokeEnabled)
    }

    @objc private func calloutCheckboxChanged(_ sender: HUDCheckboxButton) {
        calloutEnabled = sender.state == .on
        onCalloutChanged?(calloutEnabled)
    }

    @objc private func sliderChanged(_ sender: HUDSlider) {
        let raw = CGFloat(sender.doubleValue)
        let clamped = max(CGFloat(Defaults.textFontSizeMin), min(CGFloat(Defaults.textFontSizeMax), raw))

        currentFontSize = clamped
        onFontSizeChanged?(clamped)
    }

    @objc private func colorTapped(_ gesture: NSGestureRecognizer) {
        guard let view = gesture.view as? ColorSwatchView else { return }
        let index = view.itemIndex
        let paletteColors = colors
        guard index < paletteColors.count else { return }
        currentColor = paletteColors[index]
        onColorChanged?(currentColor)
        for (i, v) in colorButtons.enumerated() where i < paletteColors.count {
            (v as? ColorSwatchView)?.isSelected = colorsMatch(paletteColors[i], currentColor)
        }
    }

    private func colorsMatch(_ a: NSColor, _ b: NSColor) -> Bool {
        guard let ac = a.usingColorSpace(.deviceRGB), let bc = b.usingColorSpace(.deviceRGB) else { return false }
        return abs(ac.redComponent - bc.redComponent) < 0.01 &&
               abs(ac.greenComponent - bc.greenComponent) < 0.01 &&
               abs(ac.blueComponent - bc.blueComponent) < 0.01
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        AdaptiveChrome.toolbarBackground.setFill()
        path.fill()
    }
}

private final class ArrowStyleButtonView: NSView {
    let style: ArrowStyle
    var isSelected: Bool {
        didSet { needsDisplay = true }
    }

    init(frame: NSRect, style: ArrowStyle, isSelected: Bool) {
        self.style = style
        self.isSelected = isSelected
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let color = isSelected ? EditorOptionChrome.selectionColor : NSColor.secondaryLabelColor
        color.setFill()
        color.setStroke()

        let start = NSPoint(x: bounds.minX + 3, y: bounds.midY)
        let end = NSPoint(x: bounds.maxX - 3, y: bounds.midY)

        switch style {
        case .tapered:
            let path = NSBezierPath()
            let headLength: CGFloat = 8
            let headHalf: CGFloat = 4.5
            let neckHalf: CGFloat = 2.3
            let tailHalf: CGFloat = 1.1
            let baseX = end.x - headLength
            let neckX = end.x - headLength * 0.7
            path.move(to: end)
            path.line(to: NSPoint(x: baseX, y: end.y + headHalf))
            path.line(to: NSPoint(x: neckX, y: end.y + neckHalf))
            path.line(to: NSPoint(x: start.x, y: start.y + tailHalf))
            path.line(to: NSPoint(x: start.x, y: start.y - tailHalf))
            path.line(to: NSPoint(x: neckX, y: end.y - neckHalf))
            path.line(to: NSPoint(x: baseX, y: end.y - headHalf))
            path.close()
            path.fill()

        case .doubleEnded:
            let headLength: CGFloat = 7.5
            let shaft = NSBezierPath()
            shaft.move(to: NSPoint(x: start.x + headLength, y: start.y))
            shaft.line(to: NSPoint(x: end.x - headLength, y: end.y))
            shaft.lineWidth = 2
            shaft.lineCapStyle = .round
            shaft.stroke()
            drawRoundedHead(tip: end, unitX: 1, length: headLength, width: 6)
            drawRoundedHead(tip: start, unitX: -1, length: headLength, width: 6)

        case .line:
            let headLength: CGFloat = 7.5
            let shaft = NSBezierPath()
            shaft.move(to: start)
            shaft.line(to: NSPoint(x: end.x - headLength, y: end.y))
            shaft.lineWidth = 2
            shaft.lineCapStyle = .round
            shaft.stroke()
            drawRoundedHead(tip: end, unitX: 1, length: headLength, width: 6)

        case .dotTail:
            let radius: CGFloat = 3.4
            let headLength: CGFloat = 7.5
            let shaft = NSBezierPath()
            shaft.move(to: start)
            shaft.line(to: NSPoint(x: end.x - headLength, y: end.y))
            shaft.lineWidth = 2
            shaft.lineCapStyle = .round
            shaft.stroke()
            NSBezierPath(ovalIn: NSRect(
                x: start.x - radius,
                y: start.y - radius,
                width: radius * 2,
                height: radius * 2
            )).fill()
            drawRoundedHead(tip: end, unitX: 1, length: headLength, width: 6)
        }
    }

    private func drawRoundedHead(tip: NSPoint, unitX: CGFloat, length: CGFloat, width: CGFloat) {
        let head = arrowHead(tip: tip, unitX: unitX, length: length, width: width)
        head.lineJoinStyle = .round
        head.lineWidth = 0.9
        head.fill()
        head.stroke()
    }

    private func arrowHead(tip: NSPoint, unitX: CGFloat, length: CGFloat, width: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let baseX = tip.x - unitX * length
        path.move(to: tip)
        path.line(to: NSPoint(x: baseX, y: tip.y + width / 2))
        path.line(to: NSPoint(x: baseX, y: tip.y - width / 2))
        path.close()
        return path
    }
}
