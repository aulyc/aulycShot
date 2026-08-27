import AppKit

// MARK: - Text Annotation

struct TextAnnotation: Annotation, Equatable {
    let text: String
    /// Bottom-left of the editing/drawing frame, in canvas coordinates.
    let origin: NSPoint
    let color: NSColor
    let fontSize: CGFloat
    var rotation: CGFloat = 0
    /// When true the glyphs get a black-or-white outline picked for maximum
    /// contrast against `color`, so the text reads against any background.
    var hasStroke: Bool = false
    /// Callout mode turns `color` into the bubble/arrow fill and renders glyphs
    /// in black or white for contrast.
    var hasCallout: Bool = false
    /// Optional arrow tip pulled out from the callout bubble via the selection
    /// handle. nil means bubble only.
    var calloutTip: NSPoint? = nil

    static let trailingCaretPadding: CGFloat = 12
    static let minimumEditorWidth: CGFloat = 32
    static let calloutHorizontalPadding: CGFloat = 10
    static let calloutVerticalPadding: CGFloat = 4
    static let calloutCornerRadius: CGFloat = 7
    static let calloutHandleOffset: CGFloat = 18
    static let calloutArrowMinDistance: CGFloat = 18
    static let calloutArrowLineWidth: CGFloat = 3
    private static let calloutTailBaseWidth: CGFloat = 30
    private static let calloutTailTipMaxRadius: CGFloat = 3.2
    private static let textVerticalCenteringFactor: CGFloat = 0.2

    /// Outline pen width for the silhouette pass, as the percentage-of-font
    /// unit `NSAttributedString.Key.strokeWidth` expects. The fill pass on top
    /// covers the inner half, so the visible outline is roughly half of this.
    static let strokeWidthPercent: CGFloat = 6.0

    static func font(forSize size: CGFloat) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: .bold)
    }

    /// Light fills (white / yellow / green) get a black outline; every other
    /// fill color gets a white one.
    static func strokeColor(for fill: NSColor) -> NSColor {
        guard let rgb = fill.usingColorSpace(.sRGB) else { return .white }
        func matches(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> Bool {
            abs(rgb.redComponent - r) < 0.04
                && abs(rgb.greenComponent - g) < 0.04
                && abs(rgb.blueComponent - b) < 0.04
        }
        let blackStroke = matches(1.0, 1.0, 1.0)   // White
            || matches(1.0, 0.8, 0.0)              // Yellow
            || matches(0.0, 0.83, 0.42)            // Green
        return blackStroke ? .black : .white
    }

    static func contrastingTextColor(for background: NSColor) -> NSColor {
        strokeColor(for: background)
    }

    static func lineHeight(for font: NSFont) -> CGFloat {
        ceil(font.ascender - font.descender + font.leading)
    }

    static func lines(for text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        return lines.isEmpty ? [""] : lines
    }

    private static func measuredLineWidth(_ line: String, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        guard !line.isEmpty else { return 0 }
        return ceil((line as NSString).size(withAttributes: attributes).width)
    }

    private static func inkBounds(for line: String, attributes: [NSAttributedString.Key: Any]) -> NSRect {
        let textToMeasure = line.isEmpty ? "M" : line
        return NSAttributedString(string: textToMeasure, attributes: attributes).boundingRect(
            with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesDeviceMetrics]
        )
    }

    private static func centeredDrawOffsetY(
        for line: String,
        lineHeight: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) -> CGFloat {
        let ink = inkBounds(for: line, attributes: attributes)
        let metricOffset = (lineHeight - ink.height) / 2 - ink.origin.y
        return metricOffset * textVerticalCenteringFactor
    }

    static func editorSize(for text: String, font: NSFont) -> NSSize {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let lines = Self.lines(for: text)
        let fallbackWidth = ceil(("M" as NSString).size(withAttributes: attrs).width)
        let measuredWidth = lines
            .map { measuredLineWidth($0, attributes: attrs) }
            .max() ?? fallbackWidth
        let lineCount = max(1, lines.count)
        return NSSize(
            width: max(measuredWidth + trailingCaretPadding, minimumEditorWidth),
            height: lineHeight(for: font) * CGFloat(lineCount)
        )
    }

    /// Tight ink-bounds rect for the rendered glyphs, in canvas coordinates.
    ///
    /// Used for the dashed selection frame and as the rotation pivot, so the
    /// chrome hugs what's actually painted instead of the editor frame's
    /// trailing-caret padding + line leading (which made the box look skewed
    /// toward bottom-left of the text).
    var textBounds: NSRect {
        let font = TextAnnotation.font(forSize: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let lines = TextAnnotation.lines(for: text)
        let lineHeight = TextAnnotation.lineHeight(for: font)
        let rects = lines.enumerated().map { index, line in
            let ink = TextAnnotation.inkBounds(for: line, attributes: attrs)
            let offsetY = TextAnnotation.centeredDrawOffsetY(
                for: line,
                lineHeight: lineHeight,
                attributes: attrs
            )
            return NSRect(
                x: origin.x + ink.origin.x,
                y: origin.y + lineHeight * CGFloat(lines.count - 1 - index) + offsetY + ink.origin.y,
                width: ink.width,
                height: ink.height
            )
        }
        guard let first = rects.first else { return textBlockRect }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }

    var textBlockRect: NSRect {
        let font = TextAnnotation.font(forSize: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let lines = TextAnnotation.lines(for: text)
        let measuredWidth = lines
            .map { TextAnnotation.measuredLineWidth($0, attributes: attrs) }
            .max() ?? 0
        let blockHeight = TextAnnotation.lineHeight(for: font) * CGFloat(lines.count)
        let width = max(measuredWidth, TextAnnotation.minimumEditorWidth - TextAnnotation.trailingCaretPadding)
        return NSRect(x: origin.x, y: origin.y, width: width, height: blockHeight)
    }

    var calloutBodyRect: NSRect {
        textBlockRect.insetBy(
            dx: -TextAnnotation.calloutHorizontalPadding,
            dy: -TextAnnotation.calloutVerticalPadding
        )
    }

    var calloutHandlePoint: NSPoint {
        calloutTip ?? NSPoint(
            x: calloutBodyRect.midX,
            y: calloutBodyRect.minY - TextAnnotation.calloutHandleOffset
        )
    }

    var hasCalloutArrow: Bool {
        guard hasCallout, let tip = calloutTip else { return false }
        guard !calloutBodyRect.insetBy(dx: -2, dy: -2).contains(tip) else { return false }
        let anchor = calloutAnchorPoint(for: tip)
        return hypot(tip.x - anchor.x, tip.y - anchor.y) >= TextAnnotation.calloutArrowMinDistance
    }

    var hitBounds: NSRect {
        textBounds.insetBy(dx: -10, dy: -max(10, fontSize * 0.75))
    }

    var boundingRect: NSRect {
        guard hasCallout else { return textBounds }
        return calloutBackgroundPath().boundingBoxOfPath
            .insetBy(dx: -TextAnnotation.calloutArrowLineWidth, dy: -TextAnnotation.calloutArrowLineWidth)
    }
    var supportsRotation: Bool { true }

    func calloutAnchorPoint(for tip: NSPoint?) -> NSPoint {
        calloutAnchorPoint(for: tip, in: calloutBodyRect)
    }

    private func calloutAnchorPoint(for tip: NSPoint?, in rect: NSRect) -> NSPoint {
        guard let tip else {
            return NSPoint(x: rect.midX, y: rect.minY)
        }
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let dx = tip.x - center.x
        let dy = tip.y - center.y
        guard dx != 0 || dy != 0 else {
            return NSPoint(x: rect.midX, y: rect.minY)
        }

        let tx: CGFloat = dx > 0
            ? (rect.maxX - center.x) / dx
            : (dx < 0 ? (rect.minX - center.x) / dx : .greatestFiniteMagnitude)
        let ty: CGFloat = dy > 0
            ? (rect.maxY - center.y) / dy
            : (dy < 0 ? (rect.minY - center.y) / dy : .greatestFiniteMagnitude)
        let t = min(tx, ty)
        guard t.isFinite, t > 0 else {
            return NSPoint(x: rect.midX, y: rect.minY)
        }
        return NSPoint(x: center.x + dx * t, y: center.y + dy * t)
    }

    func draw(in context: CGContext, bounds: NSRect) {
        let font = TextAnnotation.font(forSize: fontSize)
        let lines = TextAnnotation.lines(for: text)
        let lineHeight = TextAnnotation.lineHeight(for: font)
        NSGraphicsContext.saveGraphicsState()
        if hasCallout {
            drawCalloutBackground(in: context)
        }
        let fillAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: hasCallout ? TextAnnotation.contrastingTextColor(for: color) : color,
            .font: font
        ]
        let strokeAttributes: [NSAttributedString.Key: Any]? = {
            guard hasStroke, !hasCallout else { return nil }
            let stroke = TextAnnotation.strokeColor(for: color)
            return [
                .foregroundColor: stroke,
                .strokeColor: stroke,
                .strokeWidth: -TextAnnotation.strokeWidthPercent,
                .font: font
            ]
        }()

        for (index, line) in lines.enumerated() where !line.isEmpty {
            let offsetY = TextAnnotation.centeredDrawOffsetY(
                for: line,
                lineHeight: lineHeight,
                attributes: fillAttributes
            )
            let lineOrigin = NSPoint(
                x: origin.x,
                y: origin.y + lineHeight * CGFloat(lines.count - 1 - index) + offsetY
            )
            if let strokeAttributes {
                (line as NSString).draw(at: lineOrigin, withAttributes: strokeAttributes)
            }
            (line as NSString).draw(at: lineOrigin, withAttributes: fillAttributes)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    func drawCalloutBackgroundOnly(in context: CGContext, bodyRect: NSRect? = nil) {
        guard hasCallout else { return }
        drawCalloutBackground(in: context, bodyRect: bodyRect ?? calloutBodyRect)
    }

    private func drawCalloutBackground(in context: CGContext, bodyRect: NSRect? = nil) {
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.addPath(calloutBackgroundPath(bodyRect: bodyRect ?? calloutBodyRect))
        context.fillPath()
        context.restoreGState()
    }

    private func calloutBackgroundPath() -> CGPath {
        calloutBackgroundPath(bodyRect: calloutBodyRect)
    }

    private func calloutBackgroundPath(bodyRect: NSRect) -> CGPath {
        guard hasCalloutArrow, let tip = calloutTip else {
            return CGPath(
                roundedRect: bodyRect,
                cornerWidth: TextAnnotation.calloutCornerRadius,
                cornerHeight: TextAnnotation.calloutCornerRadius,
                transform: nil
            )
        }
        return calloutBubblePath(to: tip, bodyRect: bodyRect)
    }

    private func calloutBubblePath(to tip: NSPoint, bodyRect rect: NSRect) -> CGPath {
        let radius = min(TextAnnotation.calloutCornerRadius, rect.width / 2, rect.height / 2)
        guard radius > 0 else {
            return CGPath(
                rect: rect,
                transform: nil
            )
        }

        let base = calloutTailBase(for: tip, in: rect)
        let path = CGMutablePath()
        let kappa: CGFloat = 0.552_284_749_830_793_6
        let k = radius * kappa

        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY

        path.move(to: NSPoint(x: minX + radius, y: minY))
        addBottomEdge(to: path, rect: rect, radius: radius, base: base, tip: tip)
        path.addCurve(
            to: NSPoint(x: maxX, y: minY + radius),
            control1: NSPoint(x: maxX - radius + k, y: minY),
            control2: NSPoint(x: maxX, y: minY + radius - k)
        )
        addRightEdge(to: path, rect: rect, radius: radius, base: base, tip: tip)
        path.addCurve(
            to: NSPoint(x: maxX - radius, y: maxY),
            control1: NSPoint(x: maxX, y: maxY - radius + k),
            control2: NSPoint(x: maxX - radius + k, y: maxY)
        )
        addTopEdge(to: path, rect: rect, radius: radius, base: base, tip: tip)
        path.addCurve(
            to: NSPoint(x: minX, y: maxY - radius),
            control1: NSPoint(x: minX + radius - k, y: maxY),
            control2: NSPoint(x: minX, y: maxY - radius + k)
        )
        addLeftEdge(to: path, rect: rect, radius: radius, base: base, tip: tip)
        path.addCurve(
            to: NSPoint(x: minX + radius, y: minY),
            control1: NSPoint(x: minX, y: minY + radius - k),
            control2: NSPoint(x: minX + radius - k, y: minY)
        )
        path.closeSubpath()
        return path
    }

    private func addBottomEdge(
        to path: CGMutablePath,
        rect: NSRect,
        radius: CGFloat,
        base: CalloutTailBase,
        tip: NSPoint
    ) {
        if base.side == .bottom {
            path.addLine(to: base.start)
            appendCalloutTail(to: tip, base: base, in: path)
        }
        path.addLine(to: NSPoint(x: rect.maxX - radius, y: rect.minY))
    }

    private func addRightEdge(
        to path: CGMutablePath,
        rect: NSRect,
        radius: CGFloat,
        base: CalloutTailBase,
        tip: NSPoint
    ) {
        if base.side == .right {
            path.addLine(to: base.start)
            appendCalloutTail(to: tip, base: base, in: path)
        }
        path.addLine(to: NSPoint(x: rect.maxX, y: rect.maxY - radius))
    }

    private func addTopEdge(
        to path: CGMutablePath,
        rect: NSRect,
        radius: CGFloat,
        base: CalloutTailBase,
        tip: NSPoint
    ) {
        if base.side == .top {
            path.addLine(to: base.start)
            appendCalloutTail(to: tip, base: base, in: path)
        }
        path.addLine(to: NSPoint(x: rect.minX + radius, y: rect.maxY))
    }

    private func addLeftEdge(
        to path: CGMutablePath,
        rect: NSRect,
        radius: CGFloat,
        base: CalloutTailBase,
        tip: NSPoint
    ) {
        if base.side == .left {
            path.addLine(to: base.start)
            appendCalloutTail(to: tip, base: base, in: path)
        }
        path.addLine(to: NSPoint(x: rect.minX, y: rect.minY + radius))
    }

    private func appendCalloutTail(to tip: NSPoint, base: CalloutTailBase, in path: CGMutablePath) {
        let dx = tip.x - base.center.x
        let dy = tip.y - base.center.y
        let distance = hypot(dx, dy)
        guard distance >= TextAnnotation.calloutArrowMinDistance else { return }
        let unitX = dx / distance
        let unitY = dy / distance
        let perpX = -unitY
        let perpY = unitX
        let tipRadius = min(
            TextAnnotation.calloutTailTipMaxRadius,
            max(1.25, fontSize * 0.05),
            distance * 0.08
        )
        let rootRound = min(max(5, fontSize * 0.22), base.halfWidth * 0.72, distance * 0.22)
        let sideControl = max(rootRound, distance * 0.32)

        let tipBack = NSPoint(x: tip.x - unitX * tipRadius, y: tip.y - unitY * tipRadius)
        let negativePerpTip = NSPoint(x: tipBack.x - perpX * tipRadius, y: tipBack.y - perpY * tipRadius)
        let positivePerpTip = NSPoint(x: tipBack.x + perpX * tipRadius, y: tipBack.y + perpY * tipRadius)
        let tangentDotPerp = base.tangent.dx * perpX + base.tangent.dy * perpY
        let startTip: NSPoint
        let endTip: NSPoint
        let startTipSide: CGVector
        let endTipSide: CGVector
        if tangentDotPerp >= 0 {
            startTip = negativePerpTip
            endTip = positivePerpTip
            startTipSide = CGVector(dx: -perpX, dy: -perpY)
            endTipSide = CGVector(dx: perpX, dy: perpY)
        } else {
            startTip = positivePerpTip
            endTip = negativePerpTip
            startTipSide = CGVector(dx: perpX, dy: perpY)
            endTipSide = CGVector(dx: -perpX, dy: -perpY)
        }
        let roundedTipControl = tipRadius * 0.55

        path.addCurve(
            to: startTip,
            control1: NSPoint(
                x: base.start.x + base.tangent.dx * rootRound,
                y: base.start.y + base.tangent.dy * rootRound
            ),
            control2: NSPoint(
                x: startTip.x - unitX * sideControl,
                y: startTip.y - unitY * sideControl
            )
        )
        path.addCurve(
            to: tip,
            control1: NSPoint(
                x: startTip.x + unitX * roundedTipControl,
                y: startTip.y + unitY * roundedTipControl
            ),
            control2: NSPoint(
                x: tip.x + startTipSide.dx * roundedTipControl,
                y: tip.y + startTipSide.dy * roundedTipControl
            )
        )
        path.addCurve(
            to: endTip,
            control1: NSPoint(
                x: tip.x + endTipSide.dx * roundedTipControl,
                y: tip.y + endTipSide.dy * roundedTipControl
            ),
            control2: NSPoint(
                x: endTip.x + unitX * roundedTipControl,
                y: endTip.y + unitY * roundedTipControl
            )
        )
        path.addCurve(
            to: base.end,
            control1: NSPoint(
                x: endTip.x - unitX * sideControl,
                y: endTip.y - unitY * sideControl
            ),
            control2: NSPoint(
                x: base.end.x - base.tangent.dx * rootRound,
                y: base.end.y - base.tangent.dy * rootRound
            )
        )
    }

    private struct CalloutTailBase {
        let center: NSPoint
        let start: NSPoint
        let end: NSPoint
        let tangent: CGVector
        let halfWidth: CGFloat
        let side: CalloutTailSide
    }

    private enum CalloutTailSide {
        case top
        case right
        case bottom
        case left
    }

    private func calloutTailBase(for tip: NSPoint, in rect: NSRect) -> CalloutTailBase {
        let anchor = calloutAnchorPoint(for: tip, in: rect)
        let side = calloutTailSide(for: anchor, tip: tip, in: rect)
        let desiredWidth = min(
            TextAnnotation.calloutTailBaseWidth,
            max(18, fontSize * 0.78)
        )
        let inset = TextAnnotation.calloutCornerRadius + 1

        let rawTangent: CGVector
        let availableSpan: CGFloat
        let center: NSPoint
        switch side {
        case .top:
            rawTangent = CGVector(dx: -1, dy: 0)
            availableSpan = max(2, rect.width - inset * 2)
            let half = min(desiredWidth / 2, availableSpan / 2)
            center = NSPoint(
                x: min(max(anchor.x, rect.minX + inset + half), rect.maxX - inset - half),
                y: rect.maxY
            )
        case .bottom:
            rawTangent = CGVector(dx: 1, dy: 0)
            availableSpan = max(2, rect.width - inset * 2)
            let half = min(desiredWidth / 2, availableSpan / 2)
            center = NSPoint(
                x: min(max(anchor.x, rect.minX + inset + half), rect.maxX - inset - half),
                y: rect.minY
            )
        case .left:
            rawTangent = CGVector(dx: 0, dy: -1)
            availableSpan = max(2, rect.height - inset * 2)
            let half = min(desiredWidth / 2, availableSpan / 2)
            center = NSPoint(
                x: rect.minX,
                y: min(max(anchor.y, rect.minY + inset + half), rect.maxY - inset - half)
            )
        case .right:
            rawTangent = CGVector(dx: 0, dy: 1)
            availableSpan = max(2, rect.height - inset * 2)
            let half = min(desiredWidth / 2, availableSpan / 2)
            center = NSPoint(
                x: rect.maxX,
                y: min(max(anchor.y, rect.minY + inset + half), rect.maxY - inset - half)
            )
        }

        let halfWidth = min(desiredWidth / 2, availableSpan / 2)

        return CalloutTailBase(
            center: center,
            start: NSPoint(x: center.x - rawTangent.dx * halfWidth, y: center.y - rawTangent.dy * halfWidth),
            end: NSPoint(x: center.x + rawTangent.dx * halfWidth, y: center.y + rawTangent.dy * halfWidth),
            tangent: rawTangent,
            halfWidth: halfWidth,
            side: side
        )
    }

    private func calloutTailSide(for anchor: NSPoint, tip: NSPoint, in rect: NSRect) -> CalloutTailSide {
        let distances: [(CalloutTailSide, CGFloat)] = [
            (.top, abs(anchor.y - rect.maxY)),
            (.right, abs(anchor.x - rect.maxX)),
            (.bottom, abs(anchor.y - rect.minY)),
            (.left, abs(anchor.x - rect.minX))
        ]
        let minDistance = distances.map(\.1).min() ?? 0
        let candidates = distances.filter { abs($0.1 - minDistance) < 0.5 }.map(\.0)
        guard candidates.count > 1 else {
            return candidates.first ?? .bottom
        }

        let center = NSPoint(x: rect.midX, y: rect.midY)
        let dx = tip.x - center.x
        let dy = tip.y - center.y
        if abs(dx) > abs(dy) {
            return dx >= 0 ? .right : .left
        }
        return dy >= 0 ? .top : .bottom
    }

    func containsPoint(_ point: NSPoint) -> Bool {
        let p = unrotate(point)
        if hasCallout {
            return calloutBackgroundPath().contains(p)
                || calloutBodyRect.insetBy(dx: -4, dy: -4).contains(p)
        }
        return hitBounds.contains(p)
    }

    func translated(by delta: NSPoint) -> Annotation {
        TextAnnotation(
            text: text,
            origin: NSPoint(x: origin.x + delta.x, y: origin.y + delta.y),
            color: color,
            fontSize: fontSize,
            rotation: rotation,
            hasStroke: hasStroke,
            hasCallout: hasCallout,
            calloutTip: calloutTip.map { NSPoint(x: $0.x + delta.x, y: $0.y + delta.y) }
        )
    }

    func translatedBodyPreservingCalloutTip(by delta: NSPoint) -> TextAnnotation {
        TextAnnotation(
            text: text,
            origin: NSPoint(x: origin.x + delta.x, y: origin.y + delta.y),
            color: color,
            fontSize: fontSize,
            rotation: rotation,
            hasStroke: hasStroke,
            hasCallout: hasCallout,
            calloutTip: hasCalloutArrow ? calloutTip : calloutTip.map {
                NSPoint(x: $0.x + delta.x, y: $0.y + delta.y)
            }
        )
    }

    func withRotation(_ rotation: CGFloat) -> Annotation {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    func withColor(_ color: NSColor) -> Annotation {
        TextAnnotation(
            text: text,
            origin: origin,
            color: color,
            fontSize: fontSize,
            rotation: rotation,
            hasStroke: hasStroke,
            hasCallout: hasCallout,
            calloutTip: calloutTip
        )
    }

    /// Returns a copy with the outline toggled on or off.
    func withStroke(_ hasStroke: Bool) -> TextAnnotation {
        var copy = self
        copy.hasStroke = hasStroke
        return copy
    }

    func withCallout(_ hasCallout: Bool) -> TextAnnotation {
        var copy = self
        copy.hasCallout = hasCallout
        return copy
    }

    func withCalloutTip(_ tip: NSPoint?) -> TextAnnotation {
        var copy = self
        copy.calloutTip = tip
        return copy
    }

    /// Resize the text in place. The visual top-left stays anchored — fonts
    /// grow downward in canvas coords, so the origin shifts by the full text
    /// block height delta to keep the cap line steady.
    func withFontSize(_ fontSize: CGFloat) -> Annotation {
        let oldFont = TextAnnotation.font(forSize: self.fontSize)
        let newFont = TextAnnotation.font(forSize: fontSize)
        let oldHeight = TextAnnotation.editorSize(for: text, font: oldFont).height
        let newHeight = TextAnnotation.editorSize(for: text, font: newFont).height
        let newOrigin = NSPoint(x: origin.x, y: origin.y + (oldHeight - newHeight))
        return TextAnnotation(
            text: text,
            origin: newOrigin,
            color: color,
            fontSize: fontSize,
            rotation: rotation,
            hasStroke: hasStroke,
            hasCallout: hasCallout,
            calloutTip: calloutTip
        )
    }
}
