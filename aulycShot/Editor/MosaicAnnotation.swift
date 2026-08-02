import AppKit

// MARK: - Mosaic Annotation

struct MosaicAnnotation: Annotation {
    let rect: NSRect
    let pixelatedImage: NSImage
    let blockSize: CGFloat

    var boundingRect: NSRect { rect }

    func draw(in context: CGContext, bounds: NSRect) {
        pixelatedImage.draw(in: rect)
    }

    func containsPoint(_ point: NSPoint) -> Bool {
        rect.contains(point)
    }

    func translated(by delta: NSPoint) -> Annotation {
        MosaicAnnotation(
            rect: rect.offsetBy(dx: delta.x, dy: delta.y),
            pixelatedImage: pixelatedImage,
            blockSize: blockSize
        )
    }
}
