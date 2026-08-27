import AppKit

// MARK: - Magnifier Annotation

/// A circular magnifying-glass lens placed over the screenshot. The lens
/// samples the base image beneath `sourceCenter` (or beneath itself by
/// default) and redraws that region enlarged `zoom`× inside a plain line
/// frame. It holds a reference to the source image and re-samples it on every
/// draw, so moving or resizing the lens always shows fresh underlying pixels.
struct MagnifierAnnotation: Annotation, Equatable {
    let center: NSPoint
    let radius: CGFloat
    let color: NSColor
    let lineWidth: CGFloat
    /// Magnification factor — the lens shows a `2·radius / zoom` wide region
    /// blown up to fill the `2·radius` circle.
    let zoom: CGFloat
    /// Base screenshot this lens magnifies. Sampled fresh on every draw.
    let sourceImage: NSImage
    /// Optional canvas point magnified by the lens. nil keeps the classic
    /// loupe behavior where the lens samples directly beneath its center.
    let sourceCenter: NSPoint?

    static let defaultZoom: CGFloat = 2.0
    static let minZoom: CGFloat = 1.0
    static let maxZoom: CGFloat = 6.0
    static let zoomStep: CGFloat = 0.5
    /// Smallest radius the lens may be created or resized to.
    static let minRadius: CGFloat = 16
    /// Dragging the source handle this close to the lens center resets the
    /// lens to the default "magnify what is under me" behavior.
    static let sourceResetDistance: CGFloat = 8

    var effectiveSourceCenter: NSPoint {
        sourceCenter ?? center
    }

    var boundingRect: NSRect {
        NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    }

    init(
        center: NSPoint,
        radius: CGFloat,
        color: NSColor,
        lineWidth: CGFloat,
        zoom: CGFloat,
        sourceImage: NSImage,
        sourceCenter: NSPoint? = nil
    ) {
        self.center = center
        self.radius = radius
        self.color = color
        self.lineWidth = lineWidth
        self.zoom = zoom
        self.sourceImage = sourceImage
        self.sourceCenter = sourceCenter
    }

    private static func sourceIndicatorRadius(for lensRadius: CGFloat) -> CGFloat {
        max(12, min(24, lensRadius * 0.14))
    }

    private var detachedSourceGeometry: (source: NSPoint, start: NSPoint, end: NSPoint, indicatorRadius: CGFloat)? {
        guard let source = sourceCenter else { return nil }
        let dx = source.x - center.x
        let dy = source.y - center.y
        let distance = hypot(dx, dy)
        let indicatorRadius = Self.sourceIndicatorRadius(for: radius)
        guard distance > radius + indicatorRadius + 2 else { return nil }

        let ux = dx / distance
        let uy = dy / distance
        return (
            source: source,
            start: NSPoint(x: center.x + ux * radius, y: center.y + uy * radius),
            end: NSPoint(x: source.x - ux * indicatorRadius, y: source.y - uy * indicatorRadius),
            indicatorRadius: indicatorRadius
        )
    }

    func draw(in context: CGContext, bounds: NSRect) {
        guard radius > 6, let nsContext = NSGraphicsContext.current else { return }

        let squareRect = boundingRect
        let circle = NSBezierPath(ovalIn: squareRect)

        if let geometry = detachedSourceGeometry {
            drawSourceConnector(geometry, in: context)
        }

        // 1. Magnified content, clipped to the circle. The source region is
        // `2·radius / zoom` wide in canvas coords, centered on the lens; map
        // it into the source image's coordinate space and blow it up to fill.
        NSGraphicsContext.saveGraphicsState()
        circle.addClip()
        let imgSize = sourceImage.size
        let scaleX = bounds.width > 0 ? imgSize.width / bounds.width : 1
        let scaleY = bounds.height > 0 ? imgSize.height / bounds.height : 1
        let srcSize = (radius * 2) / max(zoom, 1)
        let sampleCenter = effectiveSourceCenter
        let fromRect = NSRect(
            x: (sampleCenter.x - srcSize / 2) * scaleX,
            y: (sampleCenter.y - srcSize / 2) * scaleY,
            width: srcSize * scaleX,
            height: srcSize * scaleY
        )
        nsContext.imageInterpolation = .high
        sourceImage.draw(in: squareRect, from: fromRect, operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        // 2. Plain annotation stroke, matching rectangle / ellipse tools.
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.strokeEllipse(in: squareRect)

        if let geometry = detachedSourceGeometry {
            drawSourceIndicator(geometry, in: context)
        }
    }

    private func drawSourceConnector(
        _ geometry: (source: NSPoint, start: NSPoint, end: NSPoint, indicatorRadius: CGFloat),
        in context: CGContext
    ) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.butt)
        context.move(to: geometry.start)
        context.addLine(to: geometry.end)
        context.strokePath()
        context.restoreGState()
    }

    private func drawSourceIndicator(
        _ geometry: (source: NSPoint, start: NSPoint, end: NSPoint, indicatorRadius: CGFloat),
        in context: CGContext
    ) {
        let rect = NSRect(
            x: geometry.source.x - geometry.indicatorRadius,
            y: geometry.source.y - geometry.indicatorRadius,
            width: geometry.indicatorRadius * 2,
            height: geometry.indicatorRadius * 2
        )
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.strokeEllipse(in: rect)
        context.restoreGState()
    }

    func containsPoint(_ point: NSPoint) -> Bool {
        if hypot(point.x - center.x, point.y - center.y) <= radius {
            return true
        }
        guard let geometry = detachedSourceGeometry else { return false }
        if hypot(point.x - geometry.source.x, point.y - geometry.source.y) <= geometry.indicatorRadius + 5 {
            return true
        }
        return distanceFrom(point, toSegmentFrom: geometry.start, to: geometry.end) <= 6
    }

    func translated(by delta: NSPoint) -> Annotation {
        MagnifierAnnotation(
            center: NSPoint(x: center.x + delta.x, y: center.y + delta.y),
            radius: radius,
            color: color,
            lineWidth: lineWidth,
            zoom: zoom,
            sourceImage: sourceImage,
            sourceCenter: sourceCenter
        )
    }

    func translatedPreservingSourceFocus(by delta: NSPoint) -> MagnifierAnnotation {
        MagnifierAnnotation(
            center: NSPoint(x: center.x + delta.x, y: center.y + delta.y),
            radius: radius,
            color: color,
            lineWidth: lineWidth,
            zoom: zoom,
            sourceImage: sourceImage,
            sourceCenter: effectiveSourceCenter
        )
    }

    func withRadius(_ radius: CGFloat) -> MagnifierAnnotation {
        MagnifierAnnotation(
            center: center,
            radius: radius,
            color: color,
            lineWidth: lineWidth,
            zoom: zoom,
            sourceImage: sourceImage,
            sourceCenter: sourceCenter
        )
    }

    func withSourceCenter(_ sourceCenter: NSPoint?) -> MagnifierAnnotation {
        MagnifierAnnotation(
            center: center,
            radius: radius,
            color: color,
            lineWidth: lineWidth,
            zoom: zoom,
            sourceImage: sourceImage,
            sourceCenter: sourceCenter
        )
    }

    func withZoom(_ zoom: CGFloat) -> MagnifierAnnotation {
        MagnifierAnnotation(
            center: center,
            radius: radius,
            color: color,
            lineWidth: lineWidth,
            zoom: min(max(zoom, Self.minZoom), Self.maxZoom),
            sourceImage: sourceImage,
            sourceCenter: sourceCenter
        )
    }

    func withColor(_ color: NSColor) -> Annotation {
        MagnifierAnnotation(
            center: center,
            radius: radius,
            color: color,
            lineWidth: lineWidth,
            zoom: zoom,
            sourceImage: sourceImage,
            sourceCenter: sourceCenter
        )
    }

    func withLineWidth(_ lineWidth: CGFloat) -> Annotation {
        MagnifierAnnotation(
            center: center,
            radius: radius,
            color: color,
            lineWidth: lineWidth,
            zoom: zoom,
            sourceImage: sourceImage,
            sourceCenter: sourceCenter
        )
    }
}
