import AppKit

// MARK: - Mosaic Annotation

struct MosaicAnnotation: Annotation, Equatable {
    let rect: NSRect
    let pixelatedImage: NSImage
    let blockSize: CGFloat

    var boundingRect: NSRect { rect }

    static func == (lhs: MosaicAnnotation, rhs: MosaicAnnotation) -> Bool {
        // The pixels are derived from the base image, rect and block size.
        // Re-rendering the same logical mosaic must remain a no-op for undo.
        lhs.rect == rhs.rect && lhs.blockSize == rhs.blockSize
    }

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
