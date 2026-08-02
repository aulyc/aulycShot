import AppKit

// MARK: - Line Annotation

/// A straight line segment. Like the arrow but with no arrowhead. The two
/// endpoints carry draggable handles in adjust mode so the user can change
/// the line's length and angle; a rotation handle spins the whole segment
/// around its midpoint.
struct LineAnnotation: Annotation {
    let startPoint: NSPoint
    let endPoint: NSPoint
    let color: NSColor
    let lineWidth: CGFloat

    var boundingRect: NSRect {
        NSRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
    }

    /// The rotation handle is supported, but rather than storing an angle the
    /// segment "bakes" rotation into its endpoints (see `withRotation`). That
    /// keeps `rotation` permanently 0 so the endpoint handles always sit on
    /// the real geometry and no unrotate bookkeeping is needed.
    var supportsRotation: Bool { true }

    func draw(in context: CGContext, bounds: NSRect) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()
    }

    func containsPoint(_ point: NSPoint) -> Bool {
        let line = CGMutablePath()
        line.move(to: startPoint)
        line.addLine(to: endPoint)
        return strokedPathContains(line, point: point, lineWidth: lineWidth)
    }

    func translated(by delta: NSPoint) -> Annotation {
        LineAnnotation(
            startPoint: NSPoint(x: startPoint.x + delta.x, y: startPoint.y + delta.y),
            endPoint: NSPoint(x: endPoint.x + delta.x, y: endPoint.y + delta.y),
            color: color,
            lineWidth: lineWidth
        )
    }

    /// Rotate both endpoints by `rotation` radians around the segment's
    /// midpoint. The stored `rotation` stays 0 — the change is baked into
    /// `startPoint` / `endPoint` so the endpoint handles stay truthful.
    func withRotation(_ rotation: CGFloat) -> Annotation {
        guard rotation != 0 else { return self }
        let center = NSPoint(
            x: (startPoint.x + endPoint.x) / 2,
            y: (startPoint.y + endPoint.y) / 2
        )
        let cosR = cos(rotation)
        let sinR = sin(rotation)
        func rotate(_ p: NSPoint) -> NSPoint {
            let dx = p.x - center.x
            let dy = p.y - center.y
            return NSPoint(
                x: center.x + dx * cosR - dy * sinR,
                y: center.y + dx * sinR + dy * cosR
            )
        }
        return LineAnnotation(
            startPoint: rotate(startPoint),
            endPoint: rotate(endPoint),
            color: color,
            lineWidth: lineWidth
        )
    }

    /// Adjust-mode helper: re-anchor the start endpoint.
    func withStartPoint(_ p: NSPoint) -> LineAnnotation {
        LineAnnotation(startPoint: p, endPoint: endPoint, color: color, lineWidth: lineWidth)
    }

    /// Adjust-mode helper: re-anchor the end endpoint.
    func withEndPoint(_ p: NSPoint) -> LineAnnotation {
        LineAnnotation(startPoint: startPoint, endPoint: p, color: color, lineWidth: lineWidth)
    }

    func withColor(_ color: NSColor) -> Annotation {
        LineAnnotation(startPoint: startPoint, endPoint: endPoint, color: color, lineWidth: lineWidth)
    }

    func withLineWidth(_ lineWidth: CGFloat) -> Annotation {
        LineAnnotation(startPoint: startPoint, endPoint: endPoint, color: color, lineWidth: lineWidth)
    }
}
