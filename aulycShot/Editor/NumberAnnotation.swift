import AppKit

// MARK: - Number Annotation

struct NumberAnnotation: Annotation {
    let center: NSPoint
    /// Optional arrow tip pointing away from the badge. `nil` (or a tip
    /// inside the badge) draws the badge alone. Otherwise an arrow is drawn
    /// from the badge's edge out to `tip`. Set during creation by drag, and
    /// adjustable later via the tip handle in adjust mode.
    var tip: NSPoint?
    /// Optional curve handle. When set together with `tip`, the shaft is
    /// drawn as a quadratic bezier through `controlPoint` and the
    /// arrowhead orientation follows the tangent at the tip. nil = straight
    /// shaft.
    var controlPoint: NSPoint? = nil
    let number: Int
    let color: NSColor

    static let radius: CGFloat = 14
    /// Below this distance from `center` we treat the tip as "no arrow" so
    /// the head won't sit on top of the badge glyph.
    static let arrowMinDistance: CGFloat = NumberAnnotation.radius + 6

    /// Black on light badges, white on dark — perceived-luminance threshold.
    static func contrastingTextColor(for color: NSColor) -> NSColor {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let luminance = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        return luminance > 0.6 ? .black : .white
    }

    var hasArrow: Bool {
        guard let tip else { return false }
        return hypot(tip.x - center.x, tip.y - center.y) >= NumberAnnotation.arrowMinDistance
    }

    var circleRect: NSRect {
        NSRect(
            x: center.x - NumberAnnotation.radius,
            y: center.y - NumberAnnotation.radius,
            width: NumberAnnotation.radius * 2,
            height: NumberAnnotation.radius * 2
        )
    }

    var boundingRect: NSRect {
        guard hasArrow, let tip else { return circleRect }
        var rect = circleRect.union(NSRect(x: tip.x, y: tip.y, width: 0, height: 0))
        if let cp = controlPoint {
            rect = rect.union(NSRect(x: cp.x, y: cp.y, width: 0, height: 0))
        }
        return rect
    }

    /// Default curve handle position when no `controlPoint` is set — the
    /// midpoint of the shaft (badge center to tip) so a fresh straight
    /// arrow still surfaces a grabbable bend point.
    var defaultCurveMid: NSPoint? {
        guard hasArrow, let tip else { return nil }
        return NSPoint(
            x: (center.x + tip.x) / 2,
            y: (center.y + tip.y) / 2
        )
    }

    /// Position where the curve handle is rendered: the controlPoint when
    /// set, otherwise the visual midpoint. nil when there's no arrow.
    var curveHandlePoint: NSPoint? {
        controlPoint ?? defaultCurveMid
    }

    func draw(in context: CGContext, bounds: NSRect) {
        // Arrow shaft + head from badge center to tip (drawn first so the
        // badge sits on top and hides the part of the shaft inside the
        // circle — visually the arrow emerges from the badge's edge while
        // geometrically the bezier starts from the center).
        if hasArrow, let tip {
            let shaftWidth = NumberArrowShape.shaftWidth
            context.setStrokeColor(color.cgColor)
            context.setFillColor(color.cgColor)
            context.setLineWidth(shaftWidth)
            context.setLineCap(.round)

            // Tangent at the tip — drives the arrowhead orientation.
            let endTangent: (dx: CGFloat, dy: CGFloat)
            if let cp = controlPoint {
                endTangent = (tip.x - cp.x, tip.y - cp.y)
            } else {
                endTangent = (tip.x - center.x, tip.y - center.y)
            }

            // Arrowhead — direction follows the local tangent at the tip.
            let tlen = hypot(endTangent.dx, endTangent.dy)
            if tlen > 0 {
                let unitX = endTangent.dx / tlen
                let unitY = endTangent.dy / tlen
                let headLength = NumberArrowShape.headLength
                let baseX = tip.x - unitX * headLength
                let baseY = tip.y - unitY * headLength

                // Shaft — stop at the arrowhead base so the round line cap
                // stays hidden inside the filled triangle.
                if let cp = controlPoint {
                    let t = max(0, min(1, 1 - headLength / (2 * tlen)))
                    let a = NSPoint(x: center.x + (cp.x - center.x) * t,
                                    y: center.y + (cp.y - center.y) * t)
                    let b = NSPoint(x: cp.x + (tip.x - cp.x) * t,
                                    y: cp.y + (tip.y - cp.y) * t)
                    let shaftEnd = NSPoint(x: a.x + (b.x - a.x) * t,
                                           y: a.y + (b.y - a.y) * t)
                    context.move(to: center)
                    context.addQuadCurve(to: shaftEnd, control: a)
                    context.strokePath()
                } else {
                    context.move(to: center)
                    context.addLine(to: CGPoint(x: baseX, y: baseY))
                    context.strokePath()
                }

                NumberArrowShape.drawHead(tip: tip, unitX: unitX, unitY: unitY, in: context)
            }
        }

        // Filled badge circle
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: circleRect)

        // Badge number — always drawn upright (no rotation). Pick a digit
        // color that contrasts with the badge fill so a white badge doesn't
        // render an invisible white "1".
        let text = "\(number)"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NumberAnnotation.contrastingTextColor(for: color),
            .font: NSFont.systemFont(ofSize: 14, weight: .bold)
        ]
        let size = text.size(withAttributes: attrs)
        let textOrigin = NSPoint(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2
        )
        NSGraphicsContext.saveGraphicsState()
        text.draw(at: textOrigin, withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }

    func containsPoint(_ point: NSPoint) -> Bool {
        // Badge hit
        let dx = point.x - center.x
        let dy = point.y - center.y
        let r = NumberAnnotation.radius
        if dx * dx + dy * dy <= r * r {
            return true
        }
        // Arrow shaft hit (only when an arrow is actually drawn).
        if hasArrow, let tip {
            let line = CGMutablePath()
            line.move(to: center)
            if let cp = controlPoint {
                line.addQuadCurve(to: tip, control: cp)
            } else {
                line.addLine(to: tip)
            }
            return strokedPathContains(line, point: point, lineWidth: 4)
        }
        return false
    }

    func translated(by delta: NSPoint) -> Annotation {
        NumberAnnotation(
            center: NSPoint(x: center.x + delta.x, y: center.y + delta.y),
            tip: tip.map { NSPoint(x: $0.x + delta.x, y: $0.y + delta.y) },
            controlPoint: controlPoint.map { NSPoint(x: $0.x + delta.x, y: $0.y + delta.y) },
            number: number,
            color: color
        )
    }

    /// Adjust-mode helper: replace (or clear) the arrow tip. Clearing the
    /// tip also drops the curve control point — there's no shaft for it
    /// to bend.
    func withTip(_ tip: NSPoint?) -> NumberAnnotation {
        var copy = self
        copy.tip = tip
        if tip == nil {
            copy.controlPoint = nil
        }
        return copy
    }

    /// Adjust-mode helper: replace (or clear) the curve control point.
    func withControlPoint(_ cp: NSPoint?) -> NumberAnnotation {
        var copy = self
        copy.controlPoint = cp
        return copy
    }

    /// Adjust-mode helper: replace the displayed badge number. Driven by
    /// the +/- stepper buttons on the selection chrome.
    func withNumber(_ number: Int) -> NumberAnnotation {
        NumberAnnotation(
            center: center,
            tip: tip,
            controlPoint: controlPoint,
            number: number,
            color: color
        )
    }

    func withColor(_ color: NSColor) -> Annotation {
        NumberAnnotation(center: center, tip: tip, controlPoint: controlPoint, number: number, color: color)
    }
}
