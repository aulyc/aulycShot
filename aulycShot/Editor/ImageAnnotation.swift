import AppKit

// MARK: - Image Annotation

struct ImageAnnotation: Annotation {
    let image: NSImage
    let rect: NSRect
    var rotation: CGFloat = 0

    var boundingRect: NSRect { rect }
    var supportsRotation: Bool { true }

    func draw(in context: CGContext, bounds: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: rect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high.rawValue]
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    func containsPoint(_ point: NSPoint) -> Bool {
        let p = unrotate(point)
        return rect.insetBy(dx: -8, dy: -8).contains(p)
    }

    func translated(by delta: NSPoint) -> Annotation {
        ImageAnnotation(
            image: image,
            rect: rect.offsetBy(dx: delta.x, dy: delta.y),
            rotation: rotation
        )
    }

    func withRotation(_ rotation: CGFloat) -> Annotation {
        ImageAnnotation(image: image, rect: rect, rotation: rotation)
    }

    func withRect(_ rect: NSRect) -> ImageAnnotation {
        ImageAnnotation(image: image, rect: rect, rotation: rotation)
    }
}
