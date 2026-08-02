import AppKit
import Carbon

// MARK: - Color Swatch View

class ColorSwatchView: NSView {
    let color: NSColor
    var isSelected: Bool = false {
        didSet { needsDisplay = true }
    }
    var itemIndex: Int = 0

    init(frame: NSRect, color: NSColor, isSelected: Bool) {
        self.color = color
        self.isSelected = isSelected
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Draw color circle
        let inset: CGFloat = isSelected ? 1 : 2
        let path = NSBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset))
        color.setFill()
        path.fill()

        if isSelected {
            // Draw green selection ring
            let ring = NSBezierPath(ovalIn: bounds)
            accentGreen.setStroke()
            ring.lineWidth = 2
            ring.stroke()
        }

        // Draw border for white/light colors
        if color == .white || color == NSColor(white: 0.5, alpha: 1.0) {
            let border = NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2))
            NSColor.gray.withAlphaComponent(0.3).setStroke()
            border.lineWidth = 0.5
            border.stroke()
        }
    }

}

// MARK: - HUD Slider

final class HUDSlider: NSControl {
    var minValue: Double
    var maxValue: Double
    var onEditingBegan: (() -> Void)?
    var onEditingEnded: (() -> Void)?

    override var doubleValue: Double {
        get { value }
        set { setValue(newValue, notify: false) }
    }

    override var isEnabled: Bool {
        didSet {
            if !isEnabled {
                isDragging = false
            }
            needsDisplay = true
        }
    }

    private var value: Double
    private var isDragging = false {
        didSet { needsDisplay = true }
    }

    static let preferredHeight: CGFloat = 24
    private let standardKnobHeight: CGFloat = 20
    private let standardKnobMinWidth: CGFloat = 34
    private let knobHorizontalPadding: CGFloat = 12
    private let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)

    init(
        frame: NSRect = .zero,
        value: Double,
        minValue: Double,
        maxValue: Double,
        target: AnyObject?,
        action: Selector?
    ) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.value = min(max(value, minValue), maxValue)
        super.init(frame: frame)
        self.target = target
        self.action = action
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Self.preferredHeight)
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { isEnabled }

    override func draw(_ dirtyRect: NSRect) {
        let enabledAlpha: CGFloat = isEnabled ? 1 : 0.35
        let trackRect = currentTrackRect
        let trackPath = NSBezierPath(
            roundedRect: trackRect,
            xRadius: EditorOptionChrome.sliderTrackHeight / 2,
            yRadius: EditorOptionChrome.sliderTrackHeight / 2
        )
        AdaptiveChrome.border.withAlphaComponent(0.9 * enabledAlpha).setFill()
        trackPath.fill()

        let knobCenterX = trackRect.minX + normalizedValue * trackRect.width

        let knobWidth = currentKnobWidth
        let knobRect = NSRect(
            x: knobCenterX - knobWidth / 2,
            y: floor(bounds.midY - knobHeight / 2),
            width: knobWidth,
            height: knobHeight
        )
        let knobPath = NSBezierPath(
            roundedRect: knobRect,
            xRadius: knobHeight / 2,
            yRadius: knobHeight / 2
        )
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.24 * enabledAlpha)
        shadow.shadowBlurRadius = 2.5
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()
        NSColor.controlBackgroundColor.withAlphaComponent(enabledAlpha).setFill()
        knobPath.fill()
        NSGraphicsContext.restoreGraphicsState()

        AdaptiveChrome.border.withAlphaComponent(enabledAlpha).setStroke()
        knobPath.lineWidth = 0.6
        knobPath.stroke()

        drawValue(in: knobRect, enabledAlpha: enabledAlpha)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        window?.makeFirstResponder(self)
        isDragging = true
        onEditingBegan?()
        updateValue(with: event, notify: true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else { return }
        updateValue(with: event, notify: isContinuous)
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled else {
            isDragging = false
            return
        }
        updateValue(with: event, notify: true)
        isDragging = false
        onEditingEnded?()
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        let fineStep = max((maxValue - minValue) / 100, 0.1)
        let coarseStep = max((maxValue - minValue) / 20, fineStep)
        let step = event.modifierFlags.contains(.shift) ? coarseStep : fineStep
        switch Int(event.keyCode) {
        case kVK_LeftArrow, kVK_DownArrow:
            onEditingBegan?()
            setValue(value - step, notify: true)
            onEditingEnded?()
        case kVK_RightArrow, kVK_UpArrow:
            onEditingBegan?()
            setValue(value + step, notify: true)
            onEditingEnded?()
        default:
            super.keyDown(with: event)
        }
    }

    private var normalizedValue: CGFloat {
        guard maxValue > minValue else { return 0 }
        return CGFloat((value - minValue) / (maxValue - minValue))
    }

    private var usesCircularWidthValueBadge: Bool {
        EditorOptionChrome.usesCircularWidthValueBadge(
            minValue: minValue,
            maxValue: maxValue
        )
    }

    private var knobHeight: CGFloat {
        usesCircularWidthValueBadge
            ? EditorOptionChrome.lineWidthValueBadgeDiameter
            : standardKnobHeight
    }

    private var currentKnobWidth: CGFloat {
        if usesCircularWidthValueBadge {
            return EditorOptionChrome.lineWidthValueBadgeDiameter
        }
        let samples = [
            displayText(for: minValue),
            displayText(for: maxValue),
            displayText(for: value),
        ]
        let maxWidth = samples
            .map { ceil(($0 as NSString).size(withAttributes: [.font: valueFont]).width) }
            .max() ?? 0
        return max(standardKnobMinWidth, maxWidth + knobHorizontalPadding)
    }

    private var currentTrackRect: NSRect {
        let knobWidth = currentKnobWidth
        return NSRect(
            x: knobWidth / 2,
            y: floor(bounds.midY - EditorOptionChrome.sliderTrackHeight / 2),
            width: max(1, bounds.width - knobWidth),
            height: EditorOptionChrome.sliderTrackHeight
        )
    }

    private func updateValue(with event: NSEvent, notify: Bool) {
        let point = convert(event.locationInWindow, from: nil)
        let trackRect = currentTrackRect
        let normalized = max(0, min(1, (point.x - trackRect.minX) / trackRect.width))
        setValue(minValue + Double(normalized) * (maxValue - minValue), notify: notify)
    }

    private func setValue(_ newValue: Double, notify: Bool) {
        value = min(max(newValue, minValue), maxValue)
        needsDisplay = true
        if notify, let action {
            sendAction(action, to: target)
        }
    }

    private func drawValue(in rect: NSRect, enabledAlpha: CGFloat) {
        let text = displayText(for: value)
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: valueFont,
                .foregroundColor: NSColor.labelColor.withAlphaComponent(enabledAlpha),
            ]
        )
        let textSize = attributed.size()
        let textRect = NSRect(
            x: floor(rect.midX - textSize.width / 2),
            y: floor(rect.midY - textSize.height / 2),
            width: ceil(textSize.width),
            height: ceil(textSize.height)
        )
        attributed.draw(in: textRect)
    }

    private func displayText(for rawValue: Double) -> String {
        "\(Int(rawValue.rounded()))"
    }
}

final class ShapeFillModeSegmentedControl: NSView {
    static let preferredHeight: CGFloat = 24
    private static let minSegmentWidth: CGFloat = 54
    private static let segmentHorizontalPadding: CGFloat = 18
    private static let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
    private static let modes = ShapeFillMode.allCases

    var selectedMode: ShapeFillMode {
        didSet { needsDisplay = true }
    }
    var onSelect: ((ShapeFillMode) -> Void)?

    init(frame: NSRect, selectedMode: ShapeFillMode) {
        self.selectedMode = selectedMode
        super.init(frame: frame)
        toolTip = "\(L10n.shapeFillEffect) (F)"
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func preferredWidth() -> CGFloat {
        segmentWidths().reduce(0, +)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let mode = mode(atX: point.x) else { return }
        selectedMode = mode
        onSelect?(mode)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let background = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        AdaptiveChrome.cardBackground.setFill()
        background.fill()

        let widths = Self.segmentWidths()
        var x = rect.minX
        for (index, mode) in Self.modes.enumerated() {
            let width = widths[index]
            let segmentRect = NSRect(x: x, y: rect.minY, width: width, height: rect.height)
            if mode == selectedMode {
                let selected = NSBezierPath(
                    roundedRect: segmentRect.insetBy(dx: 1, dy: 1),
                    xRadius: 6,
                    yRadius: 6
                )
                if EditorOptionChrome.shapeFillSelectionDrawsBackground {
                    EditorOptionChrome.selectionColor.setFill()
                    selected.fill()
                }
                EditorOptionChrome.selectionColor.setStroke()
                selected.lineWidth = EditorOptionChrome.shapeFillSelectionBorderWidth
                selected.stroke()
            } else if index > 0 {
                AdaptiveChrome.separator.setStroke()
                let sep = NSBezierPath()
                sep.move(to: NSPoint(x: x, y: rect.minY + 4))
                sep.line(to: NSPoint(x: x, y: rect.maxY - 4))
                sep.lineWidth = 1
                sep.stroke()
            }
            drawTitle(for: mode, in: segmentRect)
            x += width
        }

        AdaptiveChrome.border.setStroke()
        background.lineWidth = 1
        background.stroke()
    }

    private static func segmentWidths() -> [CGFloat] {
        modes.map { mode in
            let textWidth = ceil((title(for: mode) as NSString).size(withAttributes: [.font: font]).width)
            return max(minSegmentWidth, textWidth + segmentHorizontalPadding)
        }
    }

    private static func title(for mode: ShapeFillMode) -> String {
        switch mode {
        case .none: return L10n.shapeFillNone
        case .opaque: return L10n.shapeFillOpaque
        case .translucent: return L10n.shapeFillTranslucent
        }
    }

    private func mode(atX targetX: CGFloat) -> ShapeFillMode? {
        let widths = Self.segmentWidths()
        var x: CGFloat = 0
        for (index, width) in widths.enumerated() {
            if targetX >= x && targetX <= x + width {
                return Self.modes[index]
            }
            x += width
        }
        return nil
    }

    private func drawTitle(for mode: ShapeFillMode, in rect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.font,
            .foregroundColor: NSColor.labelColor,
        ]
        let title = Self.title(for: mode) as NSString
        let size = title.size(withAttributes: attributes)
        let point = NSPoint(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2
        )
        title.draw(at: point, withAttributes: attributes)
    }
}

final class ShapeStrokeStyleButtonView: NSView {
    let style: ShapeStrokeStyle
    let previewShape: ShapeStrokePreviewShape
    var isSelected: Bool {
        didSet { needsDisplay = true }
    }

    init(frame: NSRect, style: ShapeStrokeStyle, previewShape: ShapeStrokePreviewShape, isSelected: Bool) {
        self.style = style
        self.previewShape = previewShape
        self.isSelected = isSelected
        super.init(frame: frame)
        switch style {
        case .standard:
            toolTip = L10n.shapeStyleStandard
        case .rounded:
            toolTip = L10n.shapeStyleRounded
        case .handDrawn:
            toolTip = L10n.shapeStyleHandDrawn
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let color = isSelected ? EditorOptionChrome.selectionColor : NSColor.secondaryLabelColor

        if isSelected {
            let bg = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: 7, yRadius: 7)
            EditorOptionChrome.selectionColor.withAlphaComponent(0.12).setFill()
            bg.fill()
        }

        switch style {
        case .standard:
            drawStandardIcon(color: color)
        case .rounded:
            switch previewShape {
            case .rectangle:
                drawRoundedRectangleIcon(color: color)
            case .ellipse:
                drawStandardIcon(color: color)
            }
        case .handDrawn:
            switch previewShape {
            case .rectangle:
                drawHandDrawnRectangleIcon(color: color)
            case .ellipse:
                drawHandDrawnCircleIcon(color: color)
            }
        }
    }

    private func drawStandardIcon(color: NSColor) {
        color.setStroke()
        switch previewShape {
        case .rectangle:
            let rect = bounds.insetBy(dx: 6, dy: 4.5)
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 1.9
            path.stroke()
        case .ellipse:
            let side = min(bounds.width, bounds.height) - 8
            let rect = NSRect(
                x: bounds.midX - side / 2,
                y: bounds.midY - side / 2,
                width: side,
                height: side
            )
            let path = NSBezierPath(ovalIn: rect)
            path.lineWidth = 1.9
            path.stroke()
        }
    }

    private func drawRoundedRectangleIcon(color: NSColor) {
        color.setStroke()
        let rect = bounds.insetBy(dx: 6, dy: 4.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 4.3, yRadius: 4.3)
        path.lineWidth = 1.9
        path.stroke()
    }

    private func drawHandDrawnRectangleIcon(color: NSColor) {
        NSGraphicsContext.current?.cgContext.setShouldAntialias(true)

        let outerRect = bounds.insetBy(dx: 4.4, dy: 3.4)
        let innerRect = NSRect(
            x: outerRect.minX + 4.2,
            y: outerRect.minY + 3.2,
            width: outerRect.width - 7.4,
            height: outerRect.height - 5.5
        )
        let outerRadius: CGFloat = 5.2
        let innerRadius: CGFloat = 2.6
        let outer = NSBezierPath(roundedRect: outerRect, xRadius: outerRadius, yRadius: outerRadius)
        let inner = NSBezierPath(roundedRect: innerRect, xRadius: innerRadius, yRadius: innerRadius)
        fillHandDrawnPreviewRing(outer: outer, inner: inner, color: color)
    }

    private func drawHandDrawnCircleIcon(color: NSColor) {
        NSGraphicsContext.current?.cgContext.setShouldAntialias(true)

        let outerRect = NSRect(
            x: bounds.midX - 9.4,
            y: bounds.midY - 6.9,
            width: 18.8,
            height: 13.8
        )
        let innerRect = NSRect(
            x: outerRect.minX + 3.0,
            y: outerRect.minY + 2.35,
            width: outerRect.width - 5.7,
            height: outerRect.height - 5.25
        )
        let outer = NSBezierPath(ovalIn: outerRect)
        let inner = NSBezierPath(ovalIn: innerRect)
        fillHandDrawnPreviewRing(outer: outer, inner: inner, color: color)
    }

    private func fillHandDrawnPreviewRing(outer: NSBezierPath, inner: NSBezierPath, color: NSColor) {
        let shape = NSBezierPath()
        shape.append(outer)
        shape.append(inner)
        shape.windingRule = .evenOdd
        color.setFill()
        shape.fill()
    }
}

// MARK: - HUD Checkbox

final class HUDCheckboxButton: NSButton {
    private let label: String
    private let labelFont = NSFont.systemFont(ofSize: 12, weight: .medium)
    private let boxSize: CGFloat = 16

    init(frame: NSRect, title: String, target: AnyObject?, action: Selector?) {
        self.label = title
        super.init(frame: frame)
        self.title = ""
        self.target = target
        self.action = action
        setButtonType(.toggle)
        bezelStyle = .regularSquare
        isBordered = false
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let enabledAlpha: CGFloat = isEnabled ? 1 : 0.35
        let boxRect = NSRect(
            x: 0,
            y: floor(bounds.midY - boxSize / 2),
            width: boxSize,
            height: boxSize
        )
        let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: 4, yRadius: 4)

        if state == .on {
            EditorOptionChrome.selectionColor.withAlphaComponent(enabledAlpha).setFill()
        } else {
            AdaptiveChrome.subtleFill
                .withAlphaComponent((isHighlighted ? 1.0 : 0.72) * enabledAlpha)
                .setFill()
        }
        boxPath.fill()

        AdaptiveChrome.border.withAlphaComponent(enabledAlpha).setStroke()
        boxPath.lineWidth = 1
        boxPath.stroke()

        if state == .on {
            let check = NSBezierPath()
            check.move(to: NSPoint(x: boxRect.minX + 4.0, y: boxRect.midY + 0.5))
            check.line(to: NSPoint(x: boxRect.minX + 7.0, y: boxRect.midY + 3.5))
            check.line(to: NSPoint(x: boxRect.maxX - 3.5, y: boxRect.midY - 4.0))
            check.lineWidth = 2
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            NSColor(white: 0.08, alpha: enabledAlpha).setStroke()
            check.stroke()
        }

        let attributed = NSAttributedString(
            string: label,
            attributes: [
                .font: labelFont,
                .foregroundColor: NSColor.labelColor.withAlphaComponent(enabledAlpha),
            ]
        )
        let textSize = attributed.size()
        let textRect = NSRect(
            x: boxRect.maxX + 8,
            y: floor(bounds.midY - textSize.height / 2),
            width: max(0, bounds.width - boxRect.maxX - 8),
            height: ceil(textSize.height)
        )
        attributed.draw(in: textRect)
    }
}
