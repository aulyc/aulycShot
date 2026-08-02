import AppKit

// MARK: - Arrow Annotation

struct ArrowAnnotation: Annotation {
    let startPoint: NSPoint
    let endPoint: NSPoint
    let color: NSColor
    let lineWidth: CGFloat
    let style: ArrowStyle
    /// Optional curve handle. When set, the shaft is drawn as a quadratic
    /// bezier through `controlPoint` and the arrowhead orientation follows
    /// the tangent at the end of the curve. nil = straight arrow.
    var controlPoint: NSPoint? = nil

    init(
        startPoint: NSPoint,
        endPoint: NSPoint,
        color: NSColor,
        lineWidth: CGFloat,
        style: ArrowStyle = .tapered,
        controlPoint: NSPoint? = nil
    ) {
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.color = color
        self.lineWidth = lineWidth
        self.style = style
        self.controlPoint = controlPoint
    }

    var boundingRect: NSRect {
        var minX = min(startPoint.x, endPoint.x)
        var minY = min(startPoint.y, endPoint.y)
        var maxX = max(startPoint.x, endPoint.x)
        var maxY = max(startPoint.y, endPoint.y)
        if let cp = controlPoint {
            minX = min(minX, cp.x); maxX = max(maxX, cp.x)
            minY = min(minY, cp.y); maxY = max(maxY, cp.y)
        }

        // The drawn polygon flares out perpendicular to the spine by up to
        // headWidth/2 at the arrowhead's outer corners, which would sit
        // outside the spine-only rect. Inflate so erase/selection rect
        // intersection tests cover the rendered pixels.
        let pad = boundingPad
        return NSRect(
            x: minX - pad,
            y: minY - pad,
            width: maxX - minX + 2 * pad,
            height: maxY - minY + 2 * pad
        )
    }

    private var boundingPad: CGFloat {
        switch style {
        case .tapered:
            return (arrowGeometry?.headWidth ?? 0) / 2
        case .doubleEnded, .line, .dotTail:
            guard let metrics = strokedMetrics else { return lineWidth / 2 }
            return max(metrics.headWidth / 2, metrics.shaftWidth / 2, metrics.tailRadius) + NumberArrowShape.headStrokeWidth + 2
        }
    }

    /// Scaled geometry shared by `draw`, `containsPoint`, and `boundingRect`.
    /// Returns `nil` when the arrow is degenerate (zero length).
    private struct ArrowGeometry {
        let length: CGFloat
        let unitX: CGFloat
        let unitY: CGFloat
        let perpX: CGFloat
        let perpY: CGFloat
        let headLength: CGFloat
        let headWidth: CGFloat
        let neckHalf: CGFloat
        let tailHalf: CGFloat
        let neckIndent: CGFloat
    }

    private var arrowGeometry: ArrowGeometry? {
        let dx: CGFloat
        let dy: CGFloat
        if let cp = controlPoint {
            dx = endPoint.x - cp.x
            dy = endPoint.y - cp.y
        } else {
            dx = endPoint.x - startPoint.x
            dy = endPoint.y - startPoint.y
        }
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return nil }

        var headLength: CGFloat = max(22, lineWidth * 6.5)
        var headWidth: CGFloat = max(22, lineWidth * 7.5)
        var neckHalf: CGFloat = max(3, lineWidth * 1.4)
        var tailHalf: CGFloat = max(0.5, lineWidth * 0.25)

        // Short arrow: scale the whole geometry down proportionally so the
        // head's base never overshoots the tail and the polygon stays
        // simple instead of self-intersecting.
        //
        // Use the actual arrow span (chord |end - start|) — not `length`,
        // which for curved arrows is just the end-tangent magnitude
        // |end - cp|. Dragging the curve handle near the tip would
        // otherwise collapse a long arrow into a sliver.
        let spanLength: CGFloat = controlPoint == nil
            ? length
            : hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
        if spanLength > 0 && spanLength < headLength {
            let scale = spanLength / headLength
            headWidth *= scale
            neckHalf *= scale
            tailHalf *= scale
            headLength = spanLength
        }

        let unitX = dx / length
        let unitY = dy / length
        return ArrowGeometry(
            length: length,
            unitX: unitX,
            unitY: unitY,
            perpX: -unitY,
            perpY: unitX,
            headLength: headLength,
            headWidth: headWidth,
            neckHalf: neckHalf,
            tailHalf: tailHalf,
            neckIndent: headLength * 0.14
        )
    }

    private struct UnitVector {
        let x: CGFloat
        let y: CGFloat
        let length: CGFloat
    }

    private struct StrokedGeometry {
        let startUnit: UnitVector
        let endUnit: UnitVector
        let spanLength: CGFloat
    }

    private struct StrokedMetrics {
        let headLength: CGFloat
        let headWidth: CGFloat
        let shaftWidth: CGFloat
        let tailRadius: CGFloat
    }

    private var strokedGeometry: StrokedGeometry? {
        let chordDX = endPoint.x - startPoint.x
        let chordDY = endPoint.y - startPoint.y
        let chordLength = hypot(chordDX, chordDY)
        guard chordLength > 0 else { return nil }

        let rawStartDX: CGFloat
        let rawStartDY: CGFloat
        let rawEndDX: CGFloat
        let rawEndDY: CGFloat
        if let cp = controlPoint {
            rawStartDX = cp.x - startPoint.x
            rawStartDY = cp.y - startPoint.y
            rawEndDX = endPoint.x - cp.x
            rawEndDY = endPoint.y - cp.y
        } else {
            rawStartDX = chordDX
            rawStartDY = chordDY
            rawEndDX = chordDX
            rawEndDY = chordDY
        }

        let startUnit = normalized(dx: rawStartDX, dy: rawStartDY)
            ?? normalized(dx: chordDX, dy: chordDY)
        let endUnit = normalized(dx: rawEndDX, dy: rawEndDY)
            ?? normalized(dx: chordDX, dy: chordDY)
        guard let startUnit, let endUnit else { return nil }
        return StrokedGeometry(startUnit: startUnit, endUnit: endUnit, spanLength: chordLength)
    }

    private var strokedMetrics: StrokedMetrics? {
        guard let geometry = strokedGeometry else { return nil }
        let headLimit = style == .doubleEnded ? 0.34 : 0.46
        guard style != .tapered else { return nil }
        let shaftWidth = max(1, lineWidth)
        var headLength = max(10, shaftWidth * 4)
        var headWidth = max(7, shaftWidth * 3)
        let tailRadius: CGFloat = style == .dotTail ? max(4, shaftWidth + 2) : 0
        headLength = min(headLength, max(4, geometry.spanLength * headLimit))
        headWidth = min(headWidth, max(6, geometry.spanLength * 0.75))
        return StrokedMetrics(
            headLength: headLength,
            headWidth: headWidth,
            shaftWidth: shaftWidth,
            tailRadius: tailRadius
        )
    }

    private func normalized(dx: CGFloat, dy: CGFloat) -> UnitVector? {
        let length = hypot(dx, dy)
        guard length > 0 else { return nil }
        return UnitVector(x: dx / length, y: dy / length, length: length)
    }

    private func point(_ point: NSPoint, advancedBy distance: CGFloat, along unit: UnitVector) -> NSPoint {
        NSPoint(x: point.x + unit.x * distance, y: point.y + unit.y * distance)
    }

    private func insetSpineEndpoints(
        geometry: StrokedGeometry,
        metrics: StrokedMetrics
    ) -> (start: NSPoint, end: NSPoint) {
        var startInset: CGFloat = 0
        var endInset: CGFloat = metrics.headLength

        if style == .doubleEnded {
            startInset = metrics.headLength
        }

        let totalInset = startInset + endInset
        if totalInset > geometry.spanLength - 1, totalInset > 0 {
            let scale = max(0, geometry.spanLength - 1) / totalInset
            startInset *= scale
            endInset *= scale
        }

        return (
            point(startPoint, advancedBy: startInset, along: geometry.startUnit),
            point(endPoint, advancedBy: -endInset, along: geometry.endUnit)
        )
    }

    private func spinePath(from start: NSPoint, to end: NSPoint) -> CGMutablePath {
        let path = CGMutablePath()
        path.move(to: start)
        if let cp = controlPoint {
            path.addQuadCurve(to: end, control: cp)
        } else {
            path.addLine(to: end)
        }
        return path
    }

    private func arrowHeadPath(
        tip: NSPoint,
        unitX: CGFloat,
        unitY: CGFloat,
        length: CGFloat,
        width: CGFloat
    ) -> CGMutablePath {
        NumberArrowShape.headPath(tip: tip, unitX: unitX, unitY: unitY, length: length, width: width)
    }

    /// Default visual midpoint when no controlPoint is set — the geometric
    /// mid of start/end. Used to anchor the curve handle in adjust mode.
    var defaultCurveMid: NSPoint {
        NSPoint(
            x: (startPoint.x + endPoint.x) / 2,
            y: (startPoint.y + endPoint.y) / 2
        )
    }

    /// Position where the curve handle is rendered: the controlPoint when
    /// set, otherwise the geometric midpoint.
    var curveHandlePoint: NSPoint {
        controlPoint ?? defaultCurveMid
    }

    func draw(in context: CGContext, bounds: NSRect) {
        switch style {
        case .tapered:
            drawTapered(in: context, bounds: bounds)
        case .doubleEnded, .line, .dotTail:
            drawStroked(in: context, bounds: bounds)
        }
    }

    private func drawTapered(in context: CGContext, bounds: NSRect) {
        guard let g = arrowGeometry else { return }
        context.setFillColor(color.cgColor)

        // Head base center and the concave neck point (closer to the tip).
        let baseX = endPoint.x - g.unitX * g.headLength
        let baseY = endPoint.y - g.unitY * g.headLength
        let neckX = endPoint.x - g.unitX * (g.headLength - g.neckIndent)
        let neckY = endPoint.y - g.unitY * (g.headLength - g.neckIndent)

        // Outer corners of the arrowhead.
        let headLX = baseX + g.perpX * g.headWidth / 2
        let headLY = baseY + g.perpY * g.headWidth / 2
        let headRX = baseX - g.perpX * g.headWidth / 2
        let headRY = baseY - g.perpY * g.headWidth / 2

        // Where the shaft meets the head (concave base).
        let neckLX = neckX + g.perpX * g.neckHalf
        let neckLY = neckY + g.perpY * g.neckHalf
        let neckRX = neckX - g.perpX * g.neckHalf
        let neckRY = neckY - g.perpY * g.neckHalf

        if let cp = controlPoint {
            // Curved arrow: draw the tapered shaft as a filled region bounded
            // by two parallel offset quadratic beziers, then drop the swept
            // head on top.
            //
            // Offsetting a quadratic bezier exactly is non-trivial, but for
            // the small widths involved here we can approximate by offsetting
            // each of the three control points by the local perpendicular at
            // that point.
            let startDX = cp.x - startPoint.x
            let startDY = cp.y - startPoint.y
            let startLen = max(hypot(startDX, startDY), 0.0001)
            let startPerpX = -startDY / startLen
            let startPerpY = startDX / startLen

            // Perpendicular at the control point — uses the chord direction
            // (start → end), which equals the sum of the in/out tangents at
            // the control point of a quadratic bezier.
            let cpTangentX = endPoint.x - startPoint.x
            let cpTangentY = endPoint.y - startPoint.y
            let cpTangentLen = max(hypot(cpTangentX, cpTangentY), 0.0001)
            let cpPerpX = -cpTangentY / cpTangentLen
            let cpPerpY = cpTangentX / cpTangentLen

            // Width at the control point — linearly between tail and neck.
            let midHalf = (g.tailHalf + g.neckHalf) * 0.5

            // Truncate the cp via de Casteljau so the shaft is the actual
            // sub-bezier from t=0 to t≈t_neck of the original spine curve.
            // Using `cp` directly would let the shaft bulge well past where
            // the original quadratic was. For a quadratic bezier the
            // velocity at the endpoint is 2·(end - cp), so the parameter
            // step to cover distance d from the tip is d/(2·length).
            let neckDist = g.headLength - g.neckIndent
            let t = max(0, min(1, 1 - neckDist / (2 * g.length)))
            let cpTruncX = startPoint.x + (cp.x - startPoint.x) * t
            let cpTruncY = startPoint.y + (cp.y - startPoint.y) * t

            let tailLX = startPoint.x + startPerpX * g.tailHalf
            let tailLY = startPoint.y + startPerpY * g.tailHalf
            let tailRX = startPoint.x - startPerpX * g.tailHalf
            let tailRY = startPoint.y - startPerpY * g.tailHalf
            let cpLX = cpTruncX + cpPerpX * midHalf
            let cpLY = cpTruncY + cpPerpY * midHalf
            let cpRX = cpTruncX - cpPerpX * midHalf
            let cpRY = cpTruncY - cpPerpY * midHalf

            context.beginPath()
            context.move(to: CGPoint(x: tailLX, y: tailLY))
            context.addQuadCurve(to: CGPoint(x: neckLX, y: neckLY), control: CGPoint(x: cpLX, y: cpLY))
            context.addLine(to: CGPoint(x: neckRX, y: neckRY))
            context.addQuadCurve(to: CGPoint(x: tailRX, y: tailRY), control: CGPoint(x: cpRX, y: cpRY))
            context.closePath()
            context.fillPath()

            // Arrowhead on top.
            context.beginPath()
            context.move(to: endPoint)
            context.addLine(to: CGPoint(x: headLX, y: headLY))
            context.addLine(to: CGPoint(x: neckLX, y: neckLY))
            context.addLine(to: CGPoint(x: neckRX, y: neckRY))
            context.addLine(to: CGPoint(x: headRX, y: headRY))
            context.closePath()
            context.fillPath()
        } else {
            // Straight arrow — a single tapered teardrop polygon. Tail is
            // thin, the body widens toward the concave neck, then the head
            // flares out to the wide tip.
            let tailLX = startPoint.x + g.perpX * g.tailHalf
            let tailLY = startPoint.y + g.perpY * g.tailHalf
            let tailRX = startPoint.x - g.perpX * g.tailHalf
            let tailRY = startPoint.y - g.perpY * g.tailHalf

            context.beginPath()
            context.move(to: endPoint)
            context.addLine(to: CGPoint(x: headLX, y: headLY))
            context.addLine(to: CGPoint(x: neckLX, y: neckLY))
            context.addLine(to: CGPoint(x: tailLX, y: tailLY))
            context.addLine(to: CGPoint(x: tailRX, y: tailRY))
            context.addLine(to: CGPoint(x: neckRX, y: neckRY))
            context.addLine(to: CGPoint(x: headRX, y: headRY))
            context.closePath()
            context.fillPath()
        }
    }

    private func drawStroked(in context: CGContext, bounds: NSRect) {
        guard let geometry = strokedGeometry, let metrics = strokedMetrics else { return }
        let endpoints = insetSpineEndpoints(geometry: geometry, metrics: metrics)
        let path = spinePath(from: endpoints.start, to: endpoints.end)

        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(metrics.shaftWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(path)
        context.strokePath()

        NumberArrowShape.drawHead(
            tip: endPoint,
            unitX: geometry.endUnit.x,
            unitY: geometry.endUnit.y,
            length: metrics.headLength,
            width: metrics.headWidth,
            in: context
        )

        if style == .doubleEnded {
            NumberArrowShape.drawHead(
                tip: startPoint,
                unitX: -geometry.startUnit.x,
                unitY: -geometry.startUnit.y,
                length: metrics.headLength,
                width: metrics.headWidth,
                in: context
            )
        } else if style == .dotTail {
            let rect = NSRect(
                x: startPoint.x - metrics.tailRadius,
                y: startPoint.y - metrics.tailRadius,
                width: metrics.tailRadius * 2,
                height: metrics.tailRadius * 2
            )
            context.fillEllipse(in: rect)
        }

        context.restoreGState()
    }

    func containsPoint(_ point: NSPoint) -> Bool {
        switch style {
        case .tapered:
            return containsTapered(point)
        case .doubleEnded, .line, .dotTail:
            return containsStroked(point)
        }
    }

    private func containsTapered(_ point: NSPoint) -> Bool {
        // Match the rendered silhouette exactly: scaled head polygon for
        // the concave swept arrowhead + scaled shaft polygon for the
        // tapered body. A small `grab` inflation keeps the thin tail
        // clickable without resorting to a uniform fat spine band that
        // would under-cover the much wider neck at large line widths.
        guard let g = arrowGeometry else { return false }
        let grab: CGFloat = 3

        let baseX = endPoint.x - g.unitX * g.headLength
        let baseY = endPoint.y - g.unitY * g.headLength
        let neckX = endPoint.x - g.unitX * (g.headLength - g.neckIndent)
        let neckY = endPoint.y - g.unitY * (g.headLength - g.neckIndent)

        // Head polygon — concave swept silhouette, matches draw().
        let headHalf = g.headWidth / 2 + grab
        let neckHitHalf = g.neckHalf + grab
        let head = CGMutablePath()
        head.move(to: endPoint)
        head.addLine(to: CGPoint(x: baseX + g.perpX * headHalf, y: baseY + g.perpY * headHalf))
        head.addLine(to: CGPoint(x: neckX + g.perpX * neckHitHalf, y: neckY + g.perpY * neckHitHalf))
        head.addLine(to: CGPoint(x: neckX - g.perpX * neckHitHalf, y: neckY - g.perpY * neckHitHalf))
        head.addLine(to: CGPoint(x: baseX - g.perpX * headHalf, y: baseY - g.perpY * headHalf))
        head.closeSubpath()
        if head.contains(point) {
            return true
        }

        // Shaft polygon — tapered trapezoid (straight) or tapered bezier
        // band (curved). Mirrors the geometry drawn in `draw(in:bounds:)`.
        let tailHitHalf = g.tailHalf + grab
        let shaft = CGMutablePath()
        if let cp = controlPoint {
            let startDX = cp.x - startPoint.x
            let startDY = cp.y - startPoint.y
            let startLen = max(hypot(startDX, startDY), 0.0001)
            let startPerpX = -startDY / startLen
            let startPerpY = startDX / startLen

            let cpTangentX = endPoint.x - startPoint.x
            let cpTangentY = endPoint.y - startPoint.y
            let cpTangentLen = max(hypot(cpTangentX, cpTangentY), 0.0001)
            let cpPerpX = -cpTangentY / cpTangentLen
            let cpPerpY = cpTangentX / cpTangentLen

            let midHitHalf = (tailHitHalf + neckHitHalf) * 0.5

            // Match draw(): truncate cp so the hit-test curve traces the
            // same sub-bezier as the rendered shaft, not the original
            // (over-bulged) one.
            let neckDist = g.headLength - g.neckIndent
            let t = max(0, min(1, 1 - neckDist / (2 * g.length)))
            let cpTruncX = startPoint.x + (cp.x - startPoint.x) * t
            let cpTruncY = startPoint.y + (cp.y - startPoint.y) * t

            shaft.move(to: CGPoint(x: startPoint.x + startPerpX * tailHitHalf,
                                   y: startPoint.y + startPerpY * tailHitHalf))
            shaft.addQuadCurve(
                to: CGPoint(x: neckX + g.perpX * neckHitHalf, y: neckY + g.perpY * neckHitHalf),
                control: CGPoint(x: cpTruncX + cpPerpX * midHitHalf, y: cpTruncY + cpPerpY * midHitHalf)
            )
            shaft.addLine(to: CGPoint(x: neckX - g.perpX * neckHitHalf, y: neckY - g.perpY * neckHitHalf))
            shaft.addQuadCurve(
                to: CGPoint(x: startPoint.x - startPerpX * tailHitHalf,
                            y: startPoint.y - startPerpY * tailHitHalf),
                control: CGPoint(x: cpTruncX - cpPerpX * midHitHalf, y: cpTruncY - cpPerpY * midHitHalf)
            )
            shaft.closeSubpath()
        } else {
            shaft.move(to: CGPoint(x: startPoint.x + g.perpX * tailHitHalf,
                                   y: startPoint.y + g.perpY * tailHitHalf))
            shaft.addLine(to: CGPoint(x: neckX + g.perpX * neckHitHalf, y: neckY + g.perpY * neckHitHalf))
            shaft.addLine(to: CGPoint(x: neckX - g.perpX * neckHitHalf, y: neckY - g.perpY * neckHitHalf))
            shaft.addLine(to: CGPoint(x: startPoint.x - g.perpX * tailHitHalf,
                                      y: startPoint.y - g.perpY * tailHitHalf))
            shaft.closeSubpath()
        }
        return shaft.contains(point)
    }

    private func containsStroked(_ point: NSPoint) -> Bool {
        guard let geometry = strokedGeometry, let metrics = strokedMetrics else { return false }
        let endpoints = insetSpineEndpoints(geometry: geometry, metrics: metrics)
        let path = spinePath(from: endpoints.start, to: endpoints.end)

        if strokedPathContains(path, point: point, lineWidth: metrics.shaftWidth) {
            return true
        }

        let endHead = arrowHeadPath(
            tip: endPoint,
            unitX: geometry.endUnit.x,
            unitY: geometry.endUnit.y,
            length: metrics.headLength,
            width: metrics.headWidth
        )
        if endHead.contains(point) {
            return true
        }

        if style == .doubleEnded {
            let startHead = arrowHeadPath(
                tip: startPoint,
                unitX: -geometry.startUnit.x,
                unitY: -geometry.startUnit.y,
                length: metrics.headLength,
                width: metrics.headWidth
            )
            return startHead.contains(point)
        }

        if style == .dotTail {
            return hypot(point.x - startPoint.x, point.y - startPoint.y) <= metrics.tailRadius + 4
        }

        return false
    }

    func translated(by delta: NSPoint) -> Annotation {
        let translatedCP: NSPoint? = controlPoint.map {
            NSPoint(x: $0.x + delta.x, y: $0.y + delta.y)
        }
        return ArrowAnnotation(
            startPoint: NSPoint(x: startPoint.x + delta.x, y: startPoint.y + delta.y),
            endPoint: NSPoint(x: endPoint.x + delta.x, y: endPoint.y + delta.y),
            color: color,
            lineWidth: lineWidth,
            style: style,
            controlPoint: translatedCP
        )
    }

    /// Adjust-mode helper: replace (or clear) the curve control point.
    func withControlPoint(_ cp: NSPoint?) -> ArrowAnnotation {
        var copy = self
        copy.controlPoint = cp
        return copy
    }

    /// Adjust-mode helper: replace the start (tail) endpoint while keeping
    /// the tip and any curve control point fixed in canvas space.
    func withStartPoint(_ p: NSPoint) -> ArrowAnnotation {
        ArrowAnnotation(
            startPoint: p,
            endPoint: endPoint,
            color: color,
            lineWidth: lineWidth,
            style: style,
            controlPoint: controlPoint
        )
    }

    /// Adjust-mode helper: replace the tip (arrowhead) endpoint while
    /// keeping the start and any curve control point fixed in canvas space.
    func withEndPoint(_ p: NSPoint) -> ArrowAnnotation {
        ArrowAnnotation(
            startPoint: startPoint,
            endPoint: p,
            color: color,
            lineWidth: lineWidth,
            style: style,
            controlPoint: controlPoint
        )
    }

    func withColor(_ color: NSColor) -> Annotation {
        ArrowAnnotation(
            startPoint: startPoint,
            endPoint: endPoint,
            color: color,
            lineWidth: lineWidth,
            style: style,
            controlPoint: controlPoint
        )
    }

    func withLineWidth(_ lineWidth: CGFloat) -> Annotation {
        ArrowAnnotation(
            startPoint: startPoint,
            endPoint: endPoint,
            color: color,
            lineWidth: lineWidth,
            style: style,
            controlPoint: controlPoint
        )
    }

    func withStyle(_ style: ArrowStyle) -> ArrowAnnotation {
        ArrowAnnotation(
            startPoint: startPoint,
            endPoint: endPoint,
            color: color,
            lineWidth: lineWidth,
            style: style,
            controlPoint: controlPoint
        )
    }
}
