import AppKit

// MARK: - Pen Annotation

struct PenAnnotation: Annotation {
    let path: NSBezierPath
    let color: NSColor
    let lineWidth: CGFloat
    var rotation: CGFloat = 0

    var boundingRect: NSRect {
        path.bounds.insetBy(dx: -lineWidth / 2, dy: -lineWidth / 2)
    }
    var supportsRotation: Bool { true }

    func draw(in context: CGContext, bounds: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        color.setStroke()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    func containsPoint(_ point: NSPoint) -> Bool {
        let p = unrotate(point)
        return strokedPathContains(path.cgPath, point: p, lineWidth: lineWidth)
    }

    func translated(by delta: NSPoint) -> Annotation {
        let copy = path.copy() as! NSBezierPath
        var transform = AffineTransform.identity
        transform.translate(x: delta.x, y: delta.y)
        copy.transform(using: transform)
        return PenAnnotation(path: copy, color: color, lineWidth: lineWidth, rotation: rotation)
    }

    func withRotation(_ rotation: CGFloat) -> Annotation {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    func withColor(_ color: NSColor) -> Annotation {
        PenAnnotation(path: path, color: color, lineWidth: lineWidth, rotation: rotation)
    }

    func withLineWidth(_ lineWidth: CGFloat) -> Annotation {
        PenAnnotation(path: path, color: color, lineWidth: lineWidth, rotation: rotation)
    }
}
