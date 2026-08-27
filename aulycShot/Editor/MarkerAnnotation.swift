import AppKit

// MARK: - Marker (Highlighter) Annotation

/// Highlighter — a pen stroke painted with a semi-transparent fat brush so it
/// reads as if drawn over text with a real marker. Unlike the pen, the brush
/// width scales as `lineWidth × 6` and self-overlapping segments are drawn
/// inside a transparency layer so the alpha doesn't compound at junctions.
struct MarkerAnnotation: Annotation, Equatable {
    let path: NSBezierPath
    private let pathIdentity: ObjectIdentifier
    /// User-picked color; alpha is applied at draw time.
    let color: NSColor
    /// Base width — multiplied by `MarkerAnnotation.brushScale` when drawn.
    let lineWidth: CGFloat
    var rotation: CGFloat = 0

    static let brushScale: CGFloat = 6
    static let markerAlpha: CGFloat = 0.35

    init(path: NSBezierPath, color: NSColor, lineWidth: CGFloat, rotation: CGFloat = 0) {
        self.path = path
        pathIdentity = ObjectIdentifier(path)
        self.color = color
        self.lineWidth = lineWidth
        self.rotation = rotation
    }

    var boundingRect: NSRect {
        let inset = -lineWidth * MarkerAnnotation.brushScale / 2
        return path.bounds.insetBy(dx: inset, dy: inset)
    }
    var supportsRotation: Bool { true }

    func draw(in context: CGContext, bounds: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        let stroke = color.withAlphaComponent(1.0)
        stroke.setStroke()
        path.lineWidth = lineWidth * MarkerAnnotation.brushScale
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        // Paint into a transparency layer at full alpha then flatten the
        // entire layer at marker alpha so overlapping passes don't darken.
        context.setAlpha(MarkerAnnotation.markerAlpha)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        path.stroke()
        context.endTransparencyLayer()
        context.setAlpha(1.0)
    }

    func containsPoint(_ point: NSPoint) -> Bool {
        let p = unrotate(point)
        let effectiveWidth = lineWidth * MarkerAnnotation.brushScale
        return strokedPathContains(path.cgPath, point: p, lineWidth: effectiveWidth)
    }

    func translated(by delta: NSPoint) -> Annotation {
        let copy = path.copy() as! NSBezierPath
        var transform = AffineTransform.identity
        transform.translate(x: delta.x, y: delta.y)
        copy.transform(using: transform)
        return MarkerAnnotation(path: copy, color: color, lineWidth: lineWidth, rotation: rotation)
    }

    func withRotation(_ rotation: CGFloat) -> Annotation {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    func withColor(_ color: NSColor) -> Annotation {
        MarkerAnnotation(path: path, color: color, lineWidth: lineWidth, rotation: rotation)
    }

    func withLineWidth(_ lineWidth: CGFloat) -> Annotation {
        MarkerAnnotation(path: path, color: color, lineWidth: lineWidth, rotation: rotation)
    }
}
